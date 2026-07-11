// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RadixMatchingEngineGasTest} from "./RadixMatchingEngineGas.t.sol";

/// @dev Benchmark-only harness. It does not change production matching semantics.
contract RadixMatchingEngineAccessListBenchmark is RadixMatchingEngineGasTest {
    uint256 private constant ACCESS_LIST_ADDRESS_COST = 2_400;
    uint256 private constant ACCESS_LIST_STORAGE_KEY_COST = 1_900;

    struct Accesses {
        bytes32[] engineSlots;
        bytes32[] baseSlots;
        bytes32[] quoteSlots;
    }

    function testBenchmark_FillBidConsumesAskAndRestsRemainder() public {
        vm.prank(bob);
        _fill(_order(90, 3, 0), false);
        _benchmark("FillBidConsumesAskAndRestsRemainder", alice, _order(100, 5, 0), true);
    }

    function testBenchmark_FillBidConsumesSamePriceAskSubtree() public {
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            _fill(_order(90, 1, 0), false);
        }
        _benchmark("FillBidConsumesSamePriceAskSubtree", alice, _order(90, 16, 0), true);
    }

    function testBenchmark_FillBidConsumesDirtySamePriceAskSubtree() public {
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            _fill(_order(90, 1, 0), false);
        }
        vm.prank(alice);
        _fill(_order(90, 1, 0), true);
        _benchmark("FillBidConsumesDirtySamePriceAskSubtree", alice, _order(90, 15, 0), true);
    }

    function testBenchmark_FillAskConsumesDirtySamePriceBidSubtree() public {
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            _fill(_order(90, 1, 0), true);
        }
        vm.prank(alice);
        _fill(_order(90, 1, 0), false);
        _benchmark("FillAskConsumesDirtySamePriceBidSubtree", alice, _order(90, 15, 0), false);
    }

    function testBenchmark_FillAskConsumesFullDepthBidComb() public {
        _buildFullDepthBidNonceComb();
        address seller = address(0x5E11E2);
        _fundAndApprove(seller);
        _benchmark("FillAskConsumesFullDepthBidComb", seller, _order(type(int32).min, 65, 0), false);
    }

    function testBenchmark_FillBidConsumesMaxValidDepthAskComb() public {
        _buildMaxValidDepthAskNonceComb();
        address buyer = address(0xB0DE6A);
        _fundAndApprove(buyer);
        quote.mint(buyer, uint256(1) << 200);
        _benchmark("FillBidConsumesMaxValidDepthAskComb", buyer, _order(type(int32).max, 65, 0), true);
    }

    function _benchmark(string memory label, address caller, bytes32 order, bool isBid) private {
        uint256 state = vm.snapshotState();

        vm.record();
        vm.prank(caller);
        _fill(order, isBid);
        Accesses memory touched = _recordedAccesses();
        assertTrue(vm.revertToState(state));

        _prepareCold(touched);
        uint256 coldGas = _measureFill(caller, order, isBid);
        assertTrue(vm.revertToState(state));

        _prepareWarm(touched);
        uint256 warmGas = _measureFill(caller, order, isBid);

        uint256 keyCount = touched.engineSlots.length + touched.baseSlots.length + touched.quoteSlots.length;
        uint256 addressCount = 3;
        uint256 intrinsicCost = addressCount * ACCESS_LIST_ADDRESS_COST + keyCount * ACCESS_LIST_STORAGE_KEY_COST;
        uint256 warmAllIn = warmGas + intrinsicCost;
        // Both measured values are far below int256.max.
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 net = int256(coldGas) - int256(warmAllIn);

        emit log_string(label);
        emit log_named_uint("engine keys", touched.engineSlots.length);
        emit log_named_uint("base keys", touched.baseSlots.length);
        emit log_named_uint("quote keys", touched.quoteSlots.length);
        emit log_named_uint("total keys", keyCount);
        emit log_named_uint("cold execution", coldGas);
        emit log_named_uint("warm execution", warmGas);
        emit log_named_uint("execution-only saving", coldGas - warmGas);
        emit log_named_uint("access-list intrinsic", intrinsicCost);
        emit log_named_uint("warm plus intrinsic", warmAllIn);
        emit log_named_int("transaction-net saving", net);
    }

    function _recordedAccesses() private view returns (Accesses memory touched) {
        (bytes32[] memory engineReads, bytes32[] memory engineWrites) = vm.accesses(address(engine));
        (bytes32[] memory baseReads, bytes32[] memory baseWrites) = vm.accesses(address(base));
        (bytes32[] memory quoteReads, bytes32[] memory quoteWrites) = vm.accesses(address(quote));
        touched.engineSlots = _unique(engineReads, engineWrites);
        touched.baseSlots = _unique(baseReads, baseWrites);
        touched.quoteSlots = _unique(quoteReads, quoteWrites);
    }

    function _prepareCold(Accesses memory touched) private {
        _coolSlots(address(engine), touched.engineSlots);
        _coolSlots(address(base), touched.baseSlots);
        _coolSlots(address(quote), touched.quoteSlots);
        vm.cool(address(engine));
        vm.cool(address(base));
        vm.cool(address(quote));

        // A transaction's destination is warm under EIP-2929; token contracts remain cold.
        _warmAddress(address(engine));
    }

    function _prepareWarm(Accesses memory touched) private {
        vm.cool(address(engine));
        vm.cool(address(base));
        vm.cool(address(quote));

        _warmAddress(address(engine));
        _warmAddress(address(base));
        _warmAddress(address(quote));
        _warmSlots(address(engine), touched.engineSlots);
        _warmSlots(address(base), touched.baseSlots);
        _warmSlots(address(quote), touched.quoteSlots);
    }

    function _measureFill(address caller, bytes32 order, bool isBid) private returns (uint256 gasUsed) {
        vm.prank(caller);
        uint256 gasBefore = gasleft();
        _fill(order, isBid);
        gasUsed = gasBefore - gasleft();
    }

    function _warmAddress(address target) private view {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(target)
        }
        assertGt(size, 0);
    }

    function _coolSlots(address target, bytes32[] memory slots) private {
        for (uint256 i; i < slots.length; ++i) {
            vm.coolSlot(target, slots[i]);
        }
    }

    function _warmSlots(address target, bytes32[] memory slots) private {
        for (uint256 i; i < slots.length; ++i) {
            vm.warmSlot(target, slots[i]);
        }
    }

    function _unique(bytes32[] memory reads, bytes32[] memory writes) private pure returns (bytes32[] memory slots) {
        slots = new bytes32[](reads.length + writes.length);
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            count = _appendUnique(slots, count, reads[i]);
        }
        for (uint256 i; i < writes.length; ++i) {
            count = _appendUnique(slots, count, writes[i]);
        }
        assembly ("memory-safe") {
            mstore(slots, count)
        }
    }

    function _appendUnique(bytes32[] memory slots, uint256 count, bytes32 slot) private pure returns (uint256) {
        for (uint256 i; i < count; ++i) {
            if (slots[i] == slot) return count;
        }
        slots[count] = slot;
        return count + 1;
    }
}
