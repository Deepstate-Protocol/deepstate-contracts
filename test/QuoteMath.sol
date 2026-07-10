// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {TickMath32} from "../src/libraries/TickMath32.sol";

/// @dev Test oracle for the matching engine's exact factor/divisor settlement representation.
library QuoteMath {
    function quoteValue(int32 tick, uint160 quantity, bool roundUp) internal pure returns (uint256 quoteAmount) {
        if (quantity == 0) return 0;
        if (tick == 0) return quantity;
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);

        assembly ("memory-safe") {
            let productLow := mul(quantity, factor)
            // Keep the oracle independent from production's one-word product shortcut.
            // Test gas is irrelevant, so always reconstruct the high half of the product.
            let mm := mulmod(quantity, factor, not(0))
            let productHigh := sub(mm, add(productLow, lt(mm, productLow)))
            let remainder := 0

            switch shift
            case 0 {
                if productHigh { revert(0, 0) }
                quoteAmount := productLow
            }
            case 256 {
                quoteAmount := productHigh
                remainder := productLow
            }
            default {
                if shr(shift, productHigh) { revert(0, 0) }
                quoteAmount := or(shl(sub(256, shift), productHigh), shr(shift, productLow))
                remainder := and(productLow, sub(shl(shift, 1), 1))
            }
            if and(roundUp, iszero(iszero(remainder))) { quoteAmount := add(quoteAmount, 1) }
        }
    }
}
