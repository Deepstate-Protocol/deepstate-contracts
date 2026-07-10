// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title 32-Bit Tick Math
/// @notice Converts signed 32-bit logarithmic ticks into Q64.96 square-root prices.
/// @dev
/// The price at tick `t` is `2 ** (128 * t / 2**31)`. This maps the complete
/// signed 32-bit domain onto `[2**-128, 2**128)`. Adjacent ticks differ by about
/// 0.000413148 basis points. The implementation mirrors the constant-product
/// exponentiation strategy used by Uniswap TickMath, with constants regenerated
/// for this finer tick base and the full 32-bit magnitude.
library TickMath32 {
    /// @notice Return `sqrt(price) * 2**96` for a signed logarithmic tick.
    /// @param tick Tick in the complete `int32` domain.
    /// @return sqrtPriceX96 Q64.96 square-root price.
    function getSqrtRatioAtTick(int32 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(uint64(-int64(tick))) : uint256(uint32(tick));
        uint256 ratio = uint256(1) << 128;

        if (absTick & 0x00000001 != 0) ratio = (ratio * 0xffffffa746f41376f74124cd483186d4) >> 128;
        if (absTick & 0x00000002 != 0) ratio = (ratio * 0xffffff4e8de845adac77243cd0914b37) >> 128;
        if (absTick & 0x00000004 != 0) ratio = (ratio * 0xfffffe9d1bd1065a50971275792f1c83) >> 128;
        if (absTick & 0x00000008 != 0) ratio = (ratio * 0xfffffd3a37a3f8b07e7c4871dc00d76e) >> 128;
        if (absTick & 0x00000010 != 0) ratio = (ratio * 0xfffffa746f4fa1506788fbc89750bf71) >> 128;
        if (absTick & 0x00000020 != 0) ratio = (ratio * 0xfffff4e8debe025e24128a3d460731f1) >> 128;
        if (absTick & 0x00000040 != 0) ratio = (ratio * 0xffffe9d1bdf703aef21ea4dcfb0682d8) >> 128;
        if (absTick & 0x00000080 != 0) ratio = (ratio * 0xffffd3a37dda03133bde87a8379c8932) >> 128;
        if (absTick & 0x00000100 != 0) ratio = (ratio * 0xffffa7470363f4515426d76c762b6b61) >> 128;
        if (absTick & 0x00000200 != 0) ratio = (ratio * 0xffff4e8e25879bfa09ea263360240c1a) >> 128;
        if (absTick & 0x00000400 != 0) ratio = (ratio * 0xfffe9d1cc60ddab126de1aec4a87e7b8) >> 128;
        if (absTick & 0x00000800 != 0) ratio = (ratio * 0xfffd3a3b7814eb53cd7629d70fea116a) >> 128;
        if (absTick & 0x00001000 != 0) ratio = (ratio * 0xfffa747ea0040664238f92f792405805) >> 128;
        if (absTick & 0x00002000 != 0) ratio = (ratio * 0xfff4e91bff1b8c3d88338e0ebf284a4d) >> 128;
        if (absTick & 0x00004000 != 0) ratio = (ratio * 0xffe9d2b2f7db2755ddf1d28a378a438c) >> 128;
        if (absTick & 0x00008000 != 0) ratio = (ratio * 0xffd3a751c0f7e10bd3b9f8ae012fbe06) >> 128;
        if (absTick & 0x00010000 != 0) ratio = (ratio * 0xffa756521c8daed19f3a1b48fb94c589) >> 128;
        if (absTick & 0x00020000 != 0) ratio = (ratio * 0xff4ecb59511ec8a5301ba217ef18dd7c) >> 128;
        if (absTick & 0x00040000 != 0) ratio = (ratio * 0xfe9e115c7b8f884badd25995e79d2f09) >> 128;
        if (absTick & 0x00080000 != 0) ratio = (ratio * 0xfd3e0c0cf486c174853f3a5931e0ee03) >> 128;
        if (absTick & 0x00100000 != 0) ratio = (ratio * 0xfa83b2db722a033a7c25bb14315d7fcc) >> 128;
        if (absTick & 0x00200000 != 0) ratio = (ratio * 0xf5257d152486cc2c7b9d0c7aed980fc3) >> 128;
        if (absTick & 0x00400000 != 0) ratio = (ratio * 0xeac0c6e7dd24392ed02d75b3706e54fa) >> 128;
        if (absTick & 0x00800000 != 0) ratio = (ratio * 0xd744fccad69d6af439a68bb9902d3fde) >> 128;
        if (absTick & 0x01000000 != 0) ratio = (ratio * 0xb504f333f9de6484597d89b3754abe9f) >> 128;
        if (absTick & 0x02000000 != 0) ratio >>= 1;
        if (absTick & 0x04000000 != 0) ratio >>= 2;
        if (absTick & 0x08000000 != 0) ratio >>= 4;
        if (absTick & 0x10000000 != 0) ratio >>= 8;
        if (absTick & 0x20000000 != 0) ratio >>= 16;
        if (absTick & 0x40000000 != 0) ratio >>= 32;
        if (absTick & 0x80000000 != 0) ratio >>= 64;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // Convert Q128.128 to Q64.96 and round upward so the inverse mapping is stable.
        uint256 shifted = ratio >> 32;
        if (uint32(ratio) != 0) ++shifted;
        sqrtPriceX96 = uint160(shifted);
    }
}
