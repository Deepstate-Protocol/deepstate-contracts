// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {TickMath32} from "../src/libraries/TickMath32.sol";

contract TickMath32Test is Test {
    uint256 private constant MAX_FACTOR_ERROR = 64;

    function test_KnownPowerOfTwoPriceFactors() public pure {
        (uint256 positiveFactor, uint16 positiveShift) = TickMath32.getPriceFactorAtTick(67_108_864);
        assertEq(positiveFactor, uint256(1) << 128);
        assertEq(positiveShift, 125);

        (uint256 negativeFactor, uint16 negativeShift) = TickMath32.getPriceFactorAtTick(-67_108_864);
        assertEq(negativeFactor, uint256(1) << 128);
        assertEq(negativeShift, 131);
    }

    function test_ZeroTickIsExactlyOneToOne() public pure {
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(0);
        assertEq(factor, uint256(1) << 128);
        assertEq(shift, 128);
    }

    function test_ReferenceVectors_MinimumAndLargeNegative() public pure {
        // BEGIN GENERATED TICK VECTORS
        _assertReference(-2147483648, 0x0000000000000000000000000000000100000000000000000000000000000000, 224);
        _assertReference(-2147483647, 0x000000000000000000000000000000010000008515921c751160b289896699ec, 224);
        _assertReference(-2020187722, 0x00000000000000000000000000000000ce950386e0077af407c095d15cca0e28, 218);
        _assertReference(-2000000000, 0x00000000000000000000000000000000c113b92dd01e446e0832dcaa6ab9f6f3, 217);
        _assertReference(-1971781780, 0x00000000000000000000000000000000e77046d49ca375830393a1e066315fcb, 216);
        _assertReference(-1895502299, 0x00000000000000000000000000000001338014eb832377dc263f28d54ef8a830, 213);
        _assertReference(-1500000000, 0x00000000000000000000000000000000f662bc407c3f8879681c67bb9d8adaf8, 195);
        _assertReference(-1234567890, 0x00000000000000000000000000000000e07dba5a552904e6e340168e3ddeab78, 183);
    }

    function test_ReferenceVectors_NegativeExponentBoundaries() public pure {
        _assertReference(-1073741824, 0x0000000000000000000000000000000100000000000000000000000000000000, 176);
        _assertReference(-626131176, 0x0000000000000000000000000000000101bca509f29e185c102311fcf1295675, 156);
        _assertReference(-574183375, 0x00000000000000000000000000000001423e13c6ff60ff1caa6c7d03281d24ec, 154);
        _assertReference(-536870913, 0x00000000000000000000000000000000ffffff7aea6e28ba5a1e33b2f9234215, 152);
        _assertReference(-536870912, 0x0000000000000000000000000000000100000000000000000000000000000000, 152);
        _assertReference(-536870911, 0x000000000000000000000000000000010000008515921c751160b289896699ec, 152);
        _assertReference(-67108865, 0x00000000000000000000000000000000ffffff7aea6e28ba5a1e33b2f9234215, 131);
        _assertReference(-67108864, 0x0000000000000000000000000000000100000000000000000000000000000000, 131);
    }

    function test_ReferenceVectors_AroundZero() public pure {
        _assertReference(-67108863, 0x000000000000000000000000000000010000008515921c751160b289896699ec, 131);
        _assertReference(-22369622, 0x00000000000000000000000000000000ffffffa746f41376f74124cd483186d4, 129);
        _assertReference(-22369621, 0x000000000000000000000000000000010000002c5c8601cc6b9e94213c72737a, 129);
        _assertReference(-2, 0x00000000000000000000000000000000fffffef5d4dc96a41f97562b4e07d117, 128);
        _assertReference(-1, 0x00000000000000000000000000000000ffffff7aea6e28ba5a1e33b2f9234215, 128);
        _assertReference(0, 0x0000000000000000000000000000000100000000000000000000000000000000, 128);
        _assertReference(1, 0x000000000000000000000000000000010000008515921c751160b289896699ec, 128);
        _assertReference(2, 0x000000000000000000000000000000010000010a2b247e198e6442c6ced237ae, 128);
    }

    function test_ReferenceVectors_PositiveExponentBoundaries() public pure {
        _assertReference(22369621, 0x00000000000000000000000000000000ffffffd3a37a05e383e14c90273c94f5, 127);
        _assertReference(22369622, 0x0000000000000000000000000000000100000058b90c0b48c6be5df846c5b2f0, 127);
        _assertReference(67108863, 0x00000000000000000000000000000000ffffff7aea6e28ba5a1e33b2f9234215, 125);
        _assertReference(67108864, 0x0000000000000000000000000000000100000000000000000000000000000000, 125);
        _assertReference(67108865, 0x000000000000000000000000000000010000008515921c751160b289896699ec, 125);
        _assertReference(141272518, 0x000000000000000000000000000000013e8caaf6c57a6b9135880372e3af62f7, 122);
        _assertReference(284914928, 0x00000000000000000000000000000000d54ae4f3fd85d45a3b3c46eb69209370, 115);
        _assertReference(536870911, 0x00000000000000000000000000000000ffffff7aea6e28ba5a1e33b2f9234215, 104);
    }

    function test_ReferenceVectors_LargePositive() public pure {
        _assertReference(536870912, 0x0000000000000000000000000000000100000000000000000000000000000000, 104);
        _assertReference(536870913, 0x000000000000000000000000000000010000008515921c751160b289896699ec, 104);
        _assertReference(604376798, 0x00000000000000000000000000000001032b36ca61a5f19f4bf4df8a93f005ea, 101);
        _assertReference(713025961, 0x00000000000000000000000000000000eab620d1c8f42507fc0c66b07eceb426, 96);
        _assertReference(745787207, 0x0000000000000000000000000000000143df9700828e92430845ce2b428b1b93, 95);
        _assertReference(816234878, 0x00000000000000000000000000000001672cc20d6f37b4f9430f788c94916f8b, 92);
        _assertReference(882052597, 0x000000000000000000000000000000015916bac41af75260c9ef8784ad5bec46, 89);
        _assertReference(920219821, 0x0000000000000000000000000000000119820681475da2ad080c70ee1f9e630f, 87);
    }

    function test_ReferenceVectors_MaximumAndLargePositive() public pure {
        _assertReference(1073741824, 0x0000000000000000000000000000000100000000000000000000000000000000, 80);
        _assertReference(1234567890, 0x0000000000000000000000000000000123ee6dcb97dd0237b626982288448827, 73);
        _assertReference(1500000000, 0x0000000000000000000000000000000109fd4e7fec2f26e13f6c5f9c4c8186a5, 61);
        _assertReference(1900777530, 0x00000000000000000000000000000000faf89642f07cc24141f27965d0b898f7, 43);
        _assertReference(1914724161, 0x00000000000000000000000000000000c151ae16fff368738f8b4f12b79bb5f2, 42);
        _assertReference(2000000000, 0x00000000000000000000000000000001536de4906b3d1edb8068749a7b443387, 39);
        _assertReference(2147483646, 0x00000000000000000000000000000000fffffef5d4dc96a41f97562b4e07d117, 32);
        _assertReference(2147483647, 0x00000000000000000000000000000000ffffff7aea6e28ba5a1e33b2f9234215, 32);
        // END GENERATED TICK VECTORS
    }

    function testFuzz_PriceFactorsAreStrictlyMonotonic(int32 tick) public pure {
        if (tick == type(int32).max) return;

        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
        (uint256 nextFactor, uint16 nextShift) = TickMath32.getPriceFactorAtTick(tick + 1);
        uint16 shiftDelta = shift > nextShift ? shift - nextShift : nextShift - shift;
        assertLe(shiftDelta, 1);

        bool increasing;
        if (shift == nextShift) {
            increasing = factor < nextFactor;
        } else if (shift > nextShift) {
            increasing = factor < nextFactor << shiftDelta;
        } else {
            increasing = factor << shiftDelta < nextFactor;
        }
        assertTrue(increasing);
    }

    function testFuzz_PriceFactorShiftIsBounded(int32 tick) public pure {
        (, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
        assertGe(shift, 32);
        assertLe(shift, 224);
    }

    function _assertReference(int32 tick, uint256 expectedFactor, uint16 expectedShift) private pure {
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
        assertEq(shift, expectedShift);
        uint256 error = factor > expectedFactor ? factor - expectedFactor : expectedFactor - factor;
        assertLe(error, MAX_FACTOR_ERROR);
    }
}
