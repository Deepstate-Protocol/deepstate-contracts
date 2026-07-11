// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {TickMath32} from "../src/libraries/TickMath32.sol";

contract TickMath32Test is Test {
    function test_ZeroTickIsOneToOne() public pure {
        assertEq(TickMath32.getSqrtRatioAtTick(0), uint160(1) << 96);
    }

    function test_KnownPowerOfTwoTicks() public pure {
        int32 powerTick = int32(1 << 27);
        assertEq(TickMath32.getSqrtRatioAtTick(powerTick), uint160(1) << 99);
        assertEq(TickMath32.getSqrtRatioAtTick(-powerTick), uint160(1) << 93);
    }

    function test_KnownPowerOfTwoPriceFactors() public pure {
        (uint256 positiveFactor, uint16 positiveShift) = TickMath32.getPriceFactorAtTick(67_108_864);
        assertEq(positiveFactor, uint256(1) << 128);
        assertEq(positiveShift, 125);

        (uint256 negativeFactor, uint16 negativeShift) = TickMath32.getPriceFactorAtTick(-67_108_864);
        assertEq(negativeFactor, uint256(1) << 128);
        assertEq(negativeShift, 131);
    }

    function test_FullDomainBoundariesAreRepresentableAndOrdered() public pure {
        uint160 minimum = TickMath32.getSqrtRatioAtTick(type(int32).min);
        uint160 aboveMinimum = TickMath32.getSqrtRatioAtTick(type(int32).min + 1);
        uint160 belowMaximum = TickMath32.getSqrtRatioAtTick(type(int32).max - 1);
        uint160 maximum = TickMath32.getSqrtRatioAtTick(type(int32).max);

        assertGt(minimum, 0);
        assertLt(minimum, aboveMinimum);
        assertLt(belowMaximum, maximum);
        assertLe(maximum, type(uint160).max);
    }

    function testFuzz_TicksAreStrictlyMonotonic(int32 tick) public pure {
        if (tick == type(int32).max) return;
        assertLt(TickMath32.getSqrtRatioAtTick(tick), TickMath32.getSqrtRatioAtTick(tick + 1));
    }
}
