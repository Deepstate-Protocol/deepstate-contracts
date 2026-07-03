// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IHook} from "./interfaces/IHook.sol";
import {RadixMatchingEngine} from "./RadixMatchingEngine.sol";

/// @title Routing Engine
/// @notice Multi-pool routing layer over the book-local radix matching engine.
/// @dev Token pairs are identified by sorted token addresses. Book ids are derived as
/// `keccak256(token0, token1, epoch)`, so the packed order node can stay unchanged while storage is
/// isolated by book. Batch fills defer ERC20 settlement until all matching and resting mutations
/// have completed, then net by token using transient storage keyed directly by token address.
contract RoutingEngine is RadixMatchingEngine, Ownable {
    using SafeTransferLib for address;

    /// @notice One routed fill leg.
    /// @param token0 Lower token address in the pair; asks sell token0, bids buy token0.
    /// @param token1 Higher token address in the pair; bids pay token1, asks receive token1.
    /// @param epoch Book epoch. The book id is `keccak256(token0, token1, epoch)`.
    /// @param order Packed incoming order with price and quantity set, nonce bits clear.
    /// @param isBid True for a bid, false for an ask.
    /// @param noRest If true, unmatched quantity is not inserted as maker liquidity.
    /// @param fillOrKill If true, the full requested quantity must match or the whole call reverts.
    struct FillParams {
        address token0;
        address token1;
        uint256 epoch;
        bytes32 order;
        bool isBid;
        bool noRest;
        bool fillOrKill;
    }

    struct RouteState {
        address[] touched;
        uint256 touchedCount;
        address[] feeTouched;
        uint256 feeTouchedCount;
    }

    uint256 private constant _POOL_EPOCH_MASK = (uint256(1) << 254) - 1;
    uint256 private constant _POOL_HOOK_TOKEN0_ACTIVE = uint256(1) << 254;
    uint256 private constant _POOL_HOOK_TOKEN1_ACTIVE = uint256(1) << 255;
    uint256 private constant _POOL_HOOK_ACTIVE_MASK = _POOL_HOOK_TOKEN0_ACTIVE | _POOL_HOOK_TOKEN1_ACTIVE;
    uint256 private constant _BOOK_HOOK_TOKEN0_ACTIVE = uint256(1) << 42;
    uint256 private constant _BOOK_HOOK_TOKEN1_ACTIVE = uint256(1) << 43;
    uint256 private constant _BOOK_HOOK_ACTIVE_MASK = _BOOK_HOOK_TOKEN0_ACTIVE | _BOOK_HOOK_TOKEN1_ACTIVE;
    uint256 private constant _BPS_DENOMINATOR = 10_000;
    uint16 private constant _MAX_FEE_BPS = 100;
    uint256 private constant _FEE_DELTA_DOMAIN = uint256(1) << 255;
    uint256 private constant _BOOK_NONCE_MASK = (uint256(1) << 40) - 1;

    /// @notice Latest restable epoch for each sorted token pair.
    mapping(bytes32 poolId => uint256 epochAndHookFlags) private _poolEpochAndHookFlags;

    /// @notice Optional top-of-book hook config by sorted-token pool.
    mapping(bytes32 poolId => address hook) public poolHook;

    /// @dev Protocol fee config packed as `recipient | bps << 160`. A zero recipient disables fees.
    uint256 private _feeConfig;

    /// @notice Emitted when a book is initialized.
    event BookInitialized(bytes32 poolId, bytes32 bookId, uint256 epoch);

    /// @notice Emitted when top-of-book hooks are configured for a pool.
    event PoolHookConfigured(bytes32 poolId, address hook, bool token0Active, bool token1Active);

    /// @notice Emitted when protocol fill fees are configured.
    event FeeConfigured(address recipient, uint16 bps);

    /// @notice Hook config is invalid.
    error InvalidHook();
    /// @notice Fee config is invalid.
    error InvalidFeeConfig();

    constructor() {
        _initializeOwner(msg.sender);
    }

    /// @notice Configure protocol fees taken from taker output on matched quantity.
    /// @param recipient Fee recipient. Zero disables fees and requires `bps == 0`.
    /// @param bps Fee in basis points, capped at 100.
    function setFeeConfig(address recipient, uint16 bps) external onlyOwner {
        if (bps > _MAX_FEE_BPS || (recipient == address(0) && bps != 0)) revert InvalidFeeConfig();

        _feeConfig = uint256(uint160(recipient)) | (uint256(bps) << 160);

        emit FeeConfigured(recipient, bps);
    }

    /// @notice Protocol fee configuration. A zero recipient disables fees.
    function feeConfig() external view returns (address recipient, uint16 bps) {
        uint256 config = _feeConfig;
        // forge-lint: disable-next-line(unsafe-typecast)
        recipient = address(uint160(config));
        // forge-lint: disable-next-line(unsafe-typecast)
        bps = uint16(config >> 160);
    }

    /// @notice Configure optional canonical top-of-book hooks for a sorted token pair.
    /// @param token0 Lower token address in the pair.
    /// @param token1 Higher token address in the pair.
    /// @param hook Hook contract called when a top buyer changes.
    /// @param token0Active True to hook token0 buyers, i.e. top bids.
    /// @param token1Active True to hook token1 buyers, i.e. top asks.
    function setPoolHookConfig(address token0, address token1, address hook, bool token0Active, bool token1Active)
        external
        onlyOwner
    {
        _requireSortedTokens(token0, token1);

        uint256 activeFlags;
        if (token0Active) activeFlags |= _POOL_HOOK_TOKEN0_ACTIVE;
        if (token1Active) activeFlags |= _POOL_HOOK_TOKEN1_ACTIVE;
        if (activeFlags != 0 && hook == address(0)) revert InvalidHook();

        bytes32 pid = poolId(token0, token1);
        uint256 poolState = _poolEpoch(_poolEpochAndHookFlags[pid]) | activeFlags;
        _poolEpochAndHookFlags[pid] = poolState;
        poolHook[pid] = hook;
        _setBookHookFlags(books[bookId(token0, token1, _poolEpoch(poolState))], _bookHookFlags(poolState));

        emit PoolHookConfigured(pid, hook, token0Active, token1Active);
    }

    /// @notice Submit one bid or ask and optionally rest unmatched quantity in the active epoch.
    /// @param params Fill parameters.
    /// @return restingOrder Packed order node if any quantity rested, otherwise zero.
    function fill(FillParams calldata params) external nonReentrant returns (bytes32 restingOrder) {
        int256 token0Delta;
        int256 token1Delta;
        uint256 feeAmount;
        (restingOrder, token0Delta, token1Delta) = _executeFill(params);

        uint256 config = _feeConfig;
        if (config != 0) {
            uint16 feeBps;
            /// @solidity memory-safe-assembly
            assembly {
                feeBps := shr(160, config)
            }
            (token0Delta, token1Delta, feeAmount) = _applyFillFee(params.isBid, token0Delta, token1Delta, feeBps);
        }

        _settleDeltas(params.token0, token0Delta, params.token1, token1Delta);
        if (feeAmount != 0) {
            address feeRecipient;
            /// @solidity memory-safe-assembly
            assembly {
                feeRecipient := config
            }
            (params.isBid ? params.token0 : params.token1).safeTransfer(feeRecipient, feeAmount);
        }
    }

    /// @notice Execute multiple routed fills atomically and settle each touched token once.
    /// @param fills Sequential route legs.
    function fillRoute(FillParams[] calldata fills) external nonReentrant {
        uint256 length = fills.length;
        RouteState memory route;
        route.touched = new address[](length * 2);
        uint256 config = _feeConfig;
        if (config != 0) route.feeTouched = new address[](length);

        for (uint256 i; i < length;) {
            _executeRouteLeg(fills[i], config, route);
            unchecked {
                ++i;
            }
        }

        _settleTouched(route.touched, route.touchedCount);
        if (config != 0) {
            address feeRecipient;
            /// @solidity memory-safe-assembly
            assembly {
                feeRecipient := config
            }
            _settleFees(feeRecipient, route.feeTouched, route.feeTouchedCount);
        }
    }

    /// @notice Cancel open quantity or claim filled proceeds from one book.
    /// @param token0 Lower token address in the pair.
    /// @param token1 Higher token address in the pair.
    /// @param epoch Book epoch.
    /// @param order Original packed resting order.
    /// @return baseAmount Token0 amount paid to the maker.
    /// @return quoteAmount Token1 amount paid to the maker.
    function cancel(address token0, address token1, uint256 epoch, bytes32 order)
        external
        nonReentrant
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        _requireSortedTokens(token0, token1);

        bytes32 id = bookId(token0, token1, epoch);
        Book storage book = books[id];

        bool isBid;
        address owner;
        uint256 hookFlags = _cancelHookFlags(book.nonceAndFlags);
        (owner, isBid, baseAmount, quoteAmount) = _cancelBook(id, book, order, msg.sender, hookFlags);
        if (_cancelHookEnabled(hookFlags, isBid)) _executeTopOrderHook(token0, token1, id, isBid);

        if (baseAmount != 0) token0.safeTransfer(owner, baseAmount);
        if (quoteAmount != 0) token1.safeTransfer(owner, quoteAmount);
    }

    /// @notice Compute the canonical pool id for a sorted token pair.
    function poolId(address token0, address token1) public pure returns (bytes32 id) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, token0)
            mstore(add(ptr, 0x20), token1)
            id := keccak256(ptr, 0x40)
        }
    }

    /// @notice Compute the book id for a sorted token pair and epoch.
    function bookId(address token0, address token1, uint256 epoch) public pure returns (bytes32 id) {
        /// @solidity memory-safe-assembly
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(0x00, token0)
            mstore(0x20, token1)
            mstore(0x40, epoch)
            id := keccak256(0x00, 0x60)
            mstore(0x40, freeMemoryPointer)
        }
    }

    /// @notice Globally unique owner key for an order inside a book.
    function orderId(bytes32 id, bytes32 order) external pure returns (bytes32) {
        return _orderId(id, order);
    }

    /// @notice Return the active book id for a sorted token pair.
    function activeBookId(address token0, address token1) external view returns (bytes32) {
        _requireSortedTokens(token0, token1);
        return bookId(token0, token1, poolEpoch(poolId(token0, token1)));
    }

    /// @notice Return the active restable epoch for a sorted-token pool id.
    function poolEpoch(bytes32 pid) public view returns (uint256) {
        return _poolEpoch(_poolEpochAndHookFlags[pid]);
    }

    /// @notice Return the low 40-bit next nonce for a book.
    function nextNonce(address token0, address token1, uint256 epoch) external view returns (uint40) {
        _requireSortedTokens(token0, token1);
        return _nextNonce(books[bookId(token0, token1, epoch)]);
    }

    /// @notice Return roots for a book. `askRoot` is `tree[0].leftNode`; `bidRoot` is `tree[0].rightNode`.
    function roots(address token0, address token1, uint256 epoch)
        external
        view
        returns (bytes32 askRoot, bytes32 bidRoot)
    {
        _requireSortedTokens(token0, token1);
        Branch storage root = books[bookId(token0, token1, epoch)].tree[bytes32(0)];
        askRoot = root.leftNode;
        bidRoot = root.rightNode;
    }

    /// @notice Branch child pointers for a node in a book.
    function tree(bytes32 id, bytes32 node) external view returns (bytes32 leftNode, bytes32 rightNode) {
        Branch storage branch = books[id].tree[node];
        leftNode = branch.leftNode;
        rightNode = branch.rightNode;
    }

    function _executeFill(FillParams calldata params)
        private
        returns (bytes32 restingOrder, int256 token0Delta, int256 token1Delta)
    {
        _requireSortedTokens(params.token0, params.token1);
        bytes32 routedBookId = bookId(params.token0, params.token1, params.epoch);
        Book storage routedBook = books[routedBookId];
        uint256 routedNonceAndFlags = routedBook.nonceAndFlags;
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 routedNonce = uint40(routedNonceAndFlags);

        uint24 limitPrice;
        uint192 remaining;
        uint192 baseFilled;
        uint256 quoteAmount;

        (limitPrice, remaining, baseFilled, quoteAmount) =
            _matchOrValidate(params, routedBookId, routedBook, routedNonceAndFlags);

        if (remaining != 0 && params.fillOrKill) revert FillOrKill();

        if (params.isBid) {
            token0Delta = int256(uint256(baseFilled));
            // forge-lint: disable-next-line(unsafe-typecast)
            token1Delta = -int256(quoteAmount);

            if (remaining != 0 && !params.noRest) {
                restingOrder = _restRemaining(
                    params.token0,
                    params.token1,
                    params.epoch,
                    routedBookId,
                    routedBook,
                    routedNonceAndFlags,
                    routedNonce == 0,
                    limitPrice,
                    remaining,
                    true
                );
                uint256 collateral = _quoteValue(limitPrice, remaining);
                // forge-lint: disable-next-line(unsafe-typecast)
                token1Delta -= int256(collateral);
            }
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            token0Delta = -int256(uint256(baseFilled));
            // forge-lint: disable-next-line(unsafe-typecast)
            token1Delta = int256(quoteAmount);

            if (remaining != 0 && !params.noRest) {
                restingOrder = _restRemaining(
                    params.token0,
                    params.token1,
                    params.epoch,
                    routedBookId,
                    routedBook,
                    routedNonceAndFlags,
                    routedNonce == 0,
                    limitPrice,
                    remaining,
                    false
                );
                token0Delta -= int256(uint256(remaining));
            }
        }
    }

    function _executeRouteLeg(FillParams calldata params, uint256 config, RouteState memory route) private {
        int256 token0Delta;
        int256 token1Delta;
        uint256 feeAmount;
        (, token0Delta, token1Delta) = _executeFill(params);
        if (config != 0) {
            uint16 feeBps;
            /// @solidity memory-safe-assembly
            assembly {
                feeBps := shr(160, config)
            }
            (token0Delta, token1Delta, feeAmount) = _applyFillFee(params.isBid, token0Delta, token1Delta, feeBps);
            route.feeTouchedCount = _addFee(
                params.isBid ? params.token0 : params.token1, feeAmount, route.feeTouched, route.feeTouchedCount
            );
        }
        route.touchedCount = _addDelta(params.token0, token0Delta, route.touched, route.touchedCount);
        route.touchedCount = _addDelta(params.token1, token1Delta, route.touched, route.touchedCount);
    }

    function _matchOrValidate(
        FillParams calldata params,
        bytes32 routedBookId,
        Book storage routedBook,
        uint256 routedNonceAndFlags
    ) private returns (uint24 limitPrice, uint192 remaining, uint192 baseFilled, uint256 quoteAmount) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 routedNonce = uint40(routedNonceAndFlags);
        if (routedNonce == 0) {
            if (params.noRest || params.fillOrKill) revert InvalidBook();
            (limitPrice, remaining) = _validateIncomingOrder(params.order);
        } else {
            bool hookEnabled = _bookHookEnabled(routedNonceAndFlags, !params.isBid);
            (limitPrice, remaining, baseFilled, quoteAmount) =
                _matchBook(routedBookId, routedBook, params.order, params.isBid, hookEnabled);
            if (hookEnabled) _executeTopOrderHook(params.token0, params.token1, routedBookId, !params.isBid);
        }
    }

    function _restRemaining(
        address token0,
        address token1,
        uint256 routedEpoch,
        bytes32 routedBookId,
        Book storage routedBook,
        uint256 routedNonceAndFlags,
        bool routedBookWasEmpty,
        uint24 limitPrice,
        uint192 remaining,
        bool isBid
    ) private returns (bytes32 restingOrder) {
        if (!routedBookWasEmpty) routedNonceAndFlags = routedBook.nonceAndFlags;
        bytes32 restBookId;
        Book storage restBook;
        uint256 restNonceAndFlags;
        if (!routedBookWasEmpty && (routedNonceAndFlags & _BOOK_NONCE_MASK) > 1) {
            restBookId = routedBookId;
            restBook = routedBook;
            restNonceAndFlags = routedNonceAndFlags;
        } else {
            (restBookId, restBook, restNonceAndFlags) = _restableBook(
                token0, token1, routedEpoch, routedBookId, routedBook, routedNonceAndFlags, routedBookWasEmpty
            );
        }
        uint40 nextNonceAfter;
        bool hookEnabled = _bookHookEnabled(restNonceAndFlags, isBid);
        (restingOrder, nextNonceAfter) = _restSelectedBook(
            token0, token1, restBookId, restBook, restNonceAndFlags, limitPrice, remaining, isBid, hookEnabled
        );
        if (nextNonceAfter == 1) _rotateIfExhausted(token0, token1);
    }

    function _restSelectedBook(
        address token0,
        address token1,
        bytes32 id,
        Book storage book,
        uint256 nonceAndFlags,
        uint24 limitPrice,
        uint192 remaining,
        bool isBid,
        bool hookEnabled
    ) private returns (bytes32 restingOrder, uint40 nextNonceAfter) {
        (restingOrder, nextNonceAfter) =
            _restBook(id, book, nonceAndFlags, limitPrice, remaining, isBid, msg.sender, hookEnabled);
        if (hookEnabled) _executeTopOrderHook(token0, token1, id, isBid);
    }

    function _restableBook(
        address token0,
        address token1,
        uint256 routedEpoch,
        bytes32 routedBookId,
        Book storage routedBook,
        uint256 routedNonceAndFlags,
        bool requireRoutedEpochActive
    ) private returns (bytes32 id, Book storage book, uint256 nonceAndFlags) {
        bytes32 pid = poolId(token0, token1);
        uint256 poolState = _poolEpochAndHookFlags[pid];
        uint256 epoch = _poolEpoch(poolState);
        if (requireRoutedEpochActive && routedEpoch != epoch) revert InvalidBook();

        if (epoch == routedEpoch) {
            id = routedBookId;
            book = routedBook;
            nonceAndFlags = routedNonceAndFlags;
        } else {
            id = bookId(token0, token1, epoch);
            book = books[id];
            nonceAndFlags = book.nonceAndFlags;
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 nonce = uint40(nonceAndFlags);
        uint256 bookHookFlags;
        if (poolState & _POOL_HOOK_ACTIVE_MASK != 0) bookHookFlags = _bookHookFlags(poolState);
        if (nonce == 0) {
            nonceAndFlags = uint256(type(uint40).max) | bookHookFlags;
            emit BookInitialized(pid, id, epoch);
            return (id, book, nonceAndFlags);
        }

        if (nonce == 1) {
            if (bookHookFlags != 0) _setBookHookFlags(book, 0);
            unchecked {
                epoch += 1;
            }
            poolState = _withPoolEpoch(poolState, epoch);
            _poolEpochAndHookFlags[pid] = poolState;
            id = bookId(token0, token1, epoch);
            book = books[id];
            nonceAndFlags = uint256(type(uint40).max) | bookHookFlags;
            emit BookInitialized(pid, id, epoch);
        }
    }

    function _rotateIfExhausted(address token0, address token1) private {
        bytes32 pid = poolId(token0, token1);
        uint256 poolState = _poolEpochAndHookFlags[pid];
        uint256 oldEpoch = _poolEpoch(poolState);
        uint256 bookHookFlags = _bookHookFlags(poolState);
        if (bookHookFlags != 0) _setBookHookFlags(books[bookId(token0, token1, oldEpoch)], 0);

        uint256 epoch;
        unchecked {
            epoch = oldEpoch + 1;
        }
        _poolEpochAndHookFlags[pid] = _withPoolEpoch(poolState, epoch);

        bytes32 id = bookId(token0, token1, epoch);
        Book storage nextBook = books[id];
        _initializeBookWithHookFlags(nextBook, bookHookFlags);
        emit BookInitialized(pid, id, epoch);
    }

    function _executeTopOrderHook(address token0, address token1, bytes32 id, bool isBid) private {
        (uint192 outgoingAmount, uint40 incomingNonce) = _takeTopOrderChange();
        if (outgoingAmount == 0 && incomingNonce == 0) return;

        bytes32 pid = poolId(token0, token1);
        address hook = poolHook[pid];
        if (hook == address(0)) return;

        address token = isBid ? token0 : token1;
        try IHook(hook).execute(pid, id, token, outgoingAmount, incomingNonce) {} catch {}
    }

    function _poolEpoch(uint256 poolState) private pure returns (uint256) {
        return poolState & _POOL_EPOCH_MASK;
    }

    function _withPoolEpoch(uint256 poolState, uint256 epoch) private pure returns (uint256) {
        return (poolState & _POOL_HOOK_ACTIVE_MASK) | epoch;
    }

    function _bookHookEnabled(uint256 nonceAndFlags, bool isBid) private pure returns (bool) {
        uint256 flag = isBid ? _BOOK_HOOK_TOKEN0_ACTIVE : _BOOK_HOOK_TOKEN1_ACTIVE;
        return nonceAndFlags & flag != 0;
    }

    function _cancelHookFlags(uint256 nonceAndFlags) private pure returns (uint256 flags) {
        if (nonceAndFlags & _BOOK_HOOK_TOKEN0_ACTIVE != 0) flags |= _CANCEL_HOOK_BID;
        if (nonceAndFlags & _BOOK_HOOK_TOKEN1_ACTIVE != 0) flags |= _CANCEL_HOOK_ASK;
    }

    function _cancelHookEnabled(uint256 hookFlags, bool isBid) private pure returns (bool) {
        uint256 flag = isBid ? _CANCEL_HOOK_BID : _CANCEL_HOOK_ASK;
        return hookFlags & flag != 0;
    }

    function _bookHookFlags(uint256 poolState) private pure returns (uint256 flags) {
        if (poolState & _POOL_HOOK_TOKEN0_ACTIVE != 0) flags |= _BOOK_HOOK_TOKEN0_ACTIVE;
        if (poolState & _POOL_HOOK_TOKEN1_ACTIVE != 0) flags |= _BOOK_HOOK_TOKEN1_ACTIVE;
    }

    function _setBookHookFlags(Book storage book, uint256 flags) private {
        uint256 nonceAndFlags = book.nonceAndFlags;
        uint256 nextNonceAndFlags = (nonceAndFlags & ~_BOOK_HOOK_ACTIVE_MASK) | flags;
        if (nextNonceAndFlags != nonceAndFlags) book.nonceAndFlags = nextNonceAndFlags;
    }

    function _initializeBookWithHookFlags(Book storage book, uint256 flags) private {
        if (_nextNonce(book) != 0) return;
        book.nonceAndFlags = uint256(type(uint40).max) | flags;
    }

    function _requireSortedTokens(address token0, address token1) internal pure virtual {
        /// @solidity memory-safe-assembly
        assembly {
            if or(iszero(token0), iszero(lt(token0, token1))) {
                mstore(0x00, 0xc1ab6dc1) // `InvalidToken()`.
                revert(0x1c, 0x04)
            }
        }
    }

    function _addDelta(address token, int256 amount, address[] memory touched, uint256 touchedCount)
        private
        returns (uint256)
    {
        if (amount == 0) return touchedCount;

        if (!_isTouched(token, touched, touchedCount)) {
            touched[touchedCount] = token;
            unchecked {
                ++touchedCount;
            }
        }

        bytes32 slot = bytes32(uint256(uint160(token)));
        int256 current;
        assembly {
            current := tload(slot)
        }
        int256 next = current + amount;
        assembly {
            tstore(slot, next)
        }
        return touchedCount;
    }

    function _addFee(address token, uint256 amount, address[] memory touched, uint256 touchedCount)
        private
        returns (uint256)
    {
        if (amount == 0) return touchedCount;

        if (!_isTouched(token, touched, touchedCount)) {
            touched[touchedCount] = token;
            unchecked {
                ++touchedCount;
            }
        }

        bytes32 slot = _feeSlot(token);
        uint256 current;
        assembly {
            current := tload(slot)
        }
        uint256 next = current + amount;
        assembly {
            tstore(slot, next)
        }
        return touchedCount;
    }

    function _isTouched(address token, address[] memory touched, uint256 touchedCount) private pure returns (bool) {
        for (uint256 i; i < touchedCount;) {
            if (touched[i] == token) return true;
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function _settleTouched(address[] memory touched, uint256 touchedCount) private {
        for (uint256 i; i < touchedCount;) {
            address token = touched[i];
            bytes32 slot = bytes32(uint256(uint160(token)));
            int256 amount;
            assembly {
                amount := tload(slot)
            }

            if (amount > 0) {
                assembly {
                    tstore(slot, 0)
                }
                // forge-lint: disable-next-line(unsafe-typecast)
                token.safeTransfer(msg.sender, uint256(amount));
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < touchedCount;) {
            address token = touched[i];
            bytes32 slot = bytes32(uint256(uint160(token)));
            int256 amount;
            assembly {
                amount := tload(slot)
            }

            if (amount < 0) {
                assembly {
                    tstore(slot, 0)
                }
                // forge-lint: disable-next-line(unsafe-typecast)
                token.safeTransferFrom(msg.sender, address(this), uint256(-amount));
            }

            unchecked {
                ++i;
            }
        }
    }

    function _settleDeltas(address token0, int256 amount0, address token1, int256 amount1) private {
        if (amount0 > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token0.safeTransfer(msg.sender, uint256(amount0));
        }
        if (amount1 > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token1.safeTransfer(msg.sender, uint256(amount1));
        }
        if (amount0 < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token0.safeTransferFrom(msg.sender, address(this), uint256(-amount0));
        }
        if (amount1 < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token1.safeTransferFrom(msg.sender, address(this), uint256(-amount1));
        }
    }

    function _settleFees(address recipient, address[] memory touched, uint256 touchedCount) private {
        for (uint256 i; i < touchedCount;) {
            address token = touched[i];
            bytes32 slot = _feeSlot(token);
            uint256 amount;
            assembly {
                amount := tload(slot)
                tstore(slot, 0)
            }

            if (amount != 0) token.safeTransfer(recipient, amount);

            unchecked {
                ++i;
            }
        }
    }

    function _applyFillFee(bool isBid, int256 token0Delta, int256 token1Delta, uint16 feeBps)
        private
        pure
        returns (int256 nextToken0Delta, int256 nextToken1Delta, uint256 feeAmount)
    {
        nextToken0Delta = token0Delta;
        nextToken1Delta = token1Delta;
        if (feeBps == 0) return (token0Delta, token1Delta, 0);

        if (isBid) {
            if (token0Delta <= 0) return (token0Delta, token1Delta, 0);
            // forge-lint: disable-next-line(unsafe-typecast)
            feeAmount = (uint256(token0Delta) * uint256(feeBps)) / _BPS_DENOMINATOR;
            // forge-lint: disable-next-line(unsafe-typecast)
            nextToken0Delta = token0Delta - int256(feeAmount);
        } else {
            if (token1Delta <= 0) return (token0Delta, token1Delta, 0);
            // forge-lint: disable-next-line(unsafe-typecast)
            feeAmount = (uint256(token1Delta) * uint256(feeBps)) / _BPS_DENOMINATOR;
            // forge-lint: disable-next-line(unsafe-typecast)
            nextToken1Delta = token1Delta - int256(feeAmount);
        }
    }

    function _feeSlot(address token) private pure returns (bytes32) {
        return bytes32(_FEE_DELTA_DOMAIN | uint256(uint160(token)));
    }
}
