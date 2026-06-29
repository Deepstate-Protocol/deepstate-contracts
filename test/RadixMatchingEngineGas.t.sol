// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {RadixMatchingEngine} from "../src/RadixMatchingEngine.sol";
import {TestERC20} from "./RadixMatchingEngine.t.sol";

contract RadixMatchingEngineGasTest is Test {
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

    function _order(uint24 price, uint192 quantity, uint40 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(price) << 232) | (uint256(quantity) << 40) | uint256(nonce));
    }
}
