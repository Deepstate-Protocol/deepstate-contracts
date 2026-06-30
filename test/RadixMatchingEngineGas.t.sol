// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {RadixMatchingEngine} from "../src/RadixMatchingEngine.sol";
import {TestERC20} from "./RadixMatchingEngine.t.sol";

contract RadixMatchingEngineGasTest is Test {
    uint40 internal constant MAX_ORDER_NONCE = type(uint40).max;

    TestERC20 internal base;
    TestERC20 internal quote;
    RadixMatchingEngine internal engine;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);

    function setUp() public {
        base = new TestERC20("Base", "BASE");
        quote = new TestERC20("Quote", "QUOTE");
        engine = new RadixMatchingEngine(address(base), address(quote));

        _fundAndApprove(alice);
        _fundAndApprove(bob);
        _fundAndApprove(carol);
    }

    function testGas_FillRestBidEmptyBook() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, _order(100, 5, type(uint40).max));
        assertEq(engine.bidRoot(), restingBid);
        vm.resumeGasMetering();
    }

    function testGas_FillRestAskEmptyBook() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = engine.fill(_order(100, 5, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, _order(100, 5, type(uint40).max));
        assertEq(engine.askRoot(), restingAsk);
        vm.resumeGasMetering();
    }

    function testGas_FillBidFullyMatchesSingleAsk() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskFullyMatchesSingleBid() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = engine.fill(_order(90, 5, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingBid), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillBidPartiallyMatchesSingleAsk() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), _order(90, 3, type(uint40).max));
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskPartiallyMatchesSingleBid() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), _order(100, 3, type(uint40).max));
        assertEq(engine.ownerOfOrder(restingBid), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesAskAndRestsRemainder() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        engine.fill(_order(90, 3, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, _order(100, 2, type(uint40).max - 1));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.askRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesSamePriceAskSubtree() public {
        vm.pauseGasMetering();
        bytes32 firstAsk;
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            bytes32 restingAsk = engine.fill(_order(90, 1, 0), false);
            if (i == 0) firstAsk = restingAsk;
        }

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = engine.fill(_order(90, 16, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(firstAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesDirtySamePriceAskSubtree() public {
        vm.pauseGasMetering();
        bytes32 firstAsk;
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            bytes32 restingAsk = engine.fill(_order(90, 1, 0), false);
            if (i == 0) firstAsk = restingAsk;
        }

        vm.prank(alice);
        engine.fill(_order(90, 1, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = engine.fill(_order(90, 15, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(firstAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskConsumesDirtySamePriceBidSubtree() public {
        vm.pauseGasMetering();
        bytes32 firstBid;
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            bytes32 restingBid = engine.fill(_order(90, 1, 0), true);
            if (i == 0) firstBid = restingBid;
        }

        vm.prank(alice);
        engine.fill(_order(90, 1, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = engine.fill(_order(90, 15, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(firstBid), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskConsumesFullDepthBidComb() public {
        vm.pauseGasMetering();
        _buildFullDepthBidNonceComb();

        address seller = address(0x5E11E2);
        _fundAndApprove(seller);

        vm.prank(seller);
        vm.resumeGasMetering();
        bytes32 restingAsk = engine.fill(_order(1, 65, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesMaxValidDepthAskComb() public {
        vm.pauseGasMetering();
        _buildMaxValidDepthAskNonceComb();

        address buyer = address(0xB0DE6A);
        _fundAndApprove(buyer);
        quote.mint(buyer, 2_000_000_000);

        vm.prank(buyer);
        vm.resumeGasMetering();
        bytes32 restingBid = engine.fill(_order(type(uint24).max, 64, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelFullDepthBidCombRightmost() public {
        vm.pauseGasMetering();
        bytes32 targetBid = _buildFullDepthBidNonceComb();

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(targetBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, type(uint24).max);
        assertEq(engine.ownerOfOrder(targetBid), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelMaxValidDepthAskCombRightmost() public {
        vm.pauseGasMetering();
        bytes32 targetAsk = _buildMaxValidDepthAskNonceComb();

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(targetAsk);
        vm.pauseGasMetering();

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(engine.ownerOfOrder(targetAsk), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelAskSkipsPathologicalBidTree() public {
        vm.pauseGasMetering();
        _buildSamePriceBidNonceComb(1);

        vm.prank(bob);
        bytes32 targetAsk = engine.fill(_order(2, 1, 0), false);

        vm.prank(bob);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(targetAsk);
        vm.pauseGasMetering();

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(engine.ownerOfOrder(targetAsk), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelUnfilledBid() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, 500);
        assertEq(engine.bidRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelUnfilledAsk() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_order(100, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingAsk);
        vm.pauseGasMetering();

        assertEq(baseAmount, 5);
        assertEq(quoteAmount, 0);
        assertEq(engine.askRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelFilledBidClaim() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        vm.prank(bob);
        engine.fill(_order(90, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 5);
        assertEq(quoteAmount, 0);
        assertEq(engine.ownerOfOrder(restingBid), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelPartialBid() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        vm.prank(bob);
        engine.fill(_order(90, 2, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 2);
        assertEq(quoteAmount, 300);
        assertEq(engine.bidRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function _fundAndApprove(address account) internal {
        base.mint(account, 1_000_000);
        quote.mint(account, 1_000_000);

        vm.startPrank(account);
        base.approve(address(engine), type(uint256).max);
        quote.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _buildFullDepthBidNonceComb() internal returns (bytes32 targetOrder) {
        uint64 targetKey = type(uint64).max;
        quote.mint(alice, 2_000_000_000);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = engine.fill(_order(type(uint24).max, 1, 0), true);

        for (uint256 depth; depth < 64; ++depth) {
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint24 price = uint24(siblingKey >> 40);
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = uint40(siblingKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            engine.fill(_order(price, 1, 0), true);
        }
    }

    function _buildMaxValidDepthAskNonceComb() internal returns (bytes32 targetOrder) {
        uint24 targetSortPrice = type(uint24).max - 1;

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = engine.fill(_order(1, 1, 0), false);

        uint256 orderIndex = 1;
        for (uint256 depth; depth < 23; ++depth) {
            // forge-lint: disable-next-line(unsafe-typecast)
            uint24 sortPrice = targetSortPrice ^ uint24(uint256(1) << (23 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = MAX_ORDER_NONCE - uint40(10_000 + orderIndex);
            uint24 price = type(uint24).max - sortPrice;

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            engine.fill(_order(price, 1, 0), false);

            unchecked {
                ++orderIndex;
            }
        }

        for (uint256 depth = 24; depth < 64; ++depth) {
            uint64 sortKey = (uint64(targetSortPrice) << 40) | uint64(MAX_ORDER_NONCE);
            sortKey ^= uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = uint40(sortKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            engine.fill(_order(1, 1, 0), false);
        }
    }

    function _buildSamePriceBidNonceComb(uint24 price) internal returns (bytes32 targetOrder) {
        uint64 targetKey = (uint64(price) << 40) | uint64(MAX_ORDER_NONCE);
        quote.mint(alice, 2_000_000_000);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = engine.fill(_order(price, 1, 0), true);

        for (uint256 depth = 24; depth < 64; ++depth) {
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = uint40(siblingKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            engine.fill(_order(price, 1, 0), true);
        }
    }

    function _order(uint24 price, uint192 quantity, uint40 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(price) << 232) | (uint256(quantity) << 40) | uint256(nonce));
    }

    function _nextNonceSlot() internal pure returns (bytes32) {
        return bytes32(uint256(4));
    }
}
