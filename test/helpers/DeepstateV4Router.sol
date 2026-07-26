// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @dev Test router that uses the same unlock, swap, sync, settle, and take sequence as V4 routers.
/// It returns `BalanceDelta` to keep the engine's exact execution assertions compact.
contract DeepstateV4Router is IUnlockCallback {
    using SafeTransferLib for address;
    using TransientStateLibrary for IPoolManager;

    struct SwapCall {
        PoolKey key;
        IPoolManager.SwapParams params;
        bytes hookData;
    }

    struct CallbackData {
        address sender;
        SwapCall[] calls;
    }

    IPoolManager internal immutable MANAGER;

    constructor(IPoolManager manager_) {
        MANAGER = manager_;
    }

    function swap(PoolKey memory key, IPoolManager.SwapParams memory params, bytes calldata hookData)
        external
        payable
        returns (BalanceDelta delta)
    {
        SwapCall[] memory calls = new SwapCall[](1);
        calls[0] = SwapCall({key: key, params: params, hookData: hookData});
        bytes memory result = MANAGER.unlock(abi.encode(CallbackData({sender: msg.sender, calls: calls})));
        BalanceDelta[] memory deltas = abi.decode(result, (BalanceDelta[]));
        delta = deltas[0];

        uint256 refund = address(this).balance;
        if (refund != 0) msg.sender.safeTransferETH(refund);
    }

    function swapRoute(SwapCall[] calldata calls) external payable returns (BalanceDelta[] memory deltas) {
        bytes memory result = MANAGER.unlock(abi.encode(CallbackData({sender: msg.sender, calls: calls})));
        deltas = abi.decode(result, (BalanceDelta[]));

        uint256 refund = address(this).balance;
        if (refund != 0) msg.sender.safeTransferETH(refund);
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(MANAGER));
        CallbackData memory data = abi.decode(rawData, (CallbackData));
        uint256 length = data.calls.length;
        BalanceDelta[] memory deltas = new BalanceDelta[](length);
        Currency[] memory touched = new Currency[](length * 2);
        uint256 touchedCount;

        for (uint256 i; i < length;) {
            SwapCall memory call_ = data.calls[i];
            deltas[i] = MANAGER.swap(call_.key, call_.params, call_.hookData);
            touchedCount = _touch(call_.key.currency0, touched, touchedCount);
            touchedCount = _touch(call_.key.currency1, touched, touchedCount);
            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < touchedCount;) {
            Currency currency = touched[i];
            int256 delta = MANAGER.currencyDelta(address(this), currency);
            if (delta < 0) {
                // The sign check proves the negated value is representable as uint256.
                // forge-lint: disable-next-line(unsafe-typecast)
                _settle(currency, data.sender, uint256(-delta));
            } else if (delta > 0) {
                // The sign check proves the value is representable as uint256.
                // forge-lint: disable-next-line(unsafe-typecast)
                MANAGER.take(currency, data.sender, uint256(delta));
            }
            unchecked {
                ++i;
            }
        }

        return abi.encode(deltas);
    }

    function _settle(Currency currency, address payer, uint256 amount) private {
        address token = Currency.unwrap(currency);
        if (token == address(0)) {
            MANAGER.settle{value: amount}();
        } else {
            MANAGER.sync(currency);
            token.safeTransferFrom(payer, address(MANAGER), amount);
            MANAGER.settle();
        }
    }

    function _touch(Currency currency, Currency[] memory touched, uint256 count) private pure returns (uint256) {
        for (uint256 i; i < count;) {
            if (Currency.unwrap(touched[i]) == Currency.unwrap(currency)) return count;
            unchecked {
                ++i;
            }
        }
        touched[count] = currency;
        unchecked {
            return count + 1;
        }
    }

    receive() external payable {}
}
