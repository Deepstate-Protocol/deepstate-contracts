// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title 32-Bit Tick Math
/// @notice Converts signed 32-bit logarithmic ticks into Q64.96 square-root prices.
/// @dev
/// The price at tick `t` is `2 ** (96 * t / 2**31)`. This maps the complete
/// signed 32-bit domain onto `[2**-96, 2**96)`. Adjacent ticks differ by about
/// 0.000309861 basis points. The implementation mirrors the constant-product
/// exponentiation strategy used by Uniswap TickMath, with constants regenerated
/// for this finer tick base and the full 32-bit magnitude.
library TickMath32 {
    /// @notice Return `sqrt(price) * 2**96` for a signed logarithmic tick.
    /// @param tick Tick in the complete `int32` domain.
    /// @return sqrtPriceX96 Q64.96 square-root price.
    function getSqrtRatioAtTick(int32 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick = tick < 0 ? uint256(uint64(-int64(tick))) : uint256(uint32(tick));
            uint256 ratio = uint256(1) << 128;

            if (absTick & 0x00000001 != 0) ratio = (ratio * 0xffffffbd75370bb73fa17c895f1d1e10) >> 128;
            if (absTick & 0x00000002 != 0) ratio = (ratio * 0xffffff7aea6e28ba5a1e33b2f9234215) >> 128;
            if (absTick & 0x00000004 != 0) ratio = (ratio * 0xfffffef5d4dc96a41f97562b4e07d117) >> 128;
            if (absTick & 0x00000008 != 0) ratio = (ratio * 0xfffffdeba9ba4205ec0a898fcd6f94eb) >> 128;
            if (absTick & 0x00000010 != 0) ratio = (ratio * 0xfffffbd75378d702870599268a464fd0) >> 128;
            if (absTick & 0x00000020 != 0) ratio = (ratio * 0xfffff7aea702f9dfa5d5d3bb9279d257) >> 128;
            if (absTick & 0x00000040 != 0) ratio = (ratio * 0xffffef5d4e4b23288b1a7bde307cacf0) >> 128;
            if (absTick & 0x00000080 != 0) ratio = (ratio * 0xffffdeba9dab03ed16130032411d9853) >> 128;
            if (absTick & 0x00000100 != 0) ratio = (ratio * 0xffffbd753fa8fe023cb7f01a95a85618) >> 128;
            if (absTick & 0x00000200 != 0) ratio = (ratio * 0xffff7aea909dd26544c77f0bdc9ee441) >> 128;
            if (absTick & 0x00000400 != 0) ratio = (ratio * 0xfffef5d5666aec52038389364772b7c1) >> 128;
            if (absTick & 0x00000800 != 0) ratio = (ratio * 0xfffdebabe19266e494faa08bf06f95d3) >> 128;
            if (absTick & 0x00001000 != 0) ratio = (ratio * 0xfffbd75c161287e4a9d98eb29b205e4f) >> 128;
            if (absTick & 0x00002000 != 0) ratio = (ratio * 0xfff7aec977b80143043f6d3dd6d17ccb) >> 128;
            if (absTick & 0x00004000 != 0) ratio = (ratio * 0xffef5dd81c9c14e14a6e387701ae244c) >> 128;
            if (absTick & 0x00008000 != 0) ratio = (ratio * 0xffdebcc4e4eb184180b1fe46ef229c18) >> 128;
            if (absTick & 0x00010000 != 0) ratio = (ratio * 0xffbd7ddc30bb29b9304ec1b3093eeb73) >> 128;
            if (absTick & 0x00020000 != 0) ratio = (ratio * 0xff7b0cffbe1596751b6382200cc3b5d9) >> 128;
            if (absTick & 0x00040000 != 0) ratio = (ratio * 0xfef65f0afb18a3ca235953e0a4f60a89) >> 128;
            if (absTick & 0x00080000 != 0) ratio = (ratio * 0xfdedd1b496a89f34c46757b38a53619a) >> 128;
            if (absTick & 0x00100000 != 0) ratio = (ratio * 0xfbdfed6ce5f09c489da5ff395ecae2e7) >> 128;
            if (absTick & 0x00200000 != 0) ratio = (ratio * 0xf7d0df730ad13bb8fe90d496d60fb6ea) >> 128;
            if (absTick & 0x00400000 != 0) ratio = (ratio * 0xefe4b99bdcdaf5cb46561cf6948db912) >> 128;
            if (absTick & 0x00800000 != 0) ratio = (ratio * 0xe0ccdeec2a94e111065895048dd333ca) >> 128;
            if (absTick & 0x01000000 != 0) ratio = (ratio * 0xc5672a115506dadd3e2ad0c964dd9f37) >> 128;
            if (absTick & 0x02000000 != 0) ratio = (ratio * 0x9837f0518db8a96f46ad23182e42f6f6) >> 128;
            if (absTick & 0x04000000 != 0) ratio = (ratio * 0x5a827999fcef32422cbec4d9baa55f4f) >> 128;
            if (absTick & 0x08000000 != 0) ratio = (ratio * 0x20000000000000000000000000000000) >> 128;
            if (absTick & 0x10000000 != 0) ratio = (ratio * 0x04000000000000000000000000000000) >> 128;
            if (absTick & 0x20000000 != 0) ratio = (ratio * 0x00100000000000000000000000000000) >> 128;
            if (absTick & 0x40000000 != 0) ratio = (ratio * 0x00000100000000000000000000000000) >> 128;
            if (absTick & 0x80000000 != 0) ratio = (ratio * 0x00000000000100000000000000000000) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;

            // Convert Q128.128 to Q64.96 and round upward so the inverse mapping is stable.
            uint256 shifted = ratio >> 32;
            if (uint32(ratio) != 0) ++shifted;
            sqrtPriceX96 = uint160(shifted);
        }
    }

    /// @notice Return the fractional Q128 price factor and binary divisor shift for a tick.
    /// @dev `price = factor / 2**shift`. The nearest integer exponent is used so ticks
    /// close to a lower boundary do not become dense six-nibble complements.
    function getPriceFactorAtTick(int32 tick) internal pure returns (uint256 factor, uint16 shift) {
        unchecked {
            int256 scaledTick = int256(tick) * 3;
            int256 integerExponent = scaledTick >> 26;
            uint256 fraction = uint256(scaledTick - (integerExponent << 26));

            if (fraction <= 0x2000000) {
                // Tables encode a 24-bit fraction and `_fractionFactor` folds in
                // the remaining 2 low bits. Invert the sparse factor around Q128
                // to obtain the positive fractional multiplier.
                uint256 inverseFactor = _fractionFactor(fraction);
                factor = type(uint256).max / inverseFactor + 1;
            } else {
                ++integerExponent;
                factor = _fractionFactor(0x4000000 - fraction);
            }

            shift = uint16(uint256(128 - integerExponent));
        }
    }

    function _fractionFactor(uint256 fraction) private pure returns (uint256 factor) {
        unchecked {
            uint256 residual = fraction & 0x03;
            fraction >>= 2;

            factor = _factor0(fraction & 0x0f);
            uint256 nibble = (fraction >> 4) & 0x0f;
            if (nibble != 0) factor = (factor * _factor1(nibble)) >> 128;
            nibble = (fraction >> 8) & 0x0f;
            if (nibble != 0) factor = (factor * _factor2(nibble)) >> 128;
            nibble = (fraction >> 12) & 0x0f;
            if (nibble != 0) factor = (factor * _factor3(nibble)) >> 128;
            nibble = (fraction >> 16) & 0x0f;
            if (nibble != 0) factor = (factor * _factor4(nibble)) >> 128;
            nibble = fraction >> 20;
            if (nibble != 0) factor = (factor * _factor5(nibble)) >> 128;
            if (residual != 0) factor = (factor * _residualFactor(residual)) >> 128;
        }
    }

    function _residualFactor(uint256 residual) private pure returns (uint256 factor) {
        assembly ("memory-safe") {
            switch residual
            case 1 { factor := 0xffffffd3a37a05e383e14c90273c94f5 }
            case 2 { factor := 0xffffffa746f41376f74124cd483186d4 }
            default { factor := 0xffffff7aea6e28ba5a1e33b2f9234215 }
        }
    }

    function _factor0(uint256 nibble) private pure returns (uint256 factor) {
        assembly ("memory-safe") {
            switch nibble
            case 0 { factor := 0x100000000000000000000000000000000 }
            case 1 { factor := 0xffffff4e8de845adac77243cd0914b37 }
            case 2 { factor := 0xfffffe9d1bd1065a50971275792f1c83 }
            case 3 { factor := 0xfffffdeba9ba4205ec0a898fcd6f94e9 }
            case 4 { factor := 0xfffffd3a37a3f8b07e7c4871dc00d76e }
            case 5 { factor := 0xfffffc88c58e2a5a07970e01eea908e4 }
            case 6 { factor := 0xfffffbd75378d702870599268a464fcf }
            case 7 { factor := 0xfffffb25e163fea9fc72a8c66eced432 }
            case 8 { factor := 0xfffffa746f4fa1506788fbc89750bf71 }
            case 9 { factor := 0xfffff9c2fd3bbef5c7f3511439f23c11 }
            case 10 { factor := 0xfffff9118b28579a1d5c6790c7f175ab }
            case 11 { factor := 0xfffff86019156b3d676efe25eda498b3 }
            case 12 { factor := 0xfffff7aea702f9dfa5d5d3bb9279d256 }
            case 13 { factor := 0xfffff6fd34f10380d83ba739d8f75046 }
            case 14 { factor := 0xfffff64bc2df8820fe4b37891ebb409f }
            default { factor := 0xfffff59a50ce87c017af4391fc7bd1b4 }
        }
    }

    function _factor1(uint256 nibble) private pure returns (uint256 factor) {
        assembly ("memory-safe") {
            switch nibble
            case 1 { factor := 0xfffff4e8debe025e24128a3d460731f1 }
            case 2 { factor := 0xffffe9d1bdf703aef21ea4dcfb0682d8 }
            case 3 { factor := 0xffffdeba9dab03ed16130032411d9852 }
            case 4 { factor := 0xffffd3a37dda03133bde87a8379c8932 }
            case 5 { factor := 0xffffc88c5e84011c0f7061c1f8747ebb }
            case 6 { factor := 0xffffbd753fa8fe023cb7f01a95a85617 }
            case 7 { factor := 0xffffb25e2148f9c06fa4cf6516bd41ca }
            case 8 { factor := 0xffffa7470363f4515426d76c762b6b61 }
            case 9 { factor := 0xffff9c2fe5f9edaf962e1b139ece9519 }
            case 10 { factor := 0xffff9118c90ae5d5e1aae8556956bbce }
            case 11 { factor := 0xffff8601ac96dcbee28dc84499b8b8dd }
            case 12 { factor := 0xffff7aea909dd26544c77f0bdc9ee440 }
            case 13 { factor := 0xffff6fd3751fc6c3b4490bedc4d9b6af }
            case 14 { factor := 0xffff64bc5a1cb9d4dd03a944c8d06bfb }
            default { factor := 0xffff59a53f94ab936ae8cc833ff1a560 }
        }
    }

    function _factor2(uint256 nibble) private pure returns (uint256 factor) {
        assembly ("memory-safe") {
            switch nibble
            case 1 { factor := 0xffff4e8e25879bfa09ea263360240c1a }
            case 2 { factor := 0xfffe9d1cc60ddab126de1aec4a87e7b8 }
            case 3 { factor := 0xfffdebabe19266e494faa08bf06f95d2 }
            case 4 { factor := 0xfffd3a3b7814eb53cd7629d70fea116a }
            case 5 { factor := 0xfffc88cb899512be849eb1004af9a6da }
            case 6 { factor := 0xfffbd75c161287e4a9d98eb29b205e4e }
            case 7 { factor := 0xfffb25ed1d8cf58667a3511be150639f }
            case 8 { factor := 0xfffa747ea0040664238f92f792405805 }
            case 9 { factor := 0xfff9c3109d77653e7e48d2997f2379d1 }
            case 10 { factor := 0xfff911a315e6bcd6539048f8bac58ea3 }
            case 11 { factor := 0xfff860360951b7ecba3dc0ba9b0a7c4d }
            case 12 { factor := 0xfff7aec977b80143043f6d3dd6d17cca }
            case 13 { factor := 0xfff6fd5d6119439abe99c1a5c03bd998 }
            case 14 { factor := 0xfff64bf1c57529b5b16747e59b571acc }
            default { factor := 0xfff59a86a4cb5e55dfd877cc112a9619 }
        }
    }

    function _factor3(uint256 nibble) private pure returns (uint256 factor) {
        assembly ("memory-safe") {
            switch nibble
            case 1 { factor := 0xfff4e91bff1b8c3d88338e0ebf284a4d }
            case 2 { factor := 0xffe9d2b2f7db2755ddf1d28a378a438c }
            case 3 { factor := 0xffdebcc4e4eb184180b1fe46ef229c17 }
            case 4 { factor := 0xffd3a751c0f7e10bd3b9f8ae012fbe06 }
            case 5 { factor := 0xffc8925986ae3ed08f06593fe67ac1bf }
            case 6 { factor := 0xffbd7ddc30bb29b9304ec1b3093eeb72 }
            case 7 { factor := 0xffb269d9b9cbd4fa6c269773746a69d9 }
            case 8 { factor := 0xffa756521c8daed19f3a1b48fb94c589 }
            case 9 { factor := 0xff9c434553ae60823fa7dde946a88ebf }
            case 10 { factor := 0xff9130b359dbce534e76903b39de605f }
            case 11 { factor := 0xff861e9c29c4178cc9272e1140473f0b }
            case 12 { factor := 0xff7b0cffbe1596751b6382200cc3b5d9 }
            case 13 { factor := 0xff6ffbde117ee04e90c901f772e3d464 }
            case 14 { factor := 0xff64eb371eaec554c6d000c306ca5e48 }
            default { factor := 0xff59db0ae05450ba1ecf379840cb103d }
        }
    }

    function _factor4(uint256 nibble) private pure returns (uint256 factor) {
        assembly ("memory-safe") {
            switch nibble
            case 1 { factor := 0xff4ecb59511ec8a5301ba217ef18dd7c }
            case 2 { factor := 0xfe9e115c7b8f884badd25995e79d2f09 }
            case 3 { factor := 0xfdedd1b496a89f34c46757b38a53619a }
            case 4 { factor := 0xfd3e0c0cf486c174853f3a5931e0ee03 }
            case 5 { factor := 0xfc8ec01121e447bb455d621825da76cd }
            case 6 { factor := 0xfbdfed6ce5f09c489da5ff395ecae2e6 }
            case 7 { factor := 0xfb3193cc4227c3f46f66a72687c5c9a8 }
            case 8 { factor := 0xfa83b2db722a033a7c25bb14315d7fcc }
            case 9 { factor := 0xf9d64a46eb939f352d2e093e4110a050 }
            case 10 { factor := 0xf92959bb5dd4ba7434b7e1b1c86a6355 }
            case 11 { factor := 0xf87ce0e5b2094d9bbff35cfc575603f6 }
            case 12 { factor := 0xf7d0df730ad13bb8fe90d496d60fb6ea }
            case 13 { factor := 0xf7255510c4288238d1b490ead1a26390 }
            case 14 { factor := 0xf67a416c733f846d81897dca4e77a30e }
            default { factor := 0xf5cfa433e653729065e4527c9e33781c }
        }
    }

    function _factor5(uint256 nibble) private pure returns (uint256 factor) {
        assembly ("memory-safe") {
            switch nibble
            case 1 { factor := 0xf5257d152486cc2c7b9d0c7aed980fc3 }
            case 2 { factor := 0xeac0c6e7dd24392ed02d75b3706e54fa }
            case 3 { factor := 0xe0ccdeec2a94e111065895048dd333c8 }
            case 4 { factor := 0xd744fccad69d6af439a68bb9902d3fde }
            case 5 { factor := 0xce248c151f8480e3e235838f95f2c6ec }
            case 6 { factor := 0xc5672a115506dadd3e2ad0c964dd9f36 }
            case 7 { factor := 0xbd08a39f580c36bea8811fb66d0faf78 }
            case 8 { factor := 0xb504f333f9de6484597d89b3754abe9f }
            case 9 { factor := 0xad583eea42a14ac64980a8c8f59a2ec4 }
            case 10 { factor := 0xa5fed6a9b15138ea1cbd7f621710701a }
            case 11 { factor := 0x9ef5326091a111ada0911f09ebb9fdcf }
            case 12 { factor := 0x9837f0518db8a96f46ad23182e42f6f6 }
            case 13 { factor := 0x91c3d373ab11c3360fd6d8e0ae5ac9d6 }
            case 14 { factor := 0x8b95c1e3ea8bd6e6fbe4628758a53c8f }
            default { factor := 0x85aac367cc487b14c5c95b8c2154c1b0 }
        }
    }
}
