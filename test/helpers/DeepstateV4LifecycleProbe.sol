// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

contract DeepstateV4LifecycleOutsider {
    function sync(IPoolManager manager, Currency currency) external {
        manager.sync(currency);
    }
}

/// @dev Exercises V4 lifecycle operations that ordinary swap routers do not need on every route.
contract DeepstateV4LifecycleProbe is IUnlockCallback {
    using SafeTransferLib for address;

    enum Action {
        SettleForAndTake,
        ClearOutput,
        ClearWrongAmount,
        LeaveUnsettled,
        NestedUnlock,
        UnauthorizedLocker,
        SyncNative,
        NonzeroNativeValue,
        ZeroDelta,
        RoundTripPositiveDelta
    }

    struct CallbackData {
        Action action;
        address payer;
        PoolKey key;
        IPoolManager.SwapParams params;
    }

    IPoolManager internal immutable MANAGER;
    DeepstateV4LifecycleOutsider internal immutable OUTSIDER;

    PoolKey private _reentryKey;
    IPoolManager.SwapParams private _reentryParams;
    bool private _reentryArmed;
    bytes4 public reentrySelector;

    constructor(IPoolManager manager_) {
        MANAGER = manager_;
        OUTSIDER = new DeepstateV4LifecycleOutsider();
    }

    function run(Action action, address payer, PoolKey memory key, IPoolManager.SwapParams memory params)
        external
        payable
        returns (bytes memory result)
    {
        result = MANAGER.unlock(abi.encode(CallbackData({action: action, payer: payer, key: key, params: params})));
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory result) {
        require(msg.sender == address(MANAGER));
        CallbackData memory data = abi.decode(rawData, (CallbackData));
        if (data.action == Action.NestedUnlock) return MANAGER.unlock("");
        if (data.action == Action.UnauthorizedLocker) {
            OUTSIDER.sync(MANAGER, data.key.currency0);
            return "";
        }
        if (data.action == Action.SyncNative) {
            MANAGER.sync(Currency.wrap(address(0)));
            return "";
        }
        if (data.action == Action.NonzeroNativeValue) {
            MANAGER.sync(data.key.currency0);
            MANAGER.settleFor{value: 1}(address(this));
            return "";
        }
        if (data.action == Action.ZeroDelta) {
            MANAGER.take(data.key.currency0, data.payer, 0);
            return "";
        }
        if (data.action == Action.RoundTripPositiveDelta) {
            Currency native = Currency.wrap(address(0));
            MANAGER.sync(native);
            MANAGER.settle{value: 1}();
            MANAGER.take(native, address(this), 1);
            return "";
        }

        BalanceDelta delta = MANAGER.swap(data.key, data.params, "");
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();
        bytes32[] memory values = _readDeltaSlots(data.key.currency0, data.key.currency1);

        if (data.action == Action.LeaveUnsettled) return abi.encode(delta, values);
        if (data.action == Action.ClearWrongAmount) {
            (Currency positiveCurrency, uint256 positiveAmount) = _positiveDelta(data.key, amount0, amount1);
            MANAGER.clear(positiveCurrency, positiveAmount + 1);
        }

        _settleNegative(data.key.currency0, amount0, data.payer);
        _settleNegative(data.key.currency1, amount1, data.payer);
        if (data.action == Action.ClearOutput) {
            (Currency positiveCurrency, uint256 positiveAmount) = _positiveDelta(data.key, amount0, amount1);
            MANAGER.clear(positiveCurrency, positiveAmount);
        } else {
            _takePositive(data.key.currency0, amount0, data.payer);
            _takePositive(data.key.currency1, amount1, data.payer);
        }

        result = abi.encode(delta, values);
    }

    function armSwapReentry(PoolKey memory key, IPoolManager.SwapParams memory params) external {
        _reentryKey = key;
        _reentryParams = params;
        _reentryArmed = true;
    }

    function execute(bytes32, bytes32, address, uint160, uint32) external {
        if (!_reentryArmed) return;
        _reentryArmed = false;
        (bool success, bytes memory reason) =
            address(MANAGER).call(abi.encodeCall(IPoolManager.swap, (_reentryKey, _reentryParams, bytes(""))));
        if (!success && reason.length >= 4) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(reason, 0x20))
            }
            reentrySelector = selector;
        }
    }

    function _readDeltaSlots(Currency currency0, Currency currency1) private view returns (bytes32[] memory values) {
        bytes32[] memory slots = new bytes32[](2);
        slots[0] = keccak256(abi.encode(address(this), Currency.unwrap(currency0)));
        slots[1] = keccak256(abi.encode(address(this), Currency.unwrap(currency1)));
        values = MANAGER.exttload(slots);
    }

    function _settleNegative(Currency currency, int128 delta, address payer) private {
        if (delta >= 0) return;
        // The sign check proves the negated int128 value is positive and representable as uint256.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 amount = uint256(-int256(delta));
        address token = Currency.unwrap(currency);
        MANAGER.sync(currency);
        token.safeTransferFrom(payer, address(MANAGER), amount);
        MANAGER.settleFor(address(this));
    }

    function _takePositive(Currency currency, int128 delta, address recipient) private {
        if (delta <= 0) return;
        // The sign check proves the int128 value is positive and representable as uint256.
        // forge-lint: disable-next-line(unsafe-typecast)
        MANAGER.take(currency, recipient, uint256(int256(delta)));
    }

    function _positiveDelta(PoolKey memory key, int128 amount0, int128 amount1)
        private
        pure
        returns (Currency currency, uint256 amount)
    {
        // Each branch returns only a positive int128 value, which is representable as uint256.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (amount0 > 0) return (key.currency0, uint256(int256(amount0)));
        // forge-lint: disable-next-line(unsafe-typecast)
        return (key.currency1, uint256(int256(amount1)));
    }

    receive() external payable {}
}
