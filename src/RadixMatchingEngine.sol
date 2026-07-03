// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LibBit} from "solady/utils/LibBit.sol";

/// @title Radix Matching Engine
/// @notice Fully on-chain limit-order matching engine backed by two radix trees in one mapping.
/// @dev
/// Orders and aggregate branches are both represented by a single `bytes32` node word:
///
/// - bits 232-255: 24-bit price.
/// - bits  40-231: 192-bit quantity.
/// - bits   0-39: 40-bit nonce/path suffix.
///
/// Leaf nodes are resting orders. The caller supplies price and quantity with nonce bits set to
/// zero; the contract assigns a decrementing nonce so higher nonce values have earlier time
/// priority at the same price.
///
/// Branch nodes are self-addressing aggregate nodes. A branch address is built with the maximum
/// raw price/nonce path key of its two children and the sum of their quantities. The child pointers
/// are stored in `tree[branch]`. A node is treated as a branch if it has a nonzero left child in
/// `tree`; otherwise it is treated as a leaf. This intentionally allows a branch key and an
/// original order key to be the same `bytes32`: branch structure lives in `tree`, while ownership
/// and side metadata live together in `orderOf`.
///
/// The bid and ask books are conceptual trees that coexist in the same `tree` mapping:
///
/// - Bid sort key: `price || nonce`, so the rightmost branch contains the highest price and then
///   the earliest nonce.
/// - Ask sort key: `(maxPrice - price) || nonce`, so the rightmost branch contains the lowest
///   price and then the earliest nonce.
///
/// Matching always walks the right side first because that is the best executable liquidity for
/// both books. When an entire subtree crosses the incoming limit and fits inside the incoming
/// remaining quantity, it is consumed as an aggregate using the branch quantity instead of walking
/// every leaf. Makers later claim proceeds by calling `cancel` on their original order. This
/// decouples matching from per-maker execution while preserving price-time priority.
///
/// Token assumptions: this contract uses Solady safe transfer helpers and assumes deployment will
/// choose standard, non-fee-on-transfer tokens. Deliberately malicious or inexact ERC20 behavior is
/// out of scope for this engine and should be controlled at deployment/configuration time.
abstract contract RadixMatchingEngine {
    /// @notice Stored child pointers for a branch node.
    /// @dev
    /// `leftNode` and `rightNode` are both `bytes32` nodes. They can be leaves or further branches.
    /// Branches always have two children. A zero `leftNode` is the branch/leaf sentinel used by all
    /// walkers, so live branches must never be stored with only one child.
    struct Branch {
        /// @notice Child whose sort key has a zero bit at the branch split depth.
        bytes32 leftNode;
        /// @notice Child whose sort key has a one bit at the branch split depth.
        bytes32 rightNode;
    }

    /// @notice Owner and side metadata for one original resting order.
    /// @dev
    /// Solidity packs `owner` and `isBid` into one storage slot. This keeps the side explicit in
    /// source code without spending the second side-marker slot used by the earlier design.
    struct OrderState {
        address owner;
        bool isBid;
    }

    /// @notice One isolated radix book for one token pair epoch.
    /// @dev The low 40 bits of `nonceAndFlags` are the decrementing nonce. Bits above the nonce
    /// hold per-book right-spine dirty flags. The zero node in `tree` is reserved as the root
    /// anchor: `leftNode` is the ask root and `rightNode` is the bid root.
    struct Book {
        uint256 nonceAndFlags;
        mapping(bytes32 => Branch) tree;
    }

    /// @notice Isolated books keyed by `keccak256(token0, token1, epoch)`.
    mapping(bytes32 bookId => Book) internal books;

    /// @notice Owner and side lookup by order id.
    /// @dev
    /// The key is `keccak256(bookId, orderNode)`, not the raw node, so the same packed order can
    /// exist in different pools or epochs without ownership collision.
    mapping(bytes32 orderId => OrderState state) internal orderOf;

    /// @dev Bit offset of the 24-bit price field in a packed node.
    uint256 private constant _PRICE_SHIFT = 232;
    /// @dev Bit offset of the 192-bit quantity field in a packed node.
    uint256 private constant _QUANTITY_SHIFT = 40;
    /// @dev Mask for extracting the 192-bit quantity after shifting right by `_QUANTITY_SHIFT`.
    uint256 private constant _QUANTITY_MASK = (uint256(1) << 192) - 1;
    /// @dev Mask for extracting or validating the 40-bit nonce/path suffix.
    uint256 private constant _NONCE_MASK = (uint256(1) << 40) - 1;
    /// @dev Mask that keeps price and nonce while clearing quantity.
    uint256 private constant _PATH_MASK = ~(_QUANTITY_MASK << _QUANTITY_SHIFT);
    /// @dev Maximum valid 24-bit price. Also used to invert ask prices into ascending sort order.
    uint24 private constant _MAX_PRICE = type(uint24).max;
    /// @dev Root anchor in every book's tree. `leftNode` is ask root; `rightNode` is bid root.
    bytes32 private constant _ROOT_NODE = bytes32(0);
    /// @dev Dirty bit stored above the 40-bit `nextNonce` field when bid right-spine anchors are stale.
    uint256 private constant _BID_RIGHT_SPINE_DIRTY = uint256(1) << 40;
    /// @dev Dirty bit stored above the 40-bit `nextNonce` field when ask right-spine anchors are stale.
    uint256 private constant _ASK_RIGHT_SPINE_DIRTY = uint256(1) << 41;
    /// @dev Internal matcher flag indicating stale right-spine aggregate words.
    uint256 private constant _MATCH_DIRTY = 1;
    /// @dev Internal matcher flag indicating top-change hooks should be tracked.
    uint256 private constant _MATCH_HOOK = 2;
    /// @dev Internal matcher flag indicating the resting subtree is from the bid side.
    uint256 private constant _MATCH_RESTING_BID = 4;
    /// @dev Cancel hook flag for bid-side top changes.
    uint256 internal constant _CANCEL_HOOK_BID = 1;
    /// @dev Cancel hook flag for ask-side top changes.
    uint256 internal constant _CANCEL_HOOK_ASK = 2;
    /// @dev High bit in packed match-change metadata indicating a retained dirty right-spine anchor.
    uint256 private constant _MATCH_CHANGE_DIRTY = uint256(1) << 255;

    /// @dev Transient slot carrying the live amount of a displaced top order back to the router.
    bytes32 private constant _TOP_CHANGE_OUTGOING_AMOUNT_SLOT =
        0x64b7215baea1c17e16f66db8b03af21431032e2e221c15ac43b0752d82a69b31;
    /// @dev Transient slot carrying the nonce of the new top order back to the router.
    bytes32 private constant _TOP_CHANGE_INCOMING_NONCE_SLOT =
        0xf95dfdfe2cf36f265e91ff578507ac6f6f9bffb77b95dcb89aef8ed16e5b1f45;

    /// @dev Transient storage slot used by the custom reentrancy guard.
    bytes32 private constant _REENTRANCY_GUARD_SLOT =
        0xc55a21be1c6e869c49c7a5860f6c3a83187eb30a12bcd0421f3cf4f5871dccff;

    /// @notice Emitted when unmatched quantity becomes a resting maker order.
    /// @param bookId Book that received the resting order.
    /// @param order Packed resting order node with contract-assigned nonce.
    /// @param owner Maker that owns the resting order.
    /// @param isBid True for a bid resting in the bid tree, false for an ask resting in the ask tree.
    event OrderRested(bytes32 bookId, bytes32 order, address owner, bool isBid);

    /// @notice Matched resting ask liquidity.
    /// @param bookId Book that supplied the resting ask.
    /// @param restingNode Ask leaf or same-price ask aggregate branch consumed by the incoming bid.
    /// @param quantity Base quantity matched from the resting ask liquidity.
    /// @param quoteAmount Quote value paid at the resting ask price.
    event AskMatched(bytes32 bookId, bytes32 restingNode, uint192 quantity, uint256 quoteAmount);

    /// @notice Matched resting bid liquidity.
    /// @param bookId Book that supplied the resting bid.
    /// @param restingNode Bid leaf or same-price bid aggregate branch consumed by the incoming ask.
    /// @param quantity Base quantity matched from the resting bid liquidity.
    /// @param quoteAmount Quote value paid at the resting bid price.
    event BidMatched(bytes32 bookId, bytes32 restingNode, uint192 quantity, uint256 quoteAmount);

    /// @notice Emitted when a maker cancels open quantity or claims filled proceeds.
    /// @param bookId Book that owned the order.
    /// @param order Original packed resting order node.
    /// @param owner Maker that owned the order.
    /// @param baseAmount Base tokens returned or paid to the maker.
    /// @param quoteAmount Quote tokens returned or paid to the maker.
    event OrderCancelled(bytes32 bookId, bytes32 order, address owner, uint256 baseAmount, uint256 quoteAmount);

    /// @notice Token configuration is invalid.
    error InvalidToken();
    /// @notice Order fields are invalid for the requested operation.
    error InvalidOrder();
    /// @notice The decrementing 40-bit nonce space has been exhausted.
    error NonceExhausted();
    /// @notice Routed book has not been initialized.
    error InvalidBook();
    /// @notice A fill-or-kill leg could not fully fill.
    error FillOrKill();
    /// @notice A duplicate price/nonce path was encountered.
    error DuplicateOrder();
    /// @notice Caller is not the owner recorded for the original order key.
    error NotOrderOwner();
    /// @notice Reentrant call attempted while `fill` or `cancel` is executing.
    error ReentrantCall();

    /// @dev Guards external entrypoints through transient storage.
    modifier nonReentrant() {
        /// @solidity memory-safe-assembly
        assembly {
            if tload(_REENTRANCY_GUARD_SLOT) {
                mstore(0x00, 0x37ed32e8) // `ReentrantCall()`.
                revert(0x1c, 0x04)
            }
            tstore(_REENTRANCY_GUARD_SLOT, 1)
        }
        _;
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_REENTRANCY_GUARD_SLOT, 0)
        }
    }

    /// @notice Return the maker that owns an order id, or zero if the order has been claimed/canceled.
    /// @dev Preserves the old `ownerOfOrder(bytes32) -> address` external API while the underlying
    /// storage now keeps side metadata in the same packed struct slot.
    function ownerOfOrder(bytes32 orderId) public view virtual returns (address) {
        return orderOf[orderId].owner;
    }

    /// @notice Return whether an active order id belongs to the bid tree.
    /// @dev The value is meaningful only when `ownerOfOrder(orderId) != address(0)`.
    function isBidOrder(bytes32 orderId) public view virtual returns (bool) {
        return orderOf[orderId].isBid;
    }

    /// @notice Match an incoming order against a routed book without transferring tokens.
    /// @param bookId Globally unique book id.
    /// @param book Book storage selected by `bookId`.
    /// @param order Packed incoming order with price and quantity set, nonce bits set to zero.
    /// @param isBid True for a bid, false for an ask.
    /// @return limitPrice Incoming limit price.
    /// @return remaining Incoming base quantity left unmatched.
    /// @return baseFilled Base quantity matched.
    /// @return quoteAmount Quote value matched.
    function _matchBook(bytes32 bookId, Book storage book, bytes32 order, bool isBid, bool hookEnabled)
        internal
        returns (uint24 limitPrice, uint192 remaining, uint192 baseFilled, uint256 quoteAmount)
    {
        (limitPrice, remaining) = _validateIncomingOrder(order);

        if (isBid) {
            (remaining, baseFilled, quoteAmount) = _matchIncomingBid(bookId, book, limitPrice, remaining, hookEnabled);
        } else {
            (remaining, baseFilled, quoteAmount) = _matchIncomingAsk(bookId, book, limitPrice, remaining, hookEnabled);
        }
    }

    function _matchIncomingBid(
        bytes32 bookId,
        Book storage book,
        uint24 limitPrice,
        uint192 remaining,
        bool hookEnabled
    ) private returns (uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount) {
        bytes32 root = book.tree[_ROOT_NODE].leftNode;
        if (root == bytes32(0)) return (remaining, 0, 0);

        bytes32 newRoot;
        bytes32 matchChange;
        uint256 matchFlags = _rightSpineDirty(book, false) ? _MATCH_DIRTY : 0;
        if (hookEnabled) matchFlags |= _MATCH_HOOK;
        (newRoot, baseFilled, quoteAmount, matchChange) =
            _matchAskRightSpine(bookId, book, root, limitPrice, remaining, matchFlags);
        unchecked {
            newRemaining = remaining - baseFilled;
        }
        if (newRoot != root) book.tree[_ROOT_NODE].leftNode = newRoot;
        if (_matchChangeDirty(matchChange) && newRoot != bytes32(0)) _setRightSpineDirty(book, false);
    }

    function _matchIncomingAsk(
        bytes32 bookId,
        Book storage book,
        uint24 limitPrice,
        uint192 remaining,
        bool hookEnabled
    ) private returns (uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount) {
        bytes32 root = book.tree[_ROOT_NODE].rightNode;
        if (root == bytes32(0)) return (remaining, 0, 0);

        bytes32 newRoot;
        bytes32 matchChange;
        uint256 matchFlags = _rightSpineDirty(book, true) ? _MATCH_DIRTY : 0;
        if (hookEnabled) matchFlags |= _MATCH_HOOK;
        (newRoot, baseFilled, quoteAmount, matchChange) =
            _matchBidRightSpine(bookId, book, root, limitPrice, remaining, matchFlags);
        unchecked {
            newRemaining = remaining - baseFilled;
        }
        if (newRoot != root) book.tree[_ROOT_NODE].rightNode = newRoot;
        if (_matchChangeDirty(matchChange) && newRoot != bytes32(0)) _setRightSpineDirty(book, true);
    }

    /// @notice Cancel an open order or claim a filled order.
    /// @param order Original packed resting order returned by `fill`.
    /// @return owner Owner paid by the router.
    /// @return isBid True if the original order was a bid.
    /// @return baseAmount Base tokens paid to the maker.
    /// @return quoteAmount Quote tokens paid to the maker.
    /// @dev
    /// `cancel` is also the asynchronous claim path. The original order key always stores the
    /// owner and side while active, even if the live leaf has been partially filled and now has a
    /// different quantity.
    ///
    /// - If the order is absent from the tree, it has fully filled and the maker claims proceeds.
    /// - If a live leaf with the same price/nonce exists, its quantity is returned/canceled and the
    ///   difference between original and remaining quantity is claimed as filled proceeds.
    ///
    /// The order state is deleted before payout. If a token transfer reverts, the whole transaction
    /// reverts and the claim remains live.
    function _cancelBook(bytes32 bookId, Book storage book, bytes32 order, address caller, uint256 hookFlags)
        internal
        returns (address owner, bool isBid, uint256 baseAmount, uint256 quoteAmount)
    {
        bytes32 orderKey = _orderId(bookId, order);
        OrderState storage state = orderOf[orderKey];
        owner = state.owner;
        if (owner != caller) {
            if (_nextNonce(book) == 0) revert InvalidBook();
            if (_quantity(order) == 0) revert InvalidOrder();
            revert NotOrderOwner();
        }

        uint192 originalQuantity = _quantity(order);
        if (originalQuantity == 0) revert InvalidOrder();
        isBid = state.isBid;
        bool hookEnabled = hookFlags & (isBid ? _CANCEL_HOOK_BID : _CANCEL_HOOK_ASK) != 0;

        bytes32 removed = _removeOrderFromBook(book, order, isBid, hookEnabled);

        (baseAmount, quoteAmount) = _cancelAmounts(order, removed, isBid, originalQuantity);

        delete orderOf[orderKey];

        emit OrderCancelled(bookId, order, owner, baseAmount, quoteAmount);
    }

    function _cancelAmounts(bytes32 order, bytes32 removed, bool isBid, uint192 originalQuantity)
        private
        pure
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        uint192 remainingQuantity = 0;
        if (removed != bytes32(0)) {
            remainingQuantity = _quantity(removed);
        }
        if (remainingQuantity > originalQuantity) revert InvalidOrder();
        uint192 filledQuantity;
        unchecked {
            filledQuantity = originalQuantity - remainingQuantity;
        }
        uint24 limitPrice = _price(order);
        if (isBid) {
            baseAmount = filledQuantity;
            quoteAmount = _quoteValue(limitPrice, remainingQuantity);
        } else {
            baseAmount = remainingQuantity;
            quoteAmount = _quoteValue(limitPrice, filledQuantity);
        }
    }

    function _removeOrderFromBook(Book storage book, bytes32 order, bool isBid, bool hookEnabled)
        private
        returns (bytes32 removed)
    {
        if (isBid) {
            bytes32 root = book.tree[_ROOT_NODE].rightNode;
            bytes32 newRoot;
            if (root != bytes32(0)) {
                bool dirtyChanged;
                bool removedTop;
                (newRoot, removed, dirtyChanged, removedTop) = _removeBidByKey(book, root, _bidSortKey(order), true);
                if (removed != bytes32(0) && newRoot != root) {
                    book.tree[_ROOT_NODE].rightNode = newRoot;
                }
                if (dirtyChanged && newRoot != bytes32(0)) _setRightSpineDirty(book, true);
                if (hookEnabled && removedTop) {
                    _recordTopOrderChange(_quantity(removed), _replacementTopNonce(book, newRoot));
                }
            }
        } else {
            bytes32 root = book.tree[_ROOT_NODE].leftNode;
            bytes32 newRoot;
            if (root != bytes32(0)) {
                bool dirtyChanged;
                bool removedTop;
                (newRoot, removed, dirtyChanged, removedTop) = _removeAskByKey(book, root, _askSortKey(order), true);
                if (removed != bytes32(0) && newRoot != root) {
                    book.tree[_ROOT_NODE].leftNode = newRoot;
                }
                if (dirtyChanged && newRoot != bytes32(0)) _setRightSpineDirty(book, false);
                if (hookEnabled && removedTop) {
                    _recordTopOrderChange(_quantity(removed), _replacementTopNonce(book, newRoot));
                }
            }
        }
    }

    /// @notice Rest unmatched quantity in one book.
    /// @param bookId Globally unique book id.
    /// @param book Book storage selected by `bookId`.
    /// @param nonceAndFlags Current packed nonce and right-spine flags for `book`.
    /// @param price Limit price.
    /// @param quantity Unfilled base quantity to rest.
    /// @param isBid True to rest a bid, false to rest an ask.
    /// @param owner Maker owner.
    /// @return restingOrder Packed resting order with assigned nonce.
    /// @return nextNonceAfter The book nonce after assigning `restingOrder`.
    function _restBook(
        bytes32 bookId,
        Book storage book,
        uint256 nonceAndFlags,
        uint24 price,
        uint192 quantity,
        bool isBid,
        address owner,
        bool hookEnabled
    ) internal returns (bytes32 restingOrder, uint40 nextNonceAfter) {
        uint256 dirtyFlag = isBid ? _BID_RIGHT_SPINE_DIRTY : _ASK_RIGHT_SPINE_DIRTY;
        if (nonceAndFlags & dirtyFlag != 0) {
            if (isBid) {
                book.tree[_ROOT_NODE].rightNode = _materializeRightSpine(book, book.tree[_ROOT_NODE].rightNode);
            } else {
                book.tree[_ROOT_NODE].leftNode = _materializeRightSpine(book, book.tree[_ROOT_NODE].leftNode);
            }
            nonceAndFlags &= ~dirtyFlag;
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 nonce = uint40(nonceAndFlags & _NONCE_MASK);
        if (nonce <= 1) revert NonceExhausted();
        unchecked {
            nextNonceAfter = nonce - 1;
        }
        unchecked {
            book.nonceAndFlags = (nonceAndFlags & ~_NONCE_MASK) | uint256(nextNonceAfter);
        }

        restingOrder = _pack(price, quantity, nonce);
        orderOf[_orderId(bookId, restingOrder)] = OrderState({owner: owner, isBid: isBid});

        _insertRestingOrder(book, restingOrder, price, nonce, isBid, hookEnabled);

        emit OrderRested(bookId, restingOrder, owner, isBid);
    }

    function _insertRestingOrder(
        Book storage book,
        bytes32 restingOrder,
        uint24 price,
        uint40 nonce,
        bool isBid,
        bool hookEnabled
    ) private {
        if (isBid) {
            bytes32 root = book.tree[_ROOT_NODE].rightNode;
            book.tree[_ROOT_NODE].rightNode =
                _insertBid(book, root, restingOrder, (uint64(price) << 40) | uint64(nonce), hookEnabled);
        } else {
            bytes32 root = book.tree[_ROOT_NODE].leftNode;
            unchecked {
                book.tree[_ROOT_NODE].leftNode = _insertAsk(
                    book, root, restingOrder, (uint64(_MAX_PRICE - price) << 40) | uint64(nonce), hookEnabled
                );
            }
        }
    }

    /// @notice Match an incoming bid against one ask leaf.
    /// @param root Ask leaf node.
    /// @param limitPrice Bid limit price.
    /// @param remaining Incoming bid quantity.
    /// @return newRoot Zero if fully consumed, reduced leaf if partially consumed, original leaf if not crossing.
    /// @return newRemaining Incoming bid quantity after this leaf.
    /// @return baseFilled Base quantity filled from this ask.
    /// @return quoteAmount Quote paid at the resting ask price.
    function _matchAskLeaf(bytes32 bookId, bytes32 root, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        (uint24 restingPrice, uint192 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice > limitPrice) return (root, remaining, 0, 0);

        uint192 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteValue(restingPrice, fillQuantity);

        emit AskMatched(bookId, root, fillQuantity, quoteAmount);

        unchecked {
            newRemaining = remaining - fillQuantity;
            baseFilled = fillQuantity;
        }

        if (fillQuantity < restingQuantity) {
            unchecked {
                newRoot = _withQuantity(root, restingQuantity - fillQuantity);
            }
        }
    }

    /// @notice Match an incoming ask against one bid leaf.
    /// @param root Bid leaf node.
    /// @param limitPrice Ask limit price.
    /// @param remaining Incoming ask quantity.
    /// @return newRoot Zero if fully consumed, reduced leaf if partially consumed, original leaf if not crossing.
    /// @return newRemaining Incoming ask quantity after this leaf.
    /// @return baseFilled Base quantity filled into this bid.
    /// @return quoteAmount Quote paid at the resting bid price.
    function _matchBidLeaf(bytes32 bookId, bytes32 root, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        (uint24 restingPrice, uint192 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice < limitPrice) return (root, remaining, 0, 0);

        uint192 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteValue(restingPrice, fillQuantity);

        emit BidMatched(bookId, root, fillQuantity, quoteAmount);

        unchecked {
            newRemaining = remaining - fillQuantity;
            baseFilled = fillQuantity;
        }

        if (fillQuantity < restingQuantity) {
            unchecked {
                newRoot = _withQuantity(root, restingQuantity - fillQuantity);
            }
        }
    }

    function _emitAskRightSpineMatch(
        bytes32 bookId,
        bytes32 node,
        uint192 fillQuantity,
        uint256 quoteAmount,
        uint256 matchFlags
    ) private {
        emit AskMatched(
            bookId, matchFlags & _MATCH_DIRTY != 0 ? _withQuantity(node, fillQuantity) : node, fillQuantity, quoteAmount
        );
    }

    function _emitBidRightSpineMatch(
        bytes32 bookId,
        bytes32 node,
        uint192 fillQuantity,
        uint256 quoteAmount,
        uint256 matchFlags
    ) private {
        emit BidMatched(
            bookId, matchFlags & _MATCH_DIRTY != 0 ? _withQuantity(node, fillQuantity) : node, fillQuantity, quoteAmount
        );
    }

    /// @notice Recursively match an incoming bid against an ask subtree.
    /// @param node Ask leaf or branch to inspect.
    /// @param limitPrice Bid limit price.
    /// @param remaining Incoming bid quantity available to spend in this subtree.
    /// @return newNode Replacement node for this subtree after matching.
    /// @return fillQuantity Base quantity consumed from this subtree.
    /// @return quoteAmount Quote value consumed from this subtree.
    /// @dev
    /// The ask tree's rightmost path is best because ask prices are inverted in the sort key.
    /// Right-spine branch words may be stale after previous optimized updates, so this function
    /// only aggregate-consumes same-price right-spine subtrees. Mixed-price aggregate consumption
    /// remains reserved for exact off-spine subtrees to avoid reintroducing the branch rewrite
    /// cascade this path is designed to skip.
    function _matchAskRightSpine(
        bytes32 bookId,
        Book storage book,
        bytes32 node,
        uint24 limitPrice,
        uint192 remaining,
        uint256 matchFlags
    ) private returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount, bytes32 matchChange) {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(bookId, node, limitPrice, remaining);
            if (matchFlags & _MATCH_HOOK != 0 && fillQuantity != 0) {
                _recordTopOrderChange(_quantity(node), newNode == bytes32(0) ? 0 : _nonce(newNode));
            }
            return (newNode, fillQuantity, quoteAmount, matchChange);
        }

        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            if (_price(leftNode) == _price(rightNode)) {
                uint192 outgoingTopQuantity;
                (fillQuantity, outgoingTopQuantity) =
                    _samePriceRightSpineFillQuantity(book, node, limitPrice, remaining, matchFlags);
                if (fillQuantity != 0) {
                    if (matchFlags & _MATCH_HOOK != 0) {
                        _recordTopOrderChange(outgoingTopQuantity, 0);
                    }
                    quoteAmount = _quoteValue(_price(node), fillQuantity);
                    _emitAskRightSpineMatch(bookId, node, fillQuantity, quoteAmount, matchFlags);
                    return (bytes32(0), fillQuantity, quoteAmount, matchChange);
                }
            }

            (newRightNode, rightFillQuantity, rightQuoteAmount, matchChange) =
                _matchAskRightSpine(bookId, book, rightNode, limitPrice, remaining, matchFlags);
        }
        if (rightFillQuantity == 0) return (node, 0, 0, bytes32(0));

        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchAskSubtree(bookId, book, leftNode, limitPrice, remaining);
        }

        if (fillQuantity == 0) {
            bool branchDirty;
            (newNode, branchDirty) = _replaceRightmostRightChild(book, node, newLeftNode, newRightNode);
            if (branchDirty) matchChange = _markMatchDirty(matchChange);
        } else {
            newNode = _replaceBranch(book, newLeftNode, newRightNode);
        }
        unchecked {
            fillQuantity += rightFillQuantity;
            quoteAmount += rightQuoteAmount;
        }
        if (matchFlags & _MATCH_HOOK != 0) _refreshRecordedTopNonce(book, newNode);
    }

    /// @notice Recursively match an incoming bid against an exact ask subtree.
    /// @param node Ask leaf or exact aggregate branch to inspect.
    /// @param limitPrice Bid limit price.
    /// @param remaining Incoming bid quantity available to spend in this subtree.
    /// @return newNode Replacement node for this subtree after matching.
    /// @return fillQuantity Base quantity consumed from this subtree.
    /// @return quoteAmount Quote value consumed from this subtree.
    function _matchAskSubtree(bytes32 bookId, Book storage book, bytes32 node, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(bookId, node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        uint192 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(book, node) <= limitPrice) {
            quoteAmount = _consumeSubtree(bookId, book, node, false);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            (newRightNode, rightFillQuantity, rightQuoteAmount) =
                _matchAskSubtree(bookId, book, rightNode, limitPrice, remaining);
        }
        if (rightFillQuantity == 0) return (node, 0, 0);

        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchAskSubtree(bookId, book, leftNode, limitPrice, remaining);
        }

        newNode = _replaceBranch(book, newLeftNode, newRightNode);
        unchecked {
            fillQuantity += rightFillQuantity;
            quoteAmount += rightQuoteAmount;
        }
    }

    /// @notice Recursively match an incoming ask against a bid subtree.
    /// @param node Bid leaf or branch to inspect.
    /// @param limitPrice Ask limit price.
    /// @param remaining Incoming ask quantity available to sell in this subtree.
    /// @return newNode Replacement node for this subtree after matching.
    /// @return fillQuantity Base quantity consumed from this subtree.
    /// @return quoteAmount Quote value consumed from this subtree.
    /// @dev
    /// The bid tree's rightmost path is best because higher prices sort later. Right-spine branch
    /// words may be stale after previous optimized updates, so this function only aggregate-consumes
    /// same-price right-spine subtrees. Mixed-price aggregate consumption remains reserved for exact
    /// off-spine subtrees to avoid reintroducing the branch rewrite cascade this path is designed
    /// to skip.
    function _matchBidRightSpine(
        bytes32 bookId,
        Book storage book,
        bytes32 node,
        uint24 limitPrice,
        uint192 remaining,
        uint256 matchFlags
    ) private returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount, bytes32 matchChange) {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(bookId, node, limitPrice, remaining);
            if (matchFlags & _MATCH_HOOK != 0 && fillQuantity != 0) {
                _recordTopOrderChange(_quantity(node), newNode == bytes32(0) ? 0 : _nonce(newNode));
            }
            return (newNode, fillQuantity, quoteAmount, matchChange);
        }

        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            if (_price(leftNode) == _price(rightNode)) {
                uint192 outgoingTopQuantity;
                (fillQuantity, outgoingTopQuantity) = _samePriceRightSpineFillQuantity(
                    book, node, limitPrice, remaining, matchFlags | _MATCH_RESTING_BID
                );
                if (fillQuantity != 0) {
                    if (matchFlags & _MATCH_HOOK != 0) {
                        _recordTopOrderChange(outgoingTopQuantity, 0);
                    }
                    quoteAmount = _quoteValue(_price(node), fillQuantity);
                    _emitBidRightSpineMatch(bookId, node, fillQuantity, quoteAmount, matchFlags);
                    return (bytes32(0), fillQuantity, quoteAmount, matchChange);
                }
            }

            (newRightNode, rightFillQuantity, rightQuoteAmount, matchChange) =
                _matchBidRightSpine(bookId, book, rightNode, limitPrice, remaining, matchFlags);
        }
        if (rightFillQuantity == 0) return (node, 0, 0, bytes32(0));

        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchBidSubtree(bookId, book, leftNode, limitPrice, remaining);
        }

        if (fillQuantity == 0) {
            bool branchDirty;
            (newNode, branchDirty) = _replaceRightmostRightChild(book, node, newLeftNode, newRightNode);
            if (branchDirty) matchChange = _markMatchDirty(matchChange);
        } else {
            newNode = _replaceBranch(book, newLeftNode, newRightNode);
        }
        unchecked {
            fillQuantity += rightFillQuantity;
            quoteAmount += rightQuoteAmount;
        }
        if (matchFlags & _MATCH_HOOK != 0) _refreshRecordedTopNonce(book, newNode);
    }

    /// @notice Recursively match an incoming ask against an exact bid subtree.
    /// @param node Bid leaf or exact aggregate branch to inspect.
    /// @param limitPrice Ask limit price.
    /// @param remaining Incoming ask quantity available to sell in this subtree.
    /// @return newNode Replacement node for this subtree after matching.
    /// @return fillQuantity Base quantity consumed from this subtree.
    /// @return quoteAmount Quote value consumed from this subtree.
    function _matchBidSubtree(bytes32 bookId, Book storage book, bytes32 node, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(bookId, node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        uint192 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(book, node) >= limitPrice) {
            quoteAmount = _consumeSubtree(bookId, book, node, true);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            (newRightNode, rightFillQuantity, rightQuoteAmount) =
                _matchBidSubtree(bookId, book, rightNode, limitPrice, remaining);
        }
        if (rightFillQuantity == 0) return (node, 0, 0);

        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchBidSubtree(bookId, book, leftNode, limitPrice, remaining);
        }

        newNode = _replaceBranch(book, newLeftNode, newRightNode);
        unchecked {
            fillQuantity += rightFillQuantity;
            quoteAmount += rightQuoteAmount;
        }
    }

    /// @notice Insert a leaf or branch into the bid tree.
    /// @param root Current subtree root.
    /// @param node Node to insert.
    /// @param nodeKey Bid sort key for `node`.
    /// @return newRoot Updated subtree root.
    /// @dev
    /// Insertion follows Patricia/radix-tree rules. If the new key diverges before the current
    /// branch split, a new parent branch is created above `root`. Otherwise recursion continues
    /// into the child selected by the branch split bit.
    function _insertBid(Book storage book, bytes32 root, bytes32 node, uint64 nodeKey, bool hookEnabled)
        private
        returns (bytes32 newRoot)
    {
        if (root == bytes32(0)) {
            if (hookEnabled) _recordTopOrderChange(0, _nonce(node));
            return node;
        }

        bytes32 leftNode = book.tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            if (hookEnabled && nodeKey > _bidSortKey(root)) {
                _recordTopOrderChange(_quantity(root), _nonce(node));
            }
            return _storeBranch(book, root, node, _bidSortKey(root), nodeKey);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _bidSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _bidSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            if (hookEnabled && _bit(nodeKey, _commonPrefix(nodeKey, leftKey))) {
                _recordTopOrderChange(_quantity(_rightmostLeaf(book, root)), _nonce(node));
            }
            return _storeBranch(book, root, node, _bidSortKey(root), nodeKey);
        }

        if (_bit(nodeKey, branchDepth)) {
            rightNode = _insertBid(book, rightNode, node, nodeKey, hookEnabled);
        } else {
            leftNode = _insertBid(book, leftNode, node, nodeKey, false);
        }

        return _replaceBranch(book, leftNode, rightNode);
    }

    /// @notice Insert a leaf or branch into the ask tree.
    /// @param root Current subtree root.
    /// @param node Node to insert.
    /// @param nodeKey Ask sort key for `node`.
    /// @return newRoot Updated subtree root.
    /// @dev Same insertion algorithm as bids, but callers provide inverted-price ask keys.
    function _insertAsk(Book storage book, bytes32 root, bytes32 node, uint64 nodeKey, bool hookEnabled)
        private
        returns (bytes32 newRoot)
    {
        if (root == bytes32(0)) {
            if (hookEnabled) _recordTopOrderChange(0, _nonce(node));
            return node;
        }

        bytes32 leftNode = book.tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            if (hookEnabled && nodeKey > _askSortKey(root)) {
                _recordTopOrderChange(_quantity(root), _nonce(node));
            }
            return _storeBranch(book, root, node, _askSortKey(root), nodeKey);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _askSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _askSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            if (hookEnabled && _bit(nodeKey, _commonPrefix(nodeKey, leftKey))) {
                _recordTopOrderChange(_quantity(_rightmostLeaf(book, root)), _nonce(node));
            }
            return _storeBranch(book, root, node, _askSortKey(root), nodeKey);
        }

        if (_bit(nodeKey, branchDepth)) {
            rightNode = _insertAsk(book, rightNode, node, nodeKey, hookEnabled);
        } else {
            leftNode = _insertAsk(book, leftNode, node, nodeKey, false);
        }

        return _replaceBranch(book, leftNode, rightNode);
    }

    /// @notice Remove one bid leaf by exact bid sort key.
    /// @param root Current subtree root.
    /// @param targetKey Bid sort key for the original order.
    /// @return newRoot Updated subtree root.
    /// @return removed Live leaf that was removed, or zero if absent.
    /// @dev
    /// Cancel searches by price/nonce, not by full order word, because a partially filled live leaf
    /// has the same price/nonce as the original order but a smaller quantity.
    function _removeBidByKey(Book storage book, bytes32 root, uint64 targetKey, bool rightmost)
        private
        returns (bytes32 newRoot, bytes32 removed, bool dirtyChanged, bool removedTop)
    {
        bytes32 leftNode = book.tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            return
                _bidSortKey(root) == targetKey ? (bytes32(0), root, false, rightmost) : (root, bytes32(0), false, false);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _bidSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _bidSortKey(rightNode));
        if (_commonPrefix(targetKey, leftKey) < branchDepth) return (root, bytes32(0), false, false);

        bool goRight = _bit(targetKey, branchDepth);
        if (goRight) {
            (rightNode, removed, dirtyChanged, removedTop) = _removeBidByKey(book, rightNode, targetKey, rightmost);
        } else {
            (leftNode, removed, dirtyChanged, removedTop) = _removeBidByKey(book, leftNode, targetKey, false);
        }

        if (removed == bytes32(0)) return (root, bytes32(0), false, false);
        if (rightmost && goRight) {
            bool branchDirty;
            (newRoot, branchDirty) = _replaceRightmostRightChild(book, root, leftNode, rightNode);
            return (newRoot, removed, dirtyChanged || branchDirty, removedTop);
        }
        return (_replaceBranch(book, leftNode, rightNode), removed, dirtyChanged, removedTop);
    }

    /// @notice Remove one ask leaf by exact ask sort key.
    /// @param root Current subtree root.
    /// @param targetKey Ask sort key for the original order.
    /// @return newRoot Updated subtree root.
    /// @return removed Live leaf that was removed, or zero if absent.
    /// @dev Mirrors `_removeBidByKey` using inverted-price ask keys.
    function _removeAskByKey(Book storage book, bytes32 root, uint64 targetKey, bool rightmost)
        private
        returns (bytes32 newRoot, bytes32 removed, bool dirtyChanged, bool removedTop)
    {
        bytes32 leftNode = book.tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            return
                _askSortKey(root) == targetKey ? (bytes32(0), root, false, rightmost) : (root, bytes32(0), false, false);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _askSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _askSortKey(rightNode));
        if (_commonPrefix(targetKey, leftKey) < branchDepth) return (root, bytes32(0), false, false);

        bool goRight = _bit(targetKey, branchDepth);
        if (goRight) {
            (rightNode, removed, dirtyChanged, removedTop) = _removeAskByKey(book, rightNode, targetKey, rightmost);
        } else {
            (leftNode, removed, dirtyChanged, removedTop) = _removeAskByKey(book, leftNode, targetKey, false);
        }

        if (removed == bytes32(0)) return (root, bytes32(0), false, false);
        if (rightmost && goRight) {
            bool branchDirty;
            (newRoot, branchDirty) = _replaceRightmostRightChild(book, root, leftNode, rightNode);
            return (newRoot, removed, dirtyChanged || branchDirty, removedTop);
        }
        return (_replaceBranch(book, leftNode, rightNode), removed, dirtyChanged, removedTop);
    }

    /// @notice Update a right-spine branch after only its right child changed.
    /// @param branchNode Existing branch node used as the stable right-spine anchor.
    /// @param leftNode Existing left child.
    /// @param rightNode Replacement right child.
    /// @return newNode Replacement subtree root.
    /// @return dirtyChanged True if a stable branch anchor was retained with a new right child.
    /// @dev
    /// This is the rightmost-branch optimization. The packed branch word is left in place when the
    /// right child changes, so ancestors on the same right spine do not need to be rewritten. The
    /// branch quantity/path can therefore become stale until the next same-side insertion calls
    /// `_materializeRightSpine`.
    function _replaceRightmostRightChild(Book storage book, bytes32 branchNode, bytes32 leftNode, bytes32 rightNode)
        private
        returns (bytes32 newNode, bool dirtyChanged)
    {
        if (rightNode == bytes32(0)) return (leftNode, false);
        if (rightNode == branchNode || rightNode == leftNode) {
            return (_replaceBranch(book, leftNode, rightNode), false);
        }

        book.tree[branchNode].rightNode = rightNode;
        return (branchNode, true);
    }

    /// @notice Collapse or rewrite a branch after one or both children changed.
    /// @param leftNode Replacement left child.
    /// @param rightNode Replacement right child.
    /// @return Replacement subtree root.
    /// @dev
    /// If one child was consumed or canceled, the other child is promoted. If both remain, the
    /// branch address is recomputed from the child nodes and its pointers are written. Callers pass
    /// children in already-valid left/right order.
    function _replaceBranch(Book storage book, bytes32 leftNode, bytes32 rightNode) private returns (bytes32) {
        bytes32 newBranch;
        if (leftNode == bytes32(0)) {
            newBranch = rightNode;
        } else if (rightNode == bytes32(0)) {
            newBranch = leftNode;
        } else {
            newBranch = _branchNodeForChildren(leftNode, rightNode);
            // Replacement callers preserve left/right ordering from an existing valid branch.
            book.tree[newBranch] = Branch({leftNode: leftNode, rightNode: rightNode});
        }

        return newBranch;
    }

    /// @notice Rebuild a previously optimized right spine back into exact aggregate branches.
    /// @param node Current subtree root.
    /// @return Exact subtree root.
    /// @dev Only the right spine can contain stable anchors. Left subtrees remain exact because the
    /// optimization is used only for right-child updates.
    function _materializeRightSpine(Book storage book, bytes32 node) private returns (bytes32) {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) return node;

        bytes32 rightNode = _materializeRightSpine(book, book.tree[node].rightNode);
        return _replaceBranch(book, leftNode, rightNode);
    }

    /// @notice Return the aggregate quantity for a fully crossing same-price subtree on the global right spine.
    /// @param node Right-spine branch to inspect.
    /// @param limitPrice Incoming order limit price.
    /// @param remaining Incoming base quantity available.
    /// @param matchFlags Internal matcher flags for resting side and dirty right-spine state.
    /// @return fillQuantity Actual base quantity consumable as one same-price aggregate, or zero.
    /// @dev
    /// Dirty right-spine anchors keep correct child pointers but stale packed aggregate fields. For
    /// same-price subtrees the quote value is still price * actual quantity, so this helper recovers
    /// the one-event aggregate path without rewriting every ancestor branch. Mixed-price dirty
    /// subtrees intentionally fall back to the recursive matcher because their quote value cannot be
    /// computed from one price.
    function _samePriceRightSpineFillQuantity(
        Book storage book,
        bytes32 node,
        uint24 limitPrice,
        uint192 remaining,
        uint256 matchFlags
    ) private view returns (uint192 fillQuantity, uint192 outgoingTopQuantity) {
        uint24 price;
        (price, outgoingTopQuantity) = _singlePriceSubtree(book, node);
        if (price == 0) return (0, 0);
        if (matchFlags & _MATCH_RESTING_BID != 0 ? price < limitPrice : price > limitPrice) return (0, 0);

        fillQuantity = matchFlags & _MATCH_DIRTY != 0 ? _actualSubtreeQuantity(book, node) : _quantity(node);
        if (fillQuantity > remaining) return (0, 0);
    }

    /// @notice Compute the live leaf quantity under a subtree by following child pointers.
    /// @param node Subtree root.
    /// @return quantity Sum of live leaf quantities.
    /// @dev Used only when a right-spine anchor may be stale and its packed quantity cannot be
    /// trusted. Left subtrees below a dirty right spine are exact, but recursion is simpler and
    /// still bounded by the radix tree depth plus the consumed same-price subtree size.
    function _actualSubtreeQuantity(Book storage book, bytes32 node) private view returns (uint192 quantity) {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) return _quantity(node);

        quantity = _actualSubtreeQuantity(book, leftNode);
        unchecked {
            quantity += _actualSubtreeQuantity(book, book.tree[node].rightNode);
        }
    }

    /// @notice Create and store a two-child branch for two nonzero nodes.
    /// @param a First child candidate.
    /// @param b Second child candidate.
    /// @param aKey Sort key for `a` in the tree being modified.
    /// @param bKey Sort key for `b` in the tree being modified.
    /// @return branchNode Self-addressed branch node.
    /// @dev
    /// The first bit where `aKey` and `bKey` differ decides child order. Equal keys are impossible
    /// for honest state because nonce assignment is unique; if corruption makes them equal, this
    /// reverts before overwriting ownership or branch data.
    /// Callers pass nonzero children; empty-subtree cases are handled before this helper is reached.
    function _storeBranch(Book storage book, bytes32 a, bytes32 b, uint64 aKey, uint64 bKey)
        private
        returns (bytes32 branchNode)
    {
        uint8 branchDepth = _commonPrefix(aKey, bKey);
        if (branchDepth == 64) revert DuplicateOrder();

        bytes32 leftNode = a;
        bytes32 rightNode = b;
        if (_bit(aKey, branchDepth)) {
            leftNode = b;
            rightNode = a;
        }

        branchNode = _branchNodeForChildren(a, b);
        // Walkers use leftNode as the branch sentinel, so stored branches are always two-child.
        book.tree[branchNode] = Branch({leftNode: leftNode, rightNode: rightNode});
    }

    /// @notice Compute the self-addressed branch node for two children.
    /// @param a First child.
    /// @param b Second child.
    /// @return Branch node whose quantity is the child sum and path is the maximum child path key.
    /// @dev Uses the raw price/nonce path, not the bid/ask sort key, so bid and ask branches with
    /// different economic meaning can still coexist in the same mapping as long as their resulting
    /// `bytes32` branch keys differ. Tests assert that live bid/ask branches do not share storage.
    function _branchNodeForChildren(bytes32 a, bytes32 b) private pure returns (bytes32) {
        uint64 aAddressKey = _pathKey(a);
        uint64 bAddressKey = _pathKey(b);
        uint64 boundaryKey = aAddressKey > bAddressKey ? aAddressKey : bAddressKey;
        return _branchNode(boundaryKey, _quantity(a) + _quantity(b));
    }

    /// @notice Pack a branch node from a raw path key and aggregate quantity.
    /// @param key Raw `price || nonce` path key used as the branch address suffix.
    /// @param quantity Aggregate quantity represented by the branch.
    /// @return node Packed branch node.
    function _branchNode(uint64 key, uint192 quantity) private pure returns (bytes32 node) {
        /// @solidity memory-safe-assembly
        assembly {
            node := or(
                or(shl(_PRICE_SHIFT, shr(_QUANTITY_SHIFT, key)), shl(_QUANTITY_SHIFT, quantity)),
                and(key, 0xffffffffff)
            )
        }
    }

    /// @notice Return the common price for a subtree, or zero if the subtree spans multiple prices.
    /// @param node Subtree root.
    /// @return price Nonzero common price, or zero as the mixed-price sentinel.
    /// @dev
    /// Price zero is invalid for live orders, so zero is safe as the sentinel. The function only
    /// checks the leftmost and rightmost leaf because branch ordering invariants guarantee every
    /// leaf between them is within that price range.
    function _singlePriceSubtree(Book storage book, bytes32 node)
        private
        view
        returns (uint24 price, uint192 rightmostQuantity)
    {
        bytes32 leftmost = node;
        while (true) {
            bytes32 leftNode = book.tree[leftmost].leftNode;
            if (leftNode == bytes32(0)) break;
            leftmost = leftNode;
        }

        bytes32 rightmost = node;
        while (true) {
            bytes32 rightNode = book.tree[rightmost].rightNode;
            if (rightNode == bytes32(0)) break;
            rightmost = rightNode;
        }

        price = _price(leftmost);
        if (price != _price(rightmost)) return (0, 0);
        rightmostQuantity = _quantity(rightmost);
    }

    /// @notice Return the price of the leftmost leaf in a subtree.
    /// @param node Subtree root.
    /// @return price Price of the worst executable leaf in the subtree.
    /// @dev
    /// For bids, the leftmost leaf has the lowest bid price. For asks, the leftmost leaf has the
    /// highest ask price because ask sort keys invert price. In both cases this is the "worst"
    /// price that must cross before an entire subtree can be aggregate-consumed.
    function _leftmostLeafPrice(Book storage book, bytes32 node) private view returns (uint24 price) {
        while (true) {
            bytes32 leftNode = book.tree[node].leftNode;
            if (leftNode == bytes32(0)) {
                price = _price(node);
                break;
            }
            node = leftNode;
        }
    }

    /// @notice Return the best leaf in a subtree.
    /// @param node Subtree root.
    /// @return leaf Rightmost live leaf under `node`.
    /// @dev The right child is always the better sort-key side for both bid and ask trees.
    function _rightmostLeaf(Book storage book, bytes32 node) private view returns (bytes32 leaf) {
        while (true) {
            bytes32 rightNode = book.tree[node].rightNode;
            if (rightNode == bytes32(0)) return node;
            node = rightNode;
        }
    }

    /// @notice Fill in the new top nonce after a top subtree was fully removed.
    /// @dev A zero incoming nonce in transient top-change storage means the immediate match/cancel
    /// site could not know the next top order yet. Ancestor frames call this after rebuilding
    /// `newNode`.
    function _refreshRecordedTopNonce(Book storage book, bytes32 newNode) private {
        uint192 outgoingAmount;
        uint40 incomingNonce;
        /// @solidity memory-safe-assembly
        assembly {
            outgoingAmount := tload(_TOP_CHANGE_OUTGOING_AMOUNT_SLOT)
            incomingNonce := tload(_TOP_CHANGE_INCOMING_NONCE_SLOT)
        }
        if (outgoingAmount == 0 && incomingNonce == 0) return;
        if (incomingNonce != 0 || newNode == bytes32(0)) return;
        incomingNonce = _replacementTopNonce(book, newNode);
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_TOP_CHANGE_INCOMING_NONCE_SLOT, incomingNonce)
        }
    }

    /// @notice Return the nonce of a replacement subtree's best leaf.
    /// @dev If the replacement is a leaf, the nonce is already known. `_rightmostLeaf` is only needed
    /// when a top removal leaves a branch root and the successor leaf is not encoded in that root.
    function _replacementTopNonce(Book storage book, bytes32 newNode) private view returns (uint40) {
        if (newNode == bytes32(0)) return 0;
        if (book.tree[newNode].leftNode == bytes32(0)) return _nonce(newNode);
        return _nonce(_rightmostLeaf(book, newNode));
    }

    /// @notice Record one top-order change in transient storage for the router to consume.
    /// @dev Either slot being nonzero is the signal that a hook should be considered. First rest
    /// writes only `incomingNonce`; an emptied side writes only `outgoingAmount`.
    function _recordTopOrderChange(uint192 outgoingAmount, uint40 incomingNonce) private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_TOP_CHANGE_OUTGOING_AMOUNT_SLOT, outgoingAmount)
            tstore(_TOP_CHANGE_INCOMING_NONCE_SLOT, incomingNonce)
        }
    }

    /// @notice Consume and clear the latest recorded top-order change.
    function _takeTopOrderChange() internal returns (uint192 outgoingAmount, uint40 incomingNonce) {
        /// @solidity memory-safe-assembly
        assembly {
            outgoingAmount := tload(_TOP_CHANGE_OUTGOING_AMOUNT_SLOT)
            incomingNonce := tload(_TOP_CHANGE_INCOMING_NONCE_SLOT)
            tstore(_TOP_CHANGE_OUTGOING_AMOUNT_SLOT, 0)
            tstore(_TOP_CHANGE_INCOMING_NONCE_SLOT, 0)
        }
    }

    /// @notice Consume a subtree that has already been proven fully crossing and small enough.
    /// @param node Subtree root.
    /// @param restingIsBid True if the consumed subtree is from the bid tree.
    /// @return quoteAmount Total quote value of the consumed subtree.
    /// @dev
    /// Same-price subtrees can be emitted as one aggregate match event because every maker
    /// fills at the same price. Mixed-price subtrees recurse right first to preserve execution
    /// priority in emitted match events.
    function _consumeSubtree(bytes32 bookId, Book storage book, bytes32 node, bool restingIsBid)
        private
        returns (uint256 quoteAmount)
    {
        uint192 quantity = _quantity(node);
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            quoteAmount = _quoteValue(_price(node), quantity);
            if (restingIsBid) {
                emit BidMatched(bookId, node, quantity, quoteAmount);
            } else {
                emit AskMatched(bookId, node, quantity, quoteAmount);
            }
            return quoteAmount;
        }

        (uint24 price,) = _singlePriceSubtree(book, node);
        if (price != 0) {
            quoteAmount = _quoteValue(price, quantity);
            if (restingIsBid) {
                emit BidMatched(bookId, node, quantity, quoteAmount);
            } else {
                emit AskMatched(bookId, node, quantity, quoteAmount);
            }
            return quoteAmount;
        }

        quoteAmount = _consumeSubtree(bookId, book, book.tree[node].rightNode, restingIsBid);
        unchecked {
            quoteAmount += _consumeSubtree(bookId, book, leftNode, restingIsBid);
        }
    }

    /// @notice Build the bid sort key from an order or branch node.
    /// @param order Packed node.
    /// @return key Bid sort key: `price || nonce`.
    /// @dev Higher keys are better bids: higher price first, then higher nonce for earlier time.
    function _bidSortKey(bytes32 order) private pure returns (uint64 key) {
        /// @solidity memory-safe-assembly
        assembly {
            key := or(shl(_QUANTITY_SHIFT, shr(_PRICE_SHIFT, order)), and(order, 0xffffffffff))
        }
    }

    /// @notice Build the ask sort key from an order or branch node.
    /// @param order Packed node.
    /// @return key Ask sort key: `(maxPrice - price) || nonce`.
    /// @dev Higher keys are better asks: lower price first after inversion, then higher nonce for earlier time.
    function _askSortKey(bytes32 order) private pure returns (uint64 key) {
        /// @solidity memory-safe-assembly
        assembly {
            key := or(shl(_QUANTITY_SHIFT, sub(0xffffff, shr(_PRICE_SHIFT, order))), and(order, 0xffffffffff))
        }
    }

    /// @notice Build the raw address path key from a node.
    /// @param order Packed node.
    /// @return key Raw `price || nonce` key, ignoring quantity.
    /// @dev Branch addresses use raw path keys for both sides of the book.
    function _pathKey(bytes32 order) private pure returns (uint64 key) {
        /// @solidity memory-safe-assembly
        assembly {
            key := or(shl(_QUANTITY_SHIFT, shr(_PRICE_SHIFT, order)), and(order, 0xffffffffff))
        }
    }

    /// @notice Count matching leading bits between two 64-bit radix keys.
    /// @param a First key.
    /// @param b Second key.
    /// @return prefixLength Number of equal leading bits, from 0 to 64.
    /// @dev
    /// A value of 64 means the keys are identical and cannot form a branch. The implementation
    /// left-aligns the xor into a 256-bit word so Solady `LibBit.clz` can count the leading zeros.
    function _commonPrefix(uint64 a, uint64 b) private pure returns (uint8 prefixLength) {
        uint256 differingBits = uint256(a ^ b);
        if (differingBits == 0) return 64;

        unchecked {
            prefixLength = uint8(LibBit.clz(differingBits << 192));
        }
    }

    /// @notice Read one bit from a 64-bit radix key by depth.
    /// @param key Sort or path key.
    /// @param depth Zero-based bit depth, where 0 is the most significant bit.
    /// @return one True if the selected bit is one.
    function _bit(uint64 key, uint8 depth) private pure returns (bool one) {
        /// @solidity memory-safe-assembly
        assembly {
            one := and(shr(sub(63, depth), key), 1)
        }
    }

    /// @notice Return whether a side has optimized right-spine anchors that need materialization before insert.
    /// @param isBid True for the bid tree, false for the ask tree.
    /// @return dirty True if the side's right spine contains stale branch aggregate words.
    function _rightSpineDirty(Book storage book, bool isBid) private view returns (bool dirty) {
        uint256 flag = isBid ? _BID_RIGHT_SPINE_DIRTY : _ASK_RIGHT_SPINE_DIRTY;
        dirty = book.nonceAndFlags & flag != 0;
    }

    /// @notice Mark a side's right spine dirty.
    /// @param isBid True for the bid tree, false for the ask tree.
    function _setRightSpineDirty(Book storage book, bool isBid) private {
        uint256 flag = isBid ? _BID_RIGHT_SPINE_DIRTY : _ASK_RIGHT_SPINE_DIRTY;
        uint256 nonceAndFlags = book.nonceAndFlags;
        if (nonceAndFlags & flag == 0) {
            book.nonceAndFlags = nonceAndFlags | flag;
        }
    }

    /// @notice Return the low 40-bit nonce for a book.
    function _nextNonce(Book storage book) internal view returns (uint40) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint40(book.nonceAndFlags & _NONCE_MASK);
    }

    /// @notice Initialize an empty book.
    function _initializeBook(Book storage book) internal {
        if (_nextNonce(book) != 0) return;
        book.nonceAndFlags = uint256(type(uint40).max);
    }

    /// @notice Build the globally unique owner key for an order in a book.
    function _orderId(bytes32 bookId, bytes32 order) internal pure returns (bytes32 id) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, bookId)
            mstore(add(ptr, 0x20), order)
            id := keccak256(ptr, 0x40)
        }
    }

    /// @notice Compute quote value for a base quantity at a 24-bit integer price.
    /// @param price Integer quote-per-base price.
    /// @param quantity Base quantity.
    /// @return Quote amount.
    /// @dev The product is at most 216 bits, so it cannot overflow `uint256`.
    function _quoteValue(uint24 price, uint192 quantity) internal pure returns (uint256) {
        unchecked {
            return uint256(price) * uint256(quantity);
        }
    }

    /// @notice Decode price and quantity from a packed node.
    /// @param order Packed node.
    /// @return price 24-bit price.
    /// @return quantity 192-bit quantity.
    function _priceAndQuantity(bytes32 order) internal pure returns (uint24 price, uint192 quantity) {
        /// @solidity memory-safe-assembly
        assembly {
            price := shr(_PRICE_SHIFT, order)
            quantity := and(shr(_QUANTITY_SHIFT, order), 0xffffffffffffffffffffffffffffffffffffffffffffffff)
        }
    }

    /// @notice Decode and validate an incoming order before nonce assignment.
    function _validateIncomingOrder(bytes32 order) internal pure returns (uint24 price, uint192 quantity) {
        /// @solidity memory-safe-assembly
        assembly {
            price := shr(_PRICE_SHIFT, order)
            quantity := and(shr(_QUANTITY_SHIFT, order), 0xffffffffffffffffffffffffffffffffffffffffffffffff)
            if or(or(iszero(price), iszero(quantity)), and(order, 0xffffffffff)) {
                mstore(0x00, 0xaf610693) // `InvalidOrder()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Replace the quantity field of a packed order while preserving price and nonce.
    /// @param order Original packed order or leaf.
    /// @param quantity New remaining quantity.
    /// @return updated Packed node with updated quantity.
    /// @dev Used for partial fills. The returned reduced leaf intentionally has no owner mapping;
    /// ownership remains on the original full-quantity order key.
    function _withQuantity(bytes32 order, uint192 quantity) private pure returns (bytes32 updated) {
        /// @solidity memory-safe-assembly
        assembly {
            updated := or(
                and(order, 0xffffff000000000000000000000000000000000000000000000000ffffffffff),
                shl(_QUANTITY_SHIFT, quantity)
            )
        }
    }

    /// @notice Pack price, quantity, and nonce into a node.
    /// @param price 24-bit price.
    /// @param quantity 192-bit quantity.
    /// @param nonce 40-bit nonce or branch path suffix.
    /// @return packed Packed `bytes32` node.
    function _pack(uint24 price, uint192 quantity, uint40 nonce) private pure returns (bytes32 packed) {
        /// @solidity memory-safe-assembly
        assembly {
            packed := or(or(shl(_PRICE_SHIFT, price), shl(_QUANTITY_SHIFT, quantity)), nonce)
        }
    }

    /// @notice Extract the price field from a packed node.
    /// @param order Packed node.
    /// @return price 24-bit price.
    function _price(bytes32 order) private pure returns (uint24 price) {
        /// @solidity memory-safe-assembly
        assembly {
            price := shr(_PRICE_SHIFT, order)
        }
    }

    /// @notice Extract the low 40-bit nonce/path suffix from a packed node.
    /// @param order Packed node.
    /// @return 40-bit nonce or branch path suffix.
    function _nonce(bytes32 order) private pure returns (uint40) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint40(uint256(order));
    }

    /// @notice Mark packed match metadata as having retained a dirty right-spine anchor.
    function _markMatchDirty(bytes32 change) private pure returns (bytes32) {
        return bytes32(uint256(change) | _MATCH_CHANGE_DIRTY);
    }

    /// @notice Return whether packed match metadata indicates a dirty right-spine anchor changed.
    function _matchChangeDirty(bytes32 change) private pure returns (bool) {
        return uint256(change) & _MATCH_CHANGE_DIRTY != 0;
    }

    /// @notice Extract the quantity field from a packed node.
    /// @param order Packed node.
    /// @return 192-bit quantity.
    function _quantity(bytes32 order) private pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192((uint256(order) >> _QUANTITY_SHIFT) & _QUANTITY_MASK);
    }
}
