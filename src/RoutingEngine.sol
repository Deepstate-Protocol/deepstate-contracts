// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {RadixMatchingEngine} from "./RadixMatchingEngine.sol";

/// @title Routing Engine
/// @notice Multi-pool routing layer over the book-local radix matching engine.
/// @dev Token pairs are identified by sorted token addresses. Book ids are derived as
/// `keccak256(token0, token1, epoch)`, so the packed order node can stay unchanged while storage is
/// isolated by book. Batch fills defer ERC20 settlement until all matching and resting mutations
/// have completed, then net by token using transient storage keyed directly by token address.
contract RoutingEngine is RadixMatchingEngine {
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

    /// @notice Latest restable epoch for each sorted token pair.
    mapping(bytes32 poolId => uint256 epoch) public poolEpoch;

    /// @notice Emitted when a book is initialized.
    event BookInitialized(bytes32 indexed poolId, bytes32 indexed bookId, uint256 indexed epoch);

    /// @notice Submit one bid or ask and optionally rest unmatched quantity in the active epoch.
    /// @param params Fill parameters.
    /// @return restingOrder Packed order node if any quantity rested, otherwise zero.
    function fill(FillParams calldata params) external nonReentrant returns (bytes32 restingOrder) {
        int256 token0Delta;
        int256 token1Delta;
        (restingOrder, token0Delta, token1Delta) = _executeFill(params);
        _settleDelta(params.token0, token0Delta);
        _settleDelta(params.token1, token1Delta);
    }

    /// @notice Execute multiple routed fills atomically and settle each touched token once.
    /// @param fills Sequential route legs.
    function fillRoute(FillParams[] calldata fills) external nonReentrant {
        uint256 length = fills.length;
        address[] memory touched = new address[](length * 2);
        uint256 touchedCount;

        for (uint256 i; i < length;) {
            FillParams calldata params = fills[i];
            int256 token0Delta;
            int256 token1Delta;
            (, token0Delta, token1Delta) = _executeFill(params);
            touchedCount = _addDelta(params.token0, token0Delta, touched, touchedCount);
            touchedCount = _addDelta(params.token1, token1Delta, touched, touchedCount);
            unchecked {
                ++i;
            }
        }

        _settleTouched(touched, touchedCount);
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
        (owner, isBid, baseAmount, quoteAmount) = _cancelBook(id, book, order, msg.sender);
        isBid;

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
            let ptr := mload(0x40)
            mstore(ptr, token0)
            mstore(add(ptr, 0x20), token1)
            mstore(add(ptr, 0x40), epoch)
            id := keccak256(ptr, 0x60)
        }
    }

    /// @notice Globally unique owner key for an order inside a book.
    function orderId(bytes32 id, bytes32 order) external pure returns (bytes32) {
        return _orderId(id, order);
    }

    /// @notice Return the active book id for a sorted token pair.
    function activeBookId(address token0, address token1) external view returns (bytes32) {
        _requireSortedTokens(token0, token1);
        return bookId(token0, token1, poolEpoch[poolId(token0, token1)]);
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

        if (routedNonce == 0) {
            if (params.noRest || params.fillOrKill) revert InvalidBook();
            (limitPrice, remaining) = _validateIncomingOrder(params.order);
        } else {
            (limitPrice, remaining, baseFilled, quoteAmount) =
                _matchBook(routedBookId, routedBook, params.order, params.isBid);
        }

        if (remaining != 0 && params.fillOrKill) revert FillOrKill();

        if (params.isBid) {
            token0Delta = int256(uint256(baseFilled));
            // forge-lint: disable-next-line(unsafe-typecast)
            token1Delta = -int256(quoteAmount);

            if (remaining != 0 && !params.noRest) {
                uint256 restRoutedNonceAndFlags = routedNonce == 0 ? routedNonceAndFlags : routedBook.nonceAndFlags;
                (bytes32 restBookId, Book storage restBook, uint256 restNonceAndFlags) = _restableBook(
                    params.token0,
                    params.token1,
                    params.epoch,
                    routedBookId,
                    routedBook,
                    restRoutedNonceAndFlags,
                    routedNonce == 0
                );
                uint40 nextNonceAfter;
                (restingOrder, nextNonceAfter) =
                    _restBook(restBookId, restBook, restNonceAndFlags, limitPrice, remaining, true, msg.sender);
                _rotateIfExhausted(params.token0, params.token1, nextNonceAfter);
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
                uint256 restRoutedNonceAndFlags = routedNonce == 0 ? routedNonceAndFlags : routedBook.nonceAndFlags;
                (bytes32 restBookId, Book storage restBook, uint256 restNonceAndFlags) = _restableBook(
                    params.token0,
                    params.token1,
                    params.epoch,
                    routedBookId,
                    routedBook,
                    restRoutedNonceAndFlags,
                    routedNonce == 0
                );
                uint40 nextNonceAfter;
                (restingOrder, nextNonceAfter) =
                    _restBook(restBookId, restBook, restNonceAndFlags, limitPrice, remaining, false, msg.sender);
                _rotateIfExhausted(params.token0, params.token1, nextNonceAfter);
                token0Delta -= int256(uint256(remaining));
            }
        }
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
        uint256 epoch = poolEpoch[pid];
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

        uint40 nonce = uint40(nonceAndFlags);
        if (nonce == 0) {
            nonceAndFlags = uint256(type(uint40).max);
            emit BookInitialized(pid, id, epoch);
            return (id, book, nonceAndFlags);
        }

        if (nonce == 1) {
            unchecked {
                epoch += 1;
            }
            poolEpoch[pid] = epoch;
            id = bookId(token0, token1, epoch);
            book = books[id];
            nonceAndFlags = uint256(type(uint40).max);
            emit BookInitialized(pid, id, epoch);
        }
    }

    function _rotateIfExhausted(address token0, address token1, uint40 nextNonceAfter) private {
        if (nextNonceAfter != 1) return;

        bytes32 pid = poolId(token0, token1);
        uint256 epoch;
        unchecked {
            epoch = poolEpoch[pid] + 1;
        }
        poolEpoch[pid] = epoch;

        bytes32 id = bookId(token0, token1, epoch);
        Book storage nextBook = books[id];
        _initializeBook(nextBook);
        emit BookInitialized(pid, id, epoch);
    }

    function _requireSortedTokens(address token0, address token1) internal view virtual {
        if (
            token0 == address(0) || token1 == address(0) || token0 >= token1 || token0.code.length == 0
                || token1.code.length == 0
        ) {
            revert InvalidToken();
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
                tstore(slot, 0)
            }

            if (amount < 0) {
                // forge-lint: disable-next-line(unsafe-typecast)
                token.safeTransferFrom(msg.sender, address(this), uint256(-amount));
            } else if (amount > 0) {
                // forge-lint: disable-next-line(unsafe-typecast)
                token.safeTransfer(msg.sender, uint256(amount));
            }

            unchecked {
                ++i;
            }
        }
    }

    function _settleDelta(address token, int256 amount) private {
        if (amount < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token.safeTransferFrom(msg.sender, address(this), uint256(-amount));
        } else if (amount > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token.safeTransfer(msg.sender, uint256(amount));
        }
    }
}
