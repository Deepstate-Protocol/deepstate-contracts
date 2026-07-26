// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LibBit} from "solady/utils/LibBit.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {TickMath32} from "./libraries/TickMath32.sol";

/// @dev Minimal engine surface read by the lifecycle module before an unlock starts.
interface IDeepstateFeeConfig {
    function feeConfig() external view returns (address recipient, uint16 bps);
}

/// @title V4 Swap Manager Module
/// @notice Immutable compatibility code used by `DeepstateV1` for the Uniswap V4 swap lifecycle.
/// @dev
/// The engine invokes `swapLimits` with `STATICCALL` and forwards V4 lifecycle selectors with
/// `DELEGATECALL`. Delegate execution is necessary because transient flash-accounting slots and
/// token balances belong to the engine address routers interact with. This module contains no
/// `SSTORE`, cannot select another implementation, and is deployed immutably by the engine's
/// constructor. Radix traversal and all persistent order-book mutations remain in `DeepstateV1`.
contract V4SwapManagerModule {
    using SafeCast for uint256;
    using SafeTransferLib for address;

    /// @dev Address of this module outside delegate execution.
    address private immutable _SELF = address(this);

    uint256 private constant _BPS_DENOMINATOR = 10_000;
    uint256 private constant _FEE_DELTA_DOMAIN = uint256(1) << 255;
    uint160 private constant _MIN_SQRT_PRICE_X96 = uint160(1) << 48;
    uint160 private constant _MAX_SQRT_PRICE_X96 = uint160(1) << 144;
    bytes32 private constant _REENTRANCY_GUARD_SLOT =
        0xc55a21be1c6e869c49c7a5860f6c3a83187eb30a12bcd0421f3cf4f5871dccff;
    bytes32 private constant _UNLOCKED_SLOT = 0xc090fc4683624cfc3884e9d8de5eca132f2d0ec062aff75d43c0465d5ceeab23;
    bytes32 private constant _NONZERO_DELTA_COUNT_SLOT =
        0x7d4b3164c6e45b97e7d87b7125a44c5828d005af88f9d751cfd78729c5d99a0b;
    bytes32 private constant _SYNCED_RESERVES_SLOT = 0x1e0745a7db1623981f0b2a5d4232364c00787266eb75ad546f190e6cebe9bd95;
    bytes32 private constant _SYNCED_CURRENCY_SLOT = 0x27e098c505d44ec3574004bca052aabf76bd35004c182099d8c575fb238593b9;
    bytes32 private constant _LOCKER_SLOT = 0x198ec2e3efda97c2a9180e31e13439f0e12f61966939866853ea078807be2ced;
    bytes32 private constant _FEE_CONFIG_SLOT = 0xd798799899323e18f949ed5c8519366873a3e4d42f62efbb6ca28650ee8ca5ad;
    bytes32 private constant _FEE_TOKEN_COUNT_SLOT = 0xd3980f34eaac5a0e07116dff32f6bc4a745c58b07f50e21f605765a5ef62b1df;
    bytes32 private constant _FEE_TOKEN_LIST_DOMAIN =
        0x68efe0db05419b00987a4709a78b0a491ad2695832724764f375020bcc45228d;

    /// @notice Square-root limit is outside the representable Deepstate price domain.
    /// @dev Matches the Uniswap V4 `Pool.PriceLimitOutOfBounds(uint160)` error selector.
    error PriceLimitOutOfBounds(uint160 sqrtPriceLimitX96);
    /// @notice Reentrant call attempted while an engine operation is active.
    error ReentrantCall();

    /// @dev Restrict mutable lifecycle methods to the engine's active unlock callback.
    modifier onlyLocker() {
        bool unlocked;
        address locker;
        /// @solidity memory-safe-assembly
        assembly {
            unlocked := tload(_UNLOCKED_SLOT)
            locker := tload(_LOCKER_SLOT)
        }
        if (address(this) == _SELF || !unlocked || msg.sender != locker) revert IPoolManager.ManagerLocked();
        _;
    }

    /// @dev Math entrypoints are callable only on the immutable module itself. If their selectors
    /// reach the engine fallback, delegate context changes `address(this)` and the call is rejected.
    modifier onlyDirect() {
        _requireDirectCall();
        _;
    }

    function _requireDirectCall() private view {
        if (address(this) != _SELF) revert IPoolManager.ManagerLocked();
    }

    /// @notice Derive executable limits for one V4-shaped swap request.
    function swapLimits(int256 amountSpecified, uint160 sqrtPriceLimitX96, bool zeroForOne, uint16 feeBps)
        external
        view
        onlyDirect
        returns (int32 tick, uint160 baseLimit, uint256 quoteLimit)
    {
        if (amountSpecified == 0) revert IPoolManager.SwapAmountCannotBeZero();

        tick = _limitTick(sqrtPriceLimitX96, zeroForOne);
        bool exactInput = amountSpecified < 0;
        uint256 specifiedAmount = _absoluteAmount(amountSpecified);
        baseLimit = type(uint160).max;
        quoteLimit = type(uint256).max;
        if (zeroForOne == exactInput) {
            uint256 requestedBase = exactInput ? specifiedAmount : _grossOutput(specifiedAmount, feeBps);
            // forge-lint: disable-next-line(unsafe-typecast)
            baseLimit = requestedBase > type(uint160).max ? type(uint160).max : uint160(requestedBase);
        } else {
            quoteLimit = exactInput ? specifiedAmount : _grossOutput(specifiedAmount, feeBps);
        }
    }

    /// @notice Convert a Q64.96 limit into a conservative executable Deepstate tick.
    function limitTick(uint160 sqrtPriceLimitX96, bool zeroForOne) external view onlyDirect returns (int32 tick) {
        tick = _limitTick(sqrtPriceLimitX96, zeroForOne);
    }

    /// @notice Open a canonical V4 flash-accounting session at the engine address.
    function unlock(bytes calldata data) external returns (bytes memory result) {
        if (address(this) == _SELF) revert IPoolManager.ManagerLocked();

        bool alreadyUnlocked;
        bool entered;
        /// @solidity memory-safe-assembly
        assembly {
            alreadyUnlocked := tload(_UNLOCKED_SLOT)
            entered := tload(_REENTRANCY_GUARD_SLOT)
        }
        if (alreadyUnlocked) revert IPoolManager.AlreadyUnlocked();
        if (entered) revert ReentrantCall();

        (address recipient, uint16 feeBps) = IDeepstateFeeConfig(address(this)).feeConfig();
        uint256 config = uint256(uint160(recipient)) | (uint256(feeBps) << 160);
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_REENTRANCY_GUARD_SLOT, 1)
            tstore(_UNLOCKED_SLOT, 1)
            tstore(_LOCKER_SLOT, caller())
            tstore(_FEE_CONFIG_SLOT, config)
        }

        result = IUnlockCallback(msg.sender).unlockCallback(data);

        uint256 nonzeroDeltaCount;
        /// @solidity memory-safe-assembly
        assembly {
            nonzeroDeltaCount := tload(_NONZERO_DELTA_COUNT_SLOT)
        }
        if (nonzeroDeltaCount != 0) revert IPoolManager.CurrencyNotSettled();

        /// @solidity memory-safe-assembly
        assembly {
            tstore(_UNLOCKED_SLOT, 0)
            tstore(_LOCKER_SLOT, 0)
        }
        if (config != 0) _settleFees(config);

        /// @solidity memory-safe-assembly
        assembly {
            tstore(_FEE_CONFIG_SLOT, 0)
            tstore(_REENTRANCY_GUARD_SLOT, 0)
        }
    }

    /// @notice Checkpoint the engine's balance before ERC20 settlement.
    function sync(Currency currency) external onlyLocker {
        address token = Currency.unwrap(currency);
        if (token == address(0)) {
            /// @solidity memory-safe-assembly
            assembly {
                tstore(_SYNCED_CURRENCY_SLOT, 0)
            }
        } else {
            uint256 tokenBalance = SafeTransferLib.balanceOf(token, address(this));
            /// @solidity memory-safe-assembly
            assembly {
                tstore(_SYNCED_CURRENCY_SLOT, token)
                tstore(_SYNCED_RESERVES_SLOT, tokenBalance)
            }
        }
    }

    /// @notice Pay the callback an available positive flash-accounting balance.
    function take(Currency currency, address to, uint256 amount) external onlyLocker {
        int128 amountDelta = amount.toInt128();
        unchecked {
            _accountDelta(Currency.unwrap(currency), -amountDelta, msg.sender);
        }
        _safeTransferOut(Currency.unwrap(currency), to, amount);
    }

    /// @notice Credit the callback for native value or ERC20 value transferred since `sync`.
    function settle() external payable onlyLocker returns (uint256 paid) {
        paid = _settle(msg.sender);
    }

    /// @notice Credit another account for value supplied by the active callback.
    function settleFor(address recipient) external payable onlyLocker returns (uint256 paid) {
        paid = _settle(recipient);
    }

    /// @notice Forgo an exact positive flash-accounting balance.
    function clear(Currency currency, uint256 amount) external onlyLocker {
        address token = Currency.unwrap(currency);
        int256 current = _currencyDelta(msg.sender, token);
        int128 amountDelta = amount.toInt128();
        if (current != amountDelta) revert IPoolManager.MustClearExactPositiveDelta();
        unchecked {
            _accountDelta(token, -amountDelta, msg.sender);
        }
    }

    /// @notice Read one transient slot in the caller's storage context.
    function exttload(bytes32 slot) external view returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @notice Read several transient slots in the caller's storage context.
    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory values) {
        values = new bytes32[](slots.length);
        for (uint256 i; i < slots.length;) {
            bytes32 value;
            bytes32 slot = slots[i];
            /// @solidity memory-safe-assembly
            assembly {
                value := tload(slot)
            }
            values[i] = value;
            unchecked {
                ++i;
            }
        }
    }

    function _settle(address recipient) private returns (uint256 paid) {
        address token;
        /// @solidity memory-safe-assembly
        assembly {
            token := tload(_SYNCED_CURRENCY_SLOT)
        }

        if (token == address(0)) {
            paid = msg.value;
        } else {
            if (msg.value != 0) revert IPoolManager.NonzeroNativeValue();
            uint256 reservesBefore;
            /// @solidity memory-safe-assembly
            assembly {
                reservesBefore := tload(_SYNCED_RESERVES_SLOT)
            }
            paid = SafeTransferLib.balanceOf(token, address(this)) - reservesBefore;
            /// @solidity memory-safe-assembly
            assembly {
                tstore(_SYNCED_CURRENCY_SLOT, 0)
            }
        }

        _accountDelta(token, paid.toInt128(), recipient);
    }

    function _accountDelta(address token, int128 amount, address target) private {
        if (amount == 0) return;

        bytes32 slot = _currencyDeltaSlot(target, token);
        int256 previous;
        /// @solidity memory-safe-assembly
        assembly {
            previous := tload(slot)
        }
        int256 next = previous + amount;
        uint256 count;
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, next)
            count := tload(_NONZERO_DELTA_COUNT_SLOT)
        }

        if (next == 0) {
            unchecked {
                --count;
            }
            /// @solidity memory-safe-assembly
            assembly {
                tstore(_NONZERO_DELTA_COUNT_SLOT, count)
            }
        } else if (previous == 0) {
            unchecked {
                ++count;
            }
            /// @solidity memory-safe-assembly
            assembly {
                tstore(_NONZERO_DELTA_COUNT_SLOT, count)
            }
        }
    }

    function _currencyDelta(address target, address token) private view returns (int256 delta) {
        bytes32 slot = _currencyDeltaSlot(target, token);
        /// @solidity memory-safe-assembly
        assembly {
            delta := tload(slot)
        }
    }

    function _currencyDeltaSlot(address target, address token) private pure returns (bytes32 slot) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(0x20, and(token, 0xffffffffffffffffffffffffffffffffffffffff))
            slot := keccak256(0x00, 0x40)
        }
    }

    function _settleFees(uint256 config) private {
        // forge-lint: disable-next-line(unsafe-typecast)
        address recipient = address(uint160(config));
        uint256 count;
        /// @solidity memory-safe-assembly
        assembly {
            count := tload(_FEE_TOKEN_COUNT_SLOT)
            tstore(_FEE_TOKEN_COUNT_SLOT, 0)
        }

        for (uint256 i; i < count;) {
            bytes32 tokenSlot = _feeTokenSlot(i);
            address token;
            /// @solidity memory-safe-assembly
            assembly {
                token := tload(tokenSlot)
                tstore(tokenSlot, 0)
            }

            bytes32 feeSlot = bytes32(_FEE_DELTA_DOMAIN | uint256(uint160(token)));
            uint256 amount;
            /// @solidity memory-safe-assembly
            assembly {
                amount := tload(feeSlot)
                tstore(feeSlot, 0)
            }
            if (amount != 0) _safeTransferOut(token, recipient, amount);

            unchecked {
                ++i;
            }
        }
    }

    function _feeTokenSlot(uint256 index) private pure returns (bytes32 slot) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, _FEE_TOKEN_LIST_DOMAIN)
            mstore(0x20, index)
            slot := keccak256(0x00, 0x40)
        }
    }

    function _safeTransferOut(address token, address to, uint256 amount) private {
        if (token == address(0)) {
            to.safeTransferETH(amount);
        } else {
            token.safeTransfer(to, amount);
        }
    }

    function _limitTick(uint160 sqrtPriceLimitX96, bool zeroForOne) private pure returns (int32 tick) {
        if (sqrtPriceLimitX96 <= _MIN_SQRT_PRICE_X96 || sqrtPriceLimitX96 >= _MAX_SQRT_PRICE_X96) {
            revert PriceLimitOutOfBounds(sqrtPriceLimitX96);
        }

        uint256 sqrtPrice = uint256(sqrtPriceLimitX96);
        uint256 mostSignificantBit = LibBit.fls(sqrtPrice);
        uint256 normalized = mostSignificantBit > 127
            ? sqrtPrice >> (mostSignificantBit - 127)
            : sqrtPrice << (127 - mostSignificantBit);
        uint256 fractionalLog;
        for (uint256 bit = uint256(1) << 31; bit != 0; bit >>= 1) {
            /// @solidity memory-safe-assembly
            assembly {
                normalized := shr(127, mul(normalized, normalized))
            }
            if (normalized >= uint256(1) << 128) {
                normalized >>= 1;
                fractionalLog |= bit;
            }
        }

        // `sqrtPriceLimitX96` is uint160, so its MSB is at most 159; the loop sets only 32 bits.
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 integerLog = int256(mostSignificantBit) - 96;
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 log2Q32 = integerLog * int256(uint256(1) << 32) + int256(fractionalLog);
        // The strict square-root bounds prove the candidate fits in the signed 32-bit tick domain.
        // forge-lint: disable-next-line(unsafe-typecast)
        tick = int32(log2Q32 / 96);

        uint256 limitQuote = _sqrtPriceQuoteAtMaxQuantity(sqrtPriceLimitX96);
        if (_quoteValueAtMaxQuantity(tick) > limitQuote) {
            unchecked {
                --tick;
            }
        } else if (tick != type(int32).max && _quoteValueAtMaxQuantity(tick + 1) <= limitQuote) {
            unchecked {
                ++tick;
            }
        }

        if (zeroForOne && tick != type(int32).max && _quoteValueAtMaxQuantity(tick) < limitQuote) {
            unchecked {
                ++tick;
            }
        }
    }

    function _absoluteAmount(int256 amount) private pure returns (uint256 magnitude) {
        // forge-lint: disable-next-line(unsafe-typecast)
        if (amount > 0) return uint256(amount);
        unchecked {
            magnitude = uint256(-(amount + 1)) + 1;
        }
    }

    function _grossOutput(uint256 netAmount, uint16 feeBps) private pure returns (uint256 grossAmount) {
        if (feeBps == 0) return netAmount;

        uint256 denominator = _BPS_DENOMINATOR - uint256(feeBps);
        uint256 amountBeforeLastUnit;
        unchecked {
            amountBeforeLastUnit = netAmount - 1;
        }
        uint256 quotient = amountBeforeLastUnit / denominator;
        uint256 remainder = amountBeforeLastUnit % denominator;
        // slither-disable-next-line divide-before-multiply
        uint256 feeUnits = quotient * uint256(feeBps) + (remainder * uint256(feeBps)) / denominator;
        unchecked {
            grossAmount = netAmount + feeUnits;
        }
    }

    function _sqrtPriceQuoteAtMaxQuantity(uint160 sqrtPriceX96) private pure returns (uint256 quoteAmount) {
        uint256 sqrtPrice = uint256(sqrtPriceX96);
        uint256 squareLow;
        uint256 squareHigh;
        uint256 productLow;
        uint256 productHigh;
        uint256 quantity = type(uint160).max;
        /// @solidity memory-safe-assembly
        assembly {
            squareLow := mul(sqrtPrice, sqrtPrice)
            let mm := mulmod(sqrtPrice, sqrtPrice, not(0))
            squareHigh := sub(mm, add(squareLow, lt(mm, squareLow)))
            productLow := mul(squareLow, quantity)
            mm := mulmod(squareLow, quantity, not(0))
            productHigh := sub(mm, add(productLow, lt(mm, productLow)))
        }

        unchecked {
            uint256 upper = productHigh + squareHigh * quantity;
            quoteAmount = (upper << 64) | (productLow >> 192);
        }
    }

    function _quoteValueAtMaxQuantity(int32 tick) private pure returns (uint256 quoteAmount) {
        uint160 quantity = type(uint160).max;
        if (tick == 0) return quantity;
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
        /// @solidity memory-safe-assembly
        assembly {
            let productLow := mul(quantity, factor)
            let mm := mulmod(quantity, factor, not(0))
            let productHigh := sub(mm, add(productLow, lt(mm, productLow)))
            quoteAmount := or(shl(sub(256, shift), productHigh), shr(shift, productLow))
        }
    }
}
