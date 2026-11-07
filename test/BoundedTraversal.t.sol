// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {DeepstateV1} from "../src/DeepstateV1.sol";
import {RadixMatchingEngineGasTest} from "./RadixMatchingEngineGas.t.sol";

contract TraversalEngine is DeepstateV1 {
    uint256[3] public expansions;

    function resetWalks() external {
        delete expansions;
    }

    function cachedQuote(bytes32 id, bytes32 node) external view returns (uint256) {
        return books[id].tree[bytes32(uint256(uint32(uint256(node))))].quoteTotal;
    }

    function _observeTreeWalk(uint8 phase) internal override {
        ++expansions[phase];
    }
}

contract BoundedTraversalTest is RadixMatchingEngineGasTest {
    function _afterSetUp() internal override {
        TraversalEngine instrumented = new TraversalEngine();
        vm.etch(address(engine), address(instrumented).code);
        quote.mint(alice, uint256(1) << 220);
        quote.mint(bob, uint256(1) << 220);
    }

    function test_WideSweep4096ExpandsNoBranchesAndAllMakersClaim() public {
        vm.pauseGasMetering();
        uint256 count = 4096;
        bytes32[] memory orders = new bytes32[](count);
        uint256 expectedQuote;
        for (uint256 i; i < count; ++i) {
            int32 tick = int32(uint32(i * 0x1e3779b9 + 0x1765431) & 0x7fffffff);
            vm.prank(bob);
            orders[i] = _fill(_order(tick, 1, 0), false);
            expectedQuote += _quoteValue(tick, 1, false);
        }
        _assertSummaries(_askRoot(), false);
        _reset();
        uint256 beforeBalance = quote.balanceOf(alice);
        vm.prank(alice);
        _fill(_order(type(int32).max, uint160(count), 0), true);
        assertEq(_walks(0), 0, "full sweep must use cached quote");
        assertEq(_askRoot(), bytes32(0));
        assertEq(beforeBalance - quote.balanceOf(alice), expectedQuote);
        for (uint256 i; i < count; ++i) {
            vm.prank(bob);
            _cancel(orders[i]);
        }
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
        vm.resumeGasMetering();
    }

    function test_Full64LevelCombMatchInsertAndCancelStayBounded() public {
        bytes32 target = _buildUniqueFullDepthComb();
        _assertSummaries(_bidRoot(), true);
        uint256 checkpoint = vm.snapshotState();
        _reset();
        vm.prank(bob);
        _fill(_order(type(int32).min, 32, 0), false);
        assertEq(_walks(0), 64, "exercise all price and nonce bits");
        _assertSummaries(_bidRoot(), true);
        assertTrue(vm.revertToState(checkpoint));
        _forceNextOrderNonce(900);
        _reset();
        vm.prank(alice);
        bytes32 added = _fill(_order(0, 3, 0), true);
        assertLe(_walks(1), 64, "insertion expansions");
        _assertSummaries(_bidRoot(), true);
        _reset();
        vm.prank(alice);
        _cancel(added);
        assertLe(_walks(2), 64, "cancel expansions");
        _assertSummaries(_bidRoot(), true);
        _reset();
        vm.prank(alice);
        _cancel(target);
        assertEq(_walks(2), 64, "exercise full cancellation path");
    }

    function _buildUniqueFullDepthComb() private returns (bytes32 target) {
        // Skip nonce ranges as a finite history of rests/cancels in an otherwise empty opposite
        // side could do. Every live nonce is unique, above the branch front, and assigned descending.
        _forceNextOrderNonce(MAX_ORDER_NONCE);
        vm.prank(alice);
        target = _fill(_order(0, 2, 0), true);
        for (uint256 bit; bit < 32; ++bit) {
            uint32 nonce = MAX_ORDER_NONCE ^ uint32(uint256(1) << bit);
            _forceNextOrderNonce(nonce);
            vm.prank(alice);
            _fill(_order(0, 1, 0), true);
        }
        uint32 tickKey = uint32(1) << 31;
        for (uint256 bit; bit < 32; ++bit) {
            int32 tick = int32(tickKey ^ uint32(uint256(1) << bit) ^ 0x80000000);
            _forceNextOrderNonce(uint32(1000 - bit));
            vm.prank(alice);
            _fill(_order(tick, 1, 0), true);
        }
    }

    function testFuzz_QuantityAndLimitBoundariesUseOnePath(uint256 seed, bool bids) public {
        uint256 count = 8 + seed % 121;
        bytes32[] memory orders = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            int32 tick = int32(uint32(uint256(keccak256(abi.encode(seed, i)))));
            vm.prank(bob);
            orders[i] = _fill(_order(tick, 10, 0), bids);
            assertLe(_walks(1), 64, "insertion expansions");
            _reset();
        }
        _assertSummaries(bids ? _bidRoot() : _askRoot(), bids);
        for (uint256 i; i < 5; ++i) {
            _reset();
            int32 limit = i == 0 ? (bids ? type(int32).min : type(int32).max) : int32(uint32(seed >> (i * 32)));
            DeepstateV1.FillParams memory params = DeepstateV1.FillParams({
                token0: address(base),
                token1: address(quote),
                epoch: 0,
                order: _order(limit, uint160(1 + (seed >> (i * 8)) % (count * 3)), 0),
                isBid: !bids,
                noRest: true,
                fillOrKill: false
            });
            vm.prank(alice);
            engine.fill(params);
            assertLe(_walks(0), 64, "matching expansions");
            _assertSummaries(bids ? _bidRoot() : _askRoot(), bids);
        }
        for (uint256 i; i < count; ++i) {
            _reset();
            vm.prank(bob);
            _cancel(orders[i]);
            assertLe(_walks(2), 64, "cancel expansions");
        }
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function _assertSummaries(bytes32 node, bool bid)
        private
        view
        returns (uint160 quantity, uint256 value, int32 worst)
    {
        if (node == bytes32(0)) return (0, 0, 0);
        (bytes32 left, bytes32 right) = _tree(node);
        worst = int32(uint32(uint256(node) >> 224));
        quantity = _quantity(node);
        if (left == bytes32(0)) return (quantity, _quoteValue(worst, quantity, bid), worst);
        (uint160 lq, uint256 lv, int32 lw) = _assertSummaries(left, bid);
        (uint160 rq, uint256 rv,) = _assertSummaries(right, bid);
        assertEq(quantity, lq + rq, "exact quantity at every branch");
        assertEq(worst, lw, "cached worst price");
        value = lv + rv;
        uint32 code = uint32(uint256(node) >> 32);
        if (code == 0) {
            assertEq(TraversalEngine(payable(address(engine))).cachedQuote(_bookId(), node), value, "mixed quote cache");
        } else {
            uint256 aggregate = _quoteValue(worst, quantity, bid);
            assertEq(bid ? aggregate + code - 1 : aggregate - (code - 1), value, "uniform correction");
        }
    }

    function _reset() private {
        TraversalEngine(payable(address(engine))).resetWalks();
    }

    function _walks(uint8 phase) private view returns (uint256) {
        return TraversalEngine(payable(address(engine))).expansions(phase);
    }
}
