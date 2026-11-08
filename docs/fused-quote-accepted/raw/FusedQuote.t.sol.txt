// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";
import {TickMath32} from "../src/libraries/TickMath32.sol";
import {QuoteMath} from "./QuoteMath.sol";
import {RoutingTestERC20} from "./DeepstateV1.t.sol";

contract FusedQuoteHarness is DeepstateV1 {
    function quoteDelta(int32 tick, uint160 larger, uint160 smaller, bool roundUp)
        external
        pure
        returns (uint256 amount, uint32 code)
    {
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
        return _quoteDifferenceAndEventCodeAtFactor(factor, shift, larger, smaller, roundUp);
    }

    function quoteDeltaAtFactor(uint256 factor, uint16 shift, uint160 larger, uint160 smaller, bool roundUp)
        external
        pure
        returns (uint256 amount, uint32 code)
    {
        return _quoteDifferenceAndEventCodeAtFactor(factor, shift, larger, smaller, roundUp);
    }
}

contract FusedQuoteTest is Test {
    FusedQuoteHarness private engine;
    RoutingTestERC20 private token0;
    RoutingTestERC20 private token1;
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    function setUp() public {
        engine = new FusedQuoteHarness();
        RoutingTestERC20 a = new RoutingTestERC20("A", "A");
        RoutingTestERC20 b = new RoutingTestERC20("B", "B");
        (token0, token1) = address(a) < address(b) ? (a, b) : (b, a);
        for (uint256 i; i < 2; ++i) {
            address actor = i == 0 ? alice : bob;
            token0.mint(actor, uint256(1) << 248);
            token1.mint(actor, uint256(1) << 248);
            vm.startPrank(actor);
            token0.approve(address(engine), type(uint256).max);
            token1.approve(address(engine), type(uint256).max);
            vm.stopPrank();
        }
    }

    function testFuzz_FusedDeltaMatchesIndependentQuoteOracle(
        int32 tick,
        uint160 largerSeed,
        uint160 smallerSeed,
        bool roundUp
    ) public view {
        uint160 larger = uint160(bound(largerSeed, 1, type(uint160).max));
        uint160 smaller = uint160(bound(smallerSeed, 0, larger - 1));
        _assertQuote(tick, larger, smaller, roundUp);
    }

    function test_TickAndQuantityBoundaries() public view {
        int32[7] memory ticks =
            [type(int32).min, int32(-22_369_622), int32(-1), int32(0), int32(1), int32(22_369_622), type(int32).max];
        uint160[5] memory quantities =
            [uint160(1), uint160(2), uint160(type(uint128).max), uint160(type(uint128).max) + 1, type(uint160).max];
        for (uint256 i; i < ticks.length; ++i) {
            for (uint256 j; j < quantities.length; ++j) {
                for (uint256 side; side < 2; ++side) {
                    _assertQuote(ticks[i], quantities[j], 0, side != 0);
                    _assertQuote(ticks[i], quantities[j], quantities[j] - 1, side != 0);
                }
            }
        }
    }

    function test_RemainderBoundaryCases() public view {
        uint256 factor = uint256(1) << 128;
        _assertFactor(factor, 130, 2, 1, false, 0, 1);
        _assertFactor(factor, 130, 2, 1, true, 0, 0);
        _assertFactor(factor, 129, 2, 1, false, 1, 0);
        _assertFactor(factor, 129, 2, 1, true, 0, 0);
        _assertFactor(factor, 130, 5, 3, false, 1, 0);
        _assertFactor(factor, 130, 5, 3, true, 1, 1);
        _assertFactor(factor, 130, 5, 4, false, 0, 1);
        _assertFactor(factor, 130, 5, 4, true, 1, 1);
        _assertFactor(factor, 130, 5, 1, false, 1, 1);
        _assertFactor(factor, 130, 5, 1, true, 1, 1);
    }

    function testFuzz_PartialFillEventsAndBalances(
        int32 tick,
        uint128 quantitySeed,
        uint128 fillSeed,
        bool restingBid,
        bool uniform
    ) public {
        uint160 quantity = uint160(bound(quantitySeed, 2, type(uint128).max));
        uint160 fillQuantity = uint160(bound(fillSeed, 1, quantity - 1));
        vm.prank(alice);
        bytes32 original = engine.fill(_fill(tick, quantity, restingBid, false));
        if (uniform) {
            vm.prank(alice);
            engine.fill(_fill(tick, quantity, restingBid, false));
        }
        uint256 expected = QuoteMath.quoteValue(tick, quantity, restingBid)
            - QuoteMath.quoteValue(tick, quantity - fillQuantity, restingBid);
        uint256 beforeBase = token0.balanceOf(bob);
        uint256 beforeQuote = token1.balanceOf(bob);
        vm.recordLogs();
        vm.prank(bob);
        engine.fill(_fill(tick, fillQuantity, !restingBid, true));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = restingBid ? keccak256("BidMatched(bytes32,bytes32)") : keccak256("AskMatched(bytes32,bytes32)");
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(engine) || logs[i].topics[0] != topic) continue;
            (, bytes32 node) = abi.decode(logs[i].data, (bytes32, bytes32));
            assertEq(uint160(uint256(node) >> 64), fillQuantity);
            assertEq(uint32(uint256(node)), uint32(uint256(original)));
            uint32 code = uint32(uint256(node) >> 32);
            uint256 standalone = QuoteMath.quoteValue(tick, fillQuantity, restingBid);
            assertLe(code, 1);
            uint256 decoded = restingBid ? standalone - (1 - code) : standalone + (1 - code);
            assertEq(decoded, expected, "event quote matches settlement");
            ++found;
        }
        assertEq(found, 1, "exactly one leaf match");
        assertEq(token0.balanceOf(bob), restingBid ? beforeBase - fillQuantity : beforeBase + fillQuantity);
        assertEq(token1.balanceOf(bob), restingBid ? beforeQuote + expected : beforeQuote - expected);
        (bytes32 ask, bytes32 bid) = engine.roots(address(token0), address(token1), 0);
        assertEq(uint160(uint256(restingBid ? bid : ask) >> 64), (uniform ? quantity * 2 : quantity) - fillQuantity);
        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(token0), address(token1), 0, original);
        assertEq(baseAmount, restingBid ? fillQuantity : quantity - fillQuantity);
        assertEq(quoteAmount, restingBid ? QuoteMath.quoteValue(tick, quantity - fillQuantity, true) : expected);
    }

    function test_RepeatedPartialFillsTelescopeAndClaim() public {
        uint160[6] memory fills = [uint160(3), uint160(5), uint160(7), uint160(11), uint160(13), uint160(17)];
        for (uint256 side; side < 2; ++side) {
            bool restingBid = side != 0;
            int32 tick = -111_000_000;
            vm.prank(alice);
            bytes32 original = engine.fill(_fill(tick, 100, restingBid, false));
            uint256 beforeQuote = token1.balanceOf(bob);
            for (uint256 i; i < fills.length; ++i) {
                vm.prank(bob);
                engine.fill(_fill(tick, fills[i], !restingBid, true));
            }
            uint256 expected = QuoteMath.quoteValue(tick, 100, restingBid) - QuoteMath.quoteValue(tick, 44, restingBid);
            assertEq(token1.balanceOf(bob), restingBid ? beforeQuote + expected : beforeQuote - expected);
            vm.prank(alice);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(token0), address(token1), 0, original);
            assertEq(baseAmount, restingBid ? 56 : 44);
            assertEq(quoteAmount, restingBid ? QuoteMath.quoteValue(tick, 44, true) : expected);
            assertEq(token0.balanceOf(address(engine)), 0);
            assertEq(token1.balanceOf(address(engine)), 0);
        }
    }

    function _assertQuote(int32 tick, uint160 larger, uint160 smaller, bool roundUp) private view {
        (uint256 actual, uint32 code) = engine.quoteDelta(tick, larger, smaller, roundUp);
        uint256 expected = QuoteMath.quoteValue(tick, larger, roundUp) - QuoteMath.quoteValue(tick, smaller, roundUp);
        uint256 standalone = QuoteMath.quoteValue(tick, larger - smaller, roundUp);
        assertEq(actual, expected);
        assertEq(code, expected == standalone ? 1 : 0);
    }

    function _assertFactor(
        uint256 factor,
        uint16 shift,
        uint160 larger,
        uint160 smaller,
        bool roundUp,
        uint256 expected,
        uint32 code
    ) private view {
        (uint256 actual, uint32 actualCode) = engine.quoteDeltaAtFactor(factor, shift, larger, smaller, roundUp);
        assertEq(actual, expected);
        assertEq(actualCode, code);
    }

    function _fill(int32 tick, uint160 quantity, bool bid, bool noRest)
        private
        view
        returns (DeepstateV1.FillParams memory)
    {
        bytes32 order = bytes32((uint256(uint32(tick)) << 224) | (uint256(quantity) << 64));
        return DeepstateV1.FillParams(address(token0), address(token1), 0, order, bid, noRest, false);
    }
}
