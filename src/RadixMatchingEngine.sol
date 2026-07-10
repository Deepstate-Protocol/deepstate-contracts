// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LibBit} from "solady/utils/LibBit.sol";
import {TickMath32} from "./libraries/TickMath32.sol";

/// @title Radix Matching Engine
/// @notice Fully on-chain limit-order matching engine backed by two radix trees in one mapping.
/// @dev
/// Orders and aggregate branches are both represented by a single `bytes32` node word:
///
/// - bits 224-255: signed 32-bit logarithmic tick.
/// - bits  64-223: 160-bit quantity.
/// - bits  32-63: 32-bit same-tick branch correction code; zero for leaves/mixed branches.
/// - bits   0-31: 32-bit nonce/path suffix.
///
/// Tick `t` represents the dimensionless quote/base price `2 ** (128 * t / 2**31)`.
/// Tick zero is therefore exactly 1:1, the full signed domain spans approximately
/// `[2**-128, 2**128)`, and adjacent ticks differ by about 0.000413148 basis points.
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
/// Right-spine optimization: fills and cancels near the best price often mutate only the rightmost
/// path. In those cases the engine may keep a stable branch address and update only its right child
/// pointer. The branch word can then have a stale aggregate quantity/path, so the corresponding
/// book flag is set. Same-side insertion materializes the right spine back into exact aggregate
/// nodes before adding a new leaf. Matching can still safely consume same-price dirty subtrees by
/// recomputing their live quantity from child pointers.
///
/// Hook integration is deliberately thin. The core matcher records top-of-book changes in two
/// transient slots: outgoing live amount and incoming nonce. The routing layer supplies pool, book,
/// token, and hook address context after the core mutation returns. This keeps the tree logic
/// book-local while allowing optional top-buyer reward hooks at the outer layer.
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
    /// @dev The low 32 bits of `nonceAndFlags` are the decrementing nonce. Bits above the nonce
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

    /// @dev Bit offset of the signed 32-bit tick field in a packed node.
    uint256 private constant _PRICE_SHIFT = 224;
    /// @dev Bit offset of the 160-bit quantity field in a packed node.
    uint256 private constant _QUANTITY_SHIFT = 64;
    /// @dev Bit offset of the 32-bit same-tick correction code in a packed node.
    uint256 private constant _CORRECTION_SHIFT = 32;
    /// @dev Mask for extracting the 160-bit quantity after shifting right by `_QUANTITY_SHIFT`.
    uint256 private constant _QUANTITY_MASK = (uint256(1) << 160) - 1;
    /// @dev Mask for extracting the 32-bit same-tick correction code.
    uint256 private constant _CORRECTION_MASK = type(uint32).max;
    /// @dev Mask for extracting or validating the 32-bit nonce/path suffix.
    uint256 private constant _NONCE_MASK = type(uint32).max;
    /// @dev Mask that keeps the raw tick and nonce while clearing quantity and correction metadata.
    uint256 private constant _PATH_MASK = (type(uint256).max << _PRICE_SHIFT) | _NONCE_MASK;
    /// @dev Sign-bit bias that maps signed ticks into monotonically increasing unsigned keys.
    uint256 private constant _TICK_BIAS = uint256(1) << 31;
    /// @dev Root anchor in every book's tree. `leftNode` is ask root; `rightNode` is bid root.
    bytes32 private constant _ROOT_NODE = bytes32(0);
    /// @dev Dirty bit stored above the 32-bit `nextNonce` field when bid right-spine anchors are stale.
    uint256 private constant _BID_RIGHT_SPINE_DIRTY = uint256(1) << 32;
    /// @dev Dirty bit stored above the 32-bit `nextNonce` field when ask right-spine anchors are stale.
    uint256 private constant _ASK_RIGHT_SPINE_DIRTY = uint256(1) << 33;
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
    event AskMatched(bytes32 bookId, bytes32 restingNode, uint160 quantity, uint256 quoteAmount);

    /// @notice Matched resting bid liquidity.
    /// @param bookId Book that supplied the resting bid.
    /// @param restingNode Bid leaf or same-price bid aggregate branch consumed by the incoming ask.
    /// @param quantity Base quantity matched from the resting bid liquidity.
    /// @param quoteAmount Quote value paid at the resting bid price.
    event BidMatched(bytes32 bookId, bytes32 restingNode, uint160 quantity, uint256 quoteAmount);

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
    /// @notice The decrementing 32-bit nonce space has been exhausted.
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
    /// @notice Same-tick rounding correction exceeded its 32-bit packed field.
    error CorrectionOverflow();

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
    /// @param hookEnabled True when changes to the resting side's top order should be recorded.
    /// @return limitPrice Incoming limit price.
    /// @return remaining Incoming base quantity left unmatched.
    /// @return baseFilled Base quantity matched.
    /// @return quoteAmount Quote value matched.
    function _matchBook(bytes32 bookId, Book storage book, bytes32 order, bool isBid, bool hookEnabled)
        internal
        returns (int32 limitPrice, uint160 remaining, uint160 baseFilled, uint256 quoteAmount)
    {
        (limitPrice, remaining) = _validateIncomingOrder(order);

        if (isBid) {
            (remaining, baseFilled, quoteAmount) = _matchIncomingBid(bookId, book, limitPrice, remaining, hookEnabled);
        } else {
            (remaining, baseFilled, quoteAmount) = _matchIncomingAsk(bookId, book, limitPrice, remaining, hookEnabled);
        }
    }

    /// @notice Match an incoming bid against the ask root.
    /// @param bookId Book id whose ask tree is being consumed.
    /// @param book Book storage selected by `bookId`.
    /// @param limitPrice Highest ask price the bid will accept.
    /// @param remaining Incoming bid quantity before matching.
    /// @param hookEnabled True to record top-ask changes for the routing hook.
    /// @return newRemaining Bid quantity left unmatched.
    /// @return baseFilled Base quantity bought.
    /// @return quoteAmount Quote paid at resting ask prices.
    /// @dev The ask root lives in `tree[0].leftNode`.
    function _matchIncomingBid(bytes32 bookId, Book storage book, int32 limitPrice, uint160 remaining, bool hookEnabled)
        private
        returns (uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
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

    /// @notice Match an incoming ask against the bid root.
    /// @param bookId Book id whose bid tree is being consumed.
    /// @param book Book storage selected by `bookId`.
    /// @param limitPrice Lowest bid price the ask will accept.
    /// @param remaining Incoming ask quantity before matching.
    /// @param hookEnabled True to record top-bid changes for the routing hook.
    /// @return newRemaining Ask quantity left unmatched.
    /// @return baseFilled Base quantity sold.
    /// @return quoteAmount Quote received at resting bid prices.
    /// @dev The bid root lives in `tree[0].rightNode`.
    function _matchIncomingAsk(bytes32 bookId, Book storage book, int32 limitPrice, uint160 remaining, bool hookEnabled)
        private
        returns (uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
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
    /// @param bookId Book id that scopes the original order.
    /// @param book Book storage selected by `bookId`.
    /// @param order Original packed resting order returned by `fill`.
    /// @param caller Account requesting cancel/claim.
    /// @param hookFlags Compact side flags indicating whether cancel should record top changes.
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

        uint160 originalQuantity = _quantity(order);
        if (originalQuantity == 0) revert InvalidOrder();
        isBid = state.isBid;
        bool hookEnabled = hookFlags & (isBid ? _CANCEL_HOOK_BID : _CANCEL_HOOK_ASK) != 0;

        bytes32 removed = _removeOrderFromBook(book, order, isBid, hookEnabled);

        (baseAmount, quoteAmount) = _cancelAmounts(order, removed, isBid, originalQuantity);

        delete orderOf[orderKey];

        emit OrderCancelled(bookId, order, owner, baseAmount, quoteAmount);
    }

    /// @notice Compute maker payout amounts after cancel/claim tree removal.
    /// @param order Original full-quantity order node.
    /// @param removed Live leaf removed from the tree, or zero if already fully filled.
    /// @param isBid True if the original order was a bid.
    /// @param originalQuantity Quantity encoded in the original order.
    /// @return baseAmount Base tokens owed to the maker.
    /// @return quoteAmount Quote tokens owed to the maker.
    /// @dev
    /// For bids, filled quantity pays base and unfilled quantity returns quote collateral. For asks,
    /// unfilled quantity returns base and filled quantity pays quote. A removed live leaf may have a
    /// smaller quantity than the original order because partial fills rewrite the leaf quantity.
    function _cancelAmounts(bytes32 order, bytes32 removed, bool isBid, uint160 originalQuantity)
        private
        pure
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        uint160 remainingQuantity = 0;
        if (removed != bytes32(0)) {
            remainingQuantity = _quantity(removed);
        }
        if (remainingQuantity > originalQuantity) revert InvalidOrder();
        uint160 filledQuantity;
        unchecked {
            filledQuantity = originalQuantity - remainingQuantity;
        }
        int32 limitPrice = _price(order);
        if (isBid) {
            baseAmount = filledQuantity;
            quoteAmount = _quoteValue(limitPrice, remainingQuantity, true);
        } else {
            baseAmount = remainingQuantity;
            quoteAmount = _quoteDifference(limitPrice, originalQuantity, remainingQuantity, false);
        }
    }

    /// @notice Remove the live leaf for an original order from the appropriate side of a book.
    /// @param book Book storage containing both bid and ask trees.
    /// @param order Original order node whose price/nonce identifies the live leaf.
    /// @param isBid True to remove from the bid tree, false from the ask tree.
    /// @param hookEnabled True to record a top-order change when the removed leaf was best.
    /// @return removed Live leaf removed from the tree, or zero if the order was already absent.
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
    /// @param hookEnabled True to record a top-order change if the new order becomes best.
    /// @return restingOrder Packed resting order with assigned nonce.
    /// @return nextNonceAfter The book nonce after assigning `restingOrder`.
    /// @dev
    /// Right-spine dirty flags are materialized before insertion on the same side. This preserves
    /// exact branch quantities for the insertion path while allowing earlier best-price fills to
    /// avoid rewriting ancestors.
    function _restBook(
        bytes32 bookId,
        Book storage book,
        uint256 nonceAndFlags,
        int32 price,
        uint160 quantity,
        bool isBid,
        address owner,
        bool hookEnabled
    ) internal returns (bytes32 restingOrder, uint32 nextNonceAfter) {
        uint256 dirtyFlag = isBid ? _BID_RIGHT_SPINE_DIRTY : _ASK_RIGHT_SPINE_DIRTY;
        if (nonceAndFlags & dirtyFlag != 0) {
            if (isBid) {
                book.tree[_ROOT_NODE].rightNode = _materializeRightSpine(book, book.tree[_ROOT_NODE].rightNode, true);
            } else {
                book.tree[_ROOT_NODE].leftNode = _materializeRightSpine(book, book.tree[_ROOT_NODE].leftNode, false);
            }
            nonceAndFlags &= ~dirtyFlag;
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 nonce = uint32(nonceAndFlags & _NONCE_MASK);
        if (nonce <= 1) revert NonceExhausted();
        unchecked {
            nextNonceAfter = nonce - 1;
        }
        unchecked {
            book.nonceAndFlags = (nonceAndFlags & ~_NONCE_MASK) | uint256(nextNonceAfter);
        }

        restingOrder = _pack(price, quantity, nonce);
        orderOf[_orderId(bookId, restingOrder)] = OrderState({owner: owner, isBid: isBid});

        _insertRestingOrder(book, restingOrder, isBid, hookEnabled);

        emit OrderRested(bookId, restingOrder, owner, isBid);
    }

    /// @notice Insert an already nonce-assigned resting order into the selected side tree.
    /// @param book Book storage containing both side roots.
    /// @param restingOrder Packed leaf to insert.
    /// @param isBid True for bid tree, false for ask tree.
    /// @param hookEnabled True to record a top-order change if insertion improves the book.
    function _insertRestingOrder(Book storage book, bytes32 restingOrder, bool isBid, bool hookEnabled) private {
        if (isBid) {
            bytes32 root = book.tree[_ROOT_NODE].rightNode;
            book.tree[_ROOT_NODE].rightNode =
                _insertBid(book, root, restingOrder, _bidSortKey(restingOrder), hookEnabled);
        } else {
            bytes32 root = book.tree[_ROOT_NODE].leftNode;
            book.tree[_ROOT_NODE].leftNode =
                _insertAsk(book, root, restingOrder, _askSortKey(restingOrder), hookEnabled);
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
    function _matchAskLeaf(bytes32 bookId, bytes32 root, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newRoot, uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
        (int32 restingPrice, uint160 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice > limitPrice) return (root, remaining, 0, 0);

        uint160 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteDifference(restingPrice, restingQuantity, restingQuantity - fillQuantity, false);

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
    function _matchBidLeaf(bytes32 bookId, bytes32 root, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newRoot, uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
        (int32 restingPrice, uint160 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice < limitPrice) return (root, remaining, 0, 0);

        uint160 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteDifference(restingPrice, restingQuantity, restingQuantity - fillQuantity, true);

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

    /// @notice Emit an ask match event from the right-spine matcher.
    /// @dev
    /// Dirty branch words may have stale quantity fields. For aggregate same-price fills, the event
    /// node is rewritten with the actual fill quantity so offchain consumers see the consumed
    /// amount even when the stored branch anchor was intentionally stale.
    function _emitAskRightSpineMatch(
        bytes32 bookId,
        bytes32 node,
        uint160 fillQuantity,
        uint256 quoteAmount,
        uint256 matchFlags
    ) private {
        emit AskMatched(
            bookId, matchFlags & _MATCH_DIRTY != 0 ? _withQuantity(node, fillQuantity) : node, fillQuantity, quoteAmount
        );
    }

    /// @notice Emit a bid match event from the right-spine matcher.
    /// @dev Mirrors `_emitAskRightSpineMatch` for bid-side same-price aggregate fills.
    function _emitBidRightSpineMatch(
        bytes32 bookId,
        bytes32 node,
        uint160 fillQuantity,
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
    /// @return matchChange Packed metadata for whether optimized right-spine anchors were retained.
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
        int32 limitPrice,
        uint160 remaining,
        uint256 matchFlags
    ) private returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount, bytes32 matchChange) {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(bookId, node, limitPrice, remaining);
            if (matchFlags & _MATCH_HOOK != 0 && fillQuantity != 0) {
                _recordTopOrderChange(_quantity(node), newNode == bytes32(0) ? 0 : _nonce(newNode));
            }
            return (newNode, fillQuantity, quoteAmount, matchChange);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            if (_price(leftNode) == _price(rightNode)) {
                uint160 outgoingTopQuantity;
                (fillQuantity, quoteAmount, outgoingTopQuantity) =
                    _samePriceRightSpineFillQuantity(book, node, limitPrice, remaining, matchFlags);
                if (fillQuantity != 0) {
                    if (matchFlags & _MATCH_HOOK != 0) {
                        _recordTopOrderChange(outgoingTopQuantity, 0);
                    }
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
            (newNode, branchDirty) = _replaceRightmostRightChild(book, node, newLeftNode, newRightNode, false);
            if (branchDirty) matchChange = _markMatchDirty(matchChange);
        } else {
            newNode = _replaceBranch(book, newLeftNode, newRightNode, false);
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
    /// @dev
    /// Off-spine subtrees are exact because the right-spine optimization only preserves stale
    /// anchors along the global best path. This lets the function aggregate-consume mixed-price
    /// branches when the worst leaf still crosses and the whole quantity fits.
    function _matchAskSubtree(bytes32 bookId, Book storage book, bytes32 node, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(bookId, node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        uint160 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(book, node) <= limitPrice) {
            quoteAmount = _consumeSubtree(bookId, book, node, false);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
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

        newNode = _replaceBranch(book, newLeftNode, newRightNode, false);
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
    /// @return matchChange Packed metadata for whether optimized right-spine anchors were retained.
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
        int32 limitPrice,
        uint160 remaining,
        uint256 matchFlags
    ) private returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount, bytes32 matchChange) {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(bookId, node, limitPrice, remaining);
            if (matchFlags & _MATCH_HOOK != 0 && fillQuantity != 0) {
                _recordTopOrderChange(_quantity(node), newNode == bytes32(0) ? 0 : _nonce(newNode));
            }
            return (newNode, fillQuantity, quoteAmount, matchChange);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            if (_price(leftNode) == _price(rightNode)) {
                uint160 outgoingTopQuantity;
                (fillQuantity, quoteAmount, outgoingTopQuantity) = _samePriceRightSpineFillQuantity(
                    book, node, limitPrice, remaining, matchFlags | _MATCH_RESTING_BID
                );
                if (fillQuantity != 0) {
                    if (matchFlags & _MATCH_HOOK != 0) {
                        _recordTopOrderChange(outgoingTopQuantity, 0);
                    }
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
            (newNode, branchDirty) = _replaceRightmostRightChild(book, node, newLeftNode, newRightNode, true);
            if (branchDirty) matchChange = _markMatchDirty(matchChange);
        } else {
            newNode = _replaceBranch(book, newLeftNode, newRightNode, true);
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
    /// @dev
    /// Off-spine bid subtrees are exact for the same reason as ask subtrees. If the subtree's
    /// lowest bid price still crosses the ask limit and quantity fits, the whole branch can be
    /// consumed without walking every leaf.
    function _matchBidSubtree(bytes32 bookId, Book storage book, bytes32 node, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(bookId, node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        uint160 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(book, node) >= limitPrice) {
            quoteAmount = _consumeSubtree(bookId, book, node, true);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
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

        newNode = _replaceBranch(book, newLeftNode, newRightNode, true);
        unchecked {
            fillQuantity += rightFillQuantity;
            quoteAmount += rightQuoteAmount;
        }
    }

    /// @notice Insert a leaf or branch into the bid tree.
    /// @param root Current subtree root.
    /// @param node Node to insert.
    /// @param nodeKey Bid sort key for `node`.
    /// @param hookEnabled True while this recursive frame can still affect the bid-side best order.
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
            return _storeBranch(book, root, node, _bidSortKey(root), nodeKey, true);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _bidSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _bidSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            if (hookEnabled && _bit(nodeKey, _commonPrefix(nodeKey, leftKey))) {
                _recordTopOrderChange(_quantity(_rightmostLeaf(book, root)), _nonce(node));
            }
            return _storeBranch(book, root, node, _bidSortKey(root), nodeKey, true);
        }

        if (_bit(nodeKey, branchDepth)) {
            rightNode = _insertBid(book, rightNode, node, nodeKey, hookEnabled);
        } else {
            leftNode = _insertBid(book, leftNode, node, nodeKey, false);
        }

        return _replaceBranch(book, leftNode, rightNode, true);
    }

    /// @notice Insert a leaf or branch into the ask tree.
    /// @param root Current subtree root.
    /// @param node Node to insert.
    /// @param nodeKey Ask sort key for `node`.
    /// @param hookEnabled True while this recursive frame can still affect the ask-side best order.
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
            return _storeBranch(book, root, node, _askSortKey(root), nodeKey, false);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _askSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _askSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            if (hookEnabled && _bit(nodeKey, _commonPrefix(nodeKey, leftKey))) {
                _recordTopOrderChange(_quantity(_rightmostLeaf(book, root)), _nonce(node));
            }
            return _storeBranch(book, root, node, _askSortKey(root), nodeKey, false);
        }

        if (_bit(nodeKey, branchDepth)) {
            rightNode = _insertAsk(book, rightNode, node, nodeKey, hookEnabled);
        } else {
            leftNode = _insertAsk(book, leftNode, node, nodeKey, false);
        }

        return _replaceBranch(book, leftNode, rightNode, false);
    }

    /// @notice Remove one bid leaf by exact bid sort key.
    /// @param root Current subtree root.
    /// @param targetKey Bid sort key for the original order.
    /// @param rightmost True if this frame is still on the bid-side best path.
    /// @return newRoot Updated subtree root.
    /// @return removed Live leaf that was removed, or zero if absent.
    /// @return dirtyChanged True if a right-spine anchor was retained with a changed right child.
    /// @return removedTop True if the removed leaf was the top bid.
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
            (newRoot, branchDirty) = _replaceRightmostRightChild(book, root, leftNode, rightNode, true);
            return (newRoot, removed, dirtyChanged || branchDirty, removedTop);
        }
        return (_replaceBranch(book, leftNode, rightNode, true), removed, dirtyChanged, removedTop);
    }

    /// @notice Remove one ask leaf by exact ask sort key.
    /// @param root Current subtree root.
    /// @param targetKey Ask sort key for the original order.
    /// @param rightmost True if this frame is still on the ask-side best path.
    /// @return newRoot Updated subtree root.
    /// @return removed Live leaf that was removed, or zero if absent.
    /// @return dirtyChanged True if a right-spine anchor was retained with a changed right child.
    /// @return removedTop True if the removed leaf was the top ask.
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
            (newRoot, branchDirty) = _replaceRightmostRightChild(book, root, leftNode, rightNode, false);
            return (newRoot, removed, dirtyChanged || branchDirty, removedTop);
        }
        return (_replaceBranch(book, leftNode, rightNode, false), removed, dirtyChanged, removedTop);
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
    function _replaceRightmostRightChild(
        Book storage book,
        bytes32 branchNode,
        bytes32 leftNode,
        bytes32 rightNode,
        bool isBid
    ) private returns (bytes32 newNode, bool dirtyChanged) {
        if (rightNode == bytes32(0)) return (leftNode, false);
        if (rightNode == branchNode || rightNode == leftNode) {
            return (_replaceBranch(book, leftNode, rightNode, isBid), false);
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
    function _replaceBranch(Book storage book, bytes32 leftNode, bytes32 rightNode, bool isBid)
        private
        returns (bytes32)
    {
        bytes32 newBranch;
        if (leftNode == bytes32(0)) {
            newBranch = rightNode;
        } else if (rightNode == bytes32(0)) {
            newBranch = leftNode;
        } else {
            newBranch = _branchNodeForChildren(book, leftNode, rightNode, isBid);
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
    function _materializeRightSpine(Book storage book, bytes32 node, bool isBid) private returns (bytes32) {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) return node;

        bytes32 rightNode = _materializeRightSpine(book, book.tree[node].rightNode, isBid);
        return _replaceBranch(book, leftNode, rightNode, isBid);
    }

    /// @notice Return the aggregate quantity for a fully crossing same-price subtree on the global right spine.
    /// @param node Right-spine branch to inspect.
    /// @param limitPrice Incoming order limit price.
    /// @param remaining Incoming base quantity available.
    /// @param matchFlags Internal matcher flags for resting side and dirty right-spine state.
    /// @return fillQuantity Actual base quantity consumable as one same-price aggregate, or zero.
    /// @dev
    /// Dirty right-spine anchors keep correct child pointers but stale packed aggregate fields. For
    /// same-tick subtrees this helper recovers the exact sum of leaf-rounded notionals from child
    /// correction codes, preserving the one-event aggregate path without rewriting every ancestor.
    /// Mixed-tick dirty subtrees intentionally fall back to the recursive matcher because one tick
    /// and one correction cannot represent their quote value.
    function _samePriceRightSpineFillQuantity(
        Book storage book,
        bytes32 node,
        int32 limitPrice,
        uint160 remaining,
        uint256 matchFlags
    ) private view returns (uint160 fillQuantity, uint256 quoteAmount, uint160 outgoingTopQuantity) {
        bool isBid = matchFlags & _MATCH_RESTING_BID != 0;
        int32 price;
        bool uniform;
        if (matchFlags & _MATCH_DIRTY != 0) {
            (uniform, price, fillQuantity, quoteAmount, outgoingTopQuantity) = _dirtyRightSpineData(book, node, isBid);
        } else {
            uniform = _correctionCode(node) != 0;
            price = _price(node);
            fillQuantity = _quantity(node);
            quoteAmount = uniform ? _uniformNodeQuote(book, node, isBid) : 0;
            outgoingTopQuantity = _quantity(_rightmostLeaf(book, node));
        }
        if (!uniform) return (0, 0, 0);
        if (matchFlags & _MATCH_RESTING_BID != 0 ? price < limitPrice : price > limitPrice) return (0, 0, 0);
        if (fillQuantity > remaining) return (0, 0, 0);
    }

    /// @notice Recover exact same-tick quantity and quote value from a stale global right spine.
    /// @dev Only right children can themselves be stale. Every left child is an exact off-spine
    /// subtree, so its packed correction gives its exact rounded quote value in O(1). Recursing
    /// solely through right children keeps recovery bounded by the 64-bit radix depth.
    function _dirtyRightSpineData(Book storage book, bytes32 node, bool isBid)
        private
        view
        returns (bool uniform, int32 tick, uint160 quantity, uint256 quoteAmount, uint160 rightmostQuantity)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            quantity = _quantity(node);
            return (true, _price(node), quantity, _quoteValue(_price(node), quantity, isBid), quantity);
        }

        bytes32 rightNode = book.tree[node].rightNode;
        bool leftUniform = book.tree[leftNode].leftNode == bytes32(0) || _correctionCode(leftNode) != 0;
        if (!leftUniform) return (false, 0, 0, 0, 0);

        (bool rightUniform, int32 rightTick, uint160 rightQuantity, uint256 rightQuote, uint160 topQuantity) =
            _dirtyRightSpineData(book, rightNode, isBid);
        if (!rightUniform || _price(leftNode) != rightTick) return (false, 0, 0, 0, 0);

        tick = rightTick;
        quantity = _quantity(leftNode) + rightQuantity;
        quoteAmount = _uniformNodeQuote(book, leftNode, isBid) + rightQuote;
        rightmostQuantity = topQuantity;
        uniform = true;
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
    function _storeBranch(Book storage book, bytes32 a, bytes32 b, uint64 aKey, uint64 bKey, bool isBid)
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

        branchNode = _branchNodeForChildren(book, a, b, isBid);
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
    function _branchNodeForChildren(Book storage book, bytes32 a, bytes32 b, bool isBid)
        private
        view
        returns (bytes32)
    {
        uint64 aAddressKey = _pathKey(a);
        uint64 bAddressKey = _pathKey(b);
        uint64 boundaryKey = aAddressKey > bAddressKey ? aAddressKey : bAddressKey;
        uint160 quantity = _quantity(a) + _quantity(b);
        uint32 correctionCode;

        if (_price(a) == _price(b) && _uniformNode(book, a) && _uniformNode(book, b)) {
            int32 tick = _price(a);
            (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
            uint256 childQuote = _uniformNodeQuoteAtFactor(book, a, isBid, factor, shift)
                + _uniformNodeQuoteAtFactor(book, b, isBid, factor, shift);
            uint256 aggregateQuote = _quoteAtFactor(factor, shift, quantity, isBid);
            uint256 correction = isBid ? childQuote - aggregateQuote : aggregateQuote - childQuote;
            if (correction >= type(uint32).max) revert CorrectionOverflow();
            correctionCode = uint32(correction + 1);
        }

        return _branchNode(boundaryKey, quantity, correctionCode);
    }

    /// @notice Pack a branch node from a raw path key and aggregate quantity.
    /// @param key Raw `price || nonce` path key used as the branch address suffix.
    /// @param quantity Aggregate quantity represented by the branch.
    /// @return node Packed branch node.
    function _branchNode(uint64 key, uint160 quantity, uint32 correctionCode) private pure returns (bytes32 node) {
        /// @solidity memory-safe-assembly
        assembly {
            let rawTick := xor(shr(32, key), 0x80000000)
            node := or(
                or(shl(_PRICE_SHIFT, rawTick), shl(_QUANTITY_SHIFT, quantity)),
                or(shl(_CORRECTION_SHIFT, correctionCode), and(key, 0xffffffff))
            )
        }
    }

    /// @notice Return whether a node represents one tick exactly.
    function _uniformNode(Book storage book, bytes32 node) private view returns (bool) {
        return book.tree[node].leftNode == bytes32(0) || _correctionCode(node) != 0;
    }

    /// @notice Return the exact sum of leaf-level rounded notionals for a uniform-tick node.
    function _uniformNodeQuote(Book storage book, bytes32 node, bool isBid) private view returns (uint256 quoteAmount) {
        uint160 quantity = _quantity(node);
        quoteAmount = _quoteValue(_price(node), quantity, isBid);
        if (book.tree[node].leftNode == bytes32(0)) return quoteAmount;

        uint256 correction = uint256(_correctionCode(node)) - 1;
        quoteAmount = isBid ? quoteAmount + correction : quoteAmount - correction;
    }

    /// @dev Uniform-node quote using a price factor already decoded for the node's tick.
    function _uniformNodeQuoteAtFactor(Book storage book, bytes32 node, bool isBid, uint256 factor, uint16 shift)
        private
        view
        returns (uint256 quoteAmount)
    {
        quoteAmount = _quoteAtFactor(factor, shift, _quantity(node), isBid);
        if (book.tree[node].leftNode == bytes32(0)) return quoteAmount;

        uint256 correction = uint256(_correctionCode(node)) - 1;
        quoteAmount = isBid ? quoteAmount + correction : quoteAmount - correction;
    }

    /// @notice Return the price of the leftmost leaf in a subtree.
    /// @param node Subtree root.
    /// @return price Price of the worst executable leaf in the subtree.
    /// @dev
    /// For bids, the leftmost leaf has the lowest bid price. For asks, the leftmost leaf has the
    /// highest ask price because ask sort keys invert price. In both cases this is the "worst"
    /// price that must cross before an entire subtree can be aggregate-consumed.
    function _leftmostLeafPrice(Book storage book, bytes32 node) private view returns (int32 price) {
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
        uint160 outgoingAmount;
        uint32 incomingNonce;
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
    function _replacementTopNonce(Book storage book, bytes32 newNode) private view returns (uint32) {
        if (newNode == bytes32(0)) return 0;
        if (book.tree[newNode].leftNode == bytes32(0)) return _nonce(newNode);
        return _nonce(_rightmostLeaf(book, newNode));
    }

    /// @notice Record one top-order change in transient storage for the router to consume.
    /// @dev Either slot being nonzero is the signal that a hook should be considered. First rest
    /// writes only `incomingNonce`; an emptied side writes only `outgoingAmount`.
    function _recordTopOrderChange(uint160 outgoingAmount, uint32 incomingNonce) private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_TOP_CHANGE_OUTGOING_AMOUNT_SLOT, outgoingAmount)
            tstore(_TOP_CHANGE_INCOMING_NONCE_SLOT, incomingNonce)
        }
    }

    /// @notice Consume and clear the latest recorded top-order change.
    /// @return outgoingAmount Previous top order's live amount in the rewarded token.
    /// @return incomingNonce New top order nonce, or zero if the side is empty/unknown.
    function _takeTopOrderChange() internal returns (uint160 outgoingAmount, uint32 incomingNonce) {
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
        uint160 quantity = _quantity(node);
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            quoteAmount = _quoteValue(_price(node), quantity, restingIsBid);
            if (restingIsBid) {
                emit BidMatched(bookId, node, quantity, quoteAmount);
            } else {
                emit AskMatched(bookId, node, quantity, quoteAmount);
            }
            return quoteAmount;
        }

        if (_correctionCode(node) != 0) {
            quoteAmount = _uniformNodeQuote(book, node, restingIsBid);
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
            let tickKey := xor(and(shr(_PRICE_SHIFT, order), 0xffffffff), 0x80000000)
            key := or(shl(32, tickKey), and(order, 0xffffffff))
        }
    }

    /// @notice Build the ask sort key from an order or branch node.
    /// @param order Packed node.
    /// @return key Ask sort key: `(maxPrice - price) || nonce`.
    /// @dev Higher keys are better asks: lower price first after inversion, then higher nonce for earlier time.
    function _askSortKey(bytes32 order) private pure returns (uint64 key) {
        /// @solidity memory-safe-assembly
        assembly {
            let tickKey := xor(and(shr(_PRICE_SHIFT, order), 0xffffffff), 0x80000000)
            key := or(shl(32, sub(0xffffffff, tickKey)), and(order, 0xffffffff))
        }
    }

    /// @notice Build the raw address path key from a node.
    /// @param order Packed node.
    /// @return key Raw `price || nonce` key, ignoring quantity.
    /// @dev Branch addresses use raw path keys for both sides of the book.
    function _pathKey(bytes32 order) private pure returns (uint64 key) {
        /// @solidity memory-safe-assembly
        assembly {
            let tickKey := xor(and(shr(_PRICE_SHIFT, order), 0xffffffff), 0x80000000)
            key := or(shl(32, tickKey), and(order, 0xffffffff))
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

    /// @notice Return the low 32-bit nonce for a book.
    /// @param book Book storage to inspect.
    /// @return Next decrementing nonce, or zero if the book is uninitialized.
    function _nextNonce(Book storage book) internal view returns (uint32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint32(book.nonceAndFlags & _NONCE_MASK);
    }

    /// @notice Initialize an empty book.
    /// @param book Book storage to initialize.
    /// @dev No-op if the book already has a nonce. New books start at `type(uint32).max`.
    function _initializeBook(Book storage book) internal {
        if (_nextNonce(book) != 0) return;
        book.nonceAndFlags = uint256(type(uint32).max);
    }

    /// @notice Build the globally unique owner key for an order in a book.
    /// @param bookId Book id that scopes the order.
    /// @param order Original packed order node.
    /// @return id `keccak256(bookId, order)`.
    function _orderId(bytes32 bookId, bytes32 order) internal pure returns (bytes32 id) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, bookId)
            mstore(add(ptr, 0x20), order)
            id := keccak256(ptr, 0x40)
        }
    }

    /// @notice Compute quote value for a base quantity at a signed logarithmic tick.
    /// @param price Signed logarithmic price tick.
    /// @param quantity Base quantity.
    /// @param roundUp True for bid collateral, false for ask proceeds.
    /// @return quoteAmount Quote amount.
    /// @dev Bid notionals round upward and ask notionals round downward. Partial-fill settlement
    /// uses differences between old and new notionals, so repeated fills telescope exactly.
    function _quoteValue(int32 price, uint160 quantity, bool roundUp) internal pure returns (uint256 quoteAmount) {
        if (quantity == 0) return 0;
        if (price == 0) return quantity;
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(price);
        return _quoteAtFactor(factor, shift, quantity, roundUp);
    }

    /// @dev Difference between two same-tick notionals while decoding the tick only once.
    function _quoteDifference(int32 price, uint160 largerQuantity, uint160 smallerQuantity, bool roundUp)
        private
        pure
        returns (uint256 quoteAmount)
    {
        if (price == 0) return largerQuantity - smallerQuantity;
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(price);
        unchecked {
            quoteAmount = _quoteAtFactor(factor, shift, largerQuantity, roundUp)
                - _quoteAtFactor(factor, shift, smallerQuantity, roundUp);
        }
    }

    /// @dev Multiply quantity by a Q128 fractional price factor and fold in its binary exponent.
    function _quoteAtFactor(uint256 factor, uint16 shift, uint160 quantity, bool roundUp)
        private
        pure
        returns (uint256 quoteAmount)
    {
        if (quantity == 0) return 0;
        /// @solidity memory-safe-assembly
        assembly {
            let productLow := mul(quantity, factor)
            let mm := mulmod(quantity, factor, not(0))
            let productHigh := sub(mm, add(productLow, lt(mm, productLow)))
            let remainder := 0

            switch shift
            case 0 {
                if productHigh {
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }
                quoteAmount := productLow
            }
            case 256 {
                quoteAmount := productHigh
                remainder := productLow
            }
            default {
                if shr(shift, productHigh) {
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }
                quoteAmount := or(shl(sub(256, shift), productHigh), shr(shift, productLow))
                remainder := and(productLow, sub(shl(shift, 1), 1))
            }

            if and(roundUp, iszero(iszero(remainder))) {
                quoteAmount := add(quoteAmount, 1)
                if iszero(quoteAmount) {
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @notice Decode price and quantity from a packed node.
    /// @param order Packed node.
    /// @return price Signed 32-bit logarithmic tick.
    /// @return quantity 160-bit base quantity.
    function _priceAndQuantity(bytes32 order) internal pure returns (int32 price, uint160 quantity) {
        /// @solidity memory-safe-assembly
        assembly {
            price := signextend(3, shr(_PRICE_SHIFT, order))
            quantity := and(shr(_QUANTITY_SHIFT, order), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    /// @notice Decode and validate an incoming order before nonce assignment.
    /// @param order Packed incoming order.
    /// @return price Signed 32-bit logarithmic limit tick; zero is the valid 1:1 tick.
    /// @return quantity Nonzero 160-bit base quantity.
    /// @dev Incoming orders must have zero correction and nonce bits; the engine assigns a nonce
    /// only if unmatched quantity rests.
    function _validateIncomingOrder(bytes32 order) internal pure returns (int32 price, uint160 quantity) {
        /// @solidity memory-safe-assembly
        assembly {
            price := signextend(3, shr(_PRICE_SHIFT, order))
            quantity := and(shr(_QUANTITY_SHIFT, order), 0xffffffffffffffffffffffffffffffffffffffff)
            if or(iszero(quantity), and(order, 0xffffffffffffffff)) {
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
    function _withQuantity(bytes32 order, uint160 quantity) private pure returns (bytes32 updated) {
        /// @solidity memory-safe-assembly
        assembly {
            updated := or(
                and(order, not(shl(_QUANTITY_SHIFT, 0xffffffffffffffffffffffffffffffffffffffff))),
                shl(_QUANTITY_SHIFT, quantity)
            )
        }
    }

    /// @notice Pack price, quantity, and nonce into a node.
    /// @param price Signed 32-bit logarithmic tick.
    /// @param quantity 160-bit base quantity.
    /// @param nonce 32-bit nonce or branch path suffix.
    /// @return packed Packed `bytes32` node.
    function _pack(int32 price, uint160 quantity, uint32 nonce) private pure returns (bytes32 packed) {
        /// @solidity memory-safe-assembly
        assembly {
            packed := or(or(shl(_PRICE_SHIFT, and(price, 0xffffffff)), shl(_QUANTITY_SHIFT, quantity)), nonce)
        }
    }

    /// @notice Extract the price field from a packed node.
    /// @param order Packed node.
    /// @return price Signed 32-bit logarithmic tick.
    function _price(bytes32 order) private pure returns (int32 price) {
        /// @solidity memory-safe-assembly
        assembly {
            price := signextend(3, shr(_PRICE_SHIFT, order))
        }
    }

    /// @notice Extract the low 32-bit nonce/path suffix from a packed node.
    /// @param order Packed node.
    /// @return 32-bit nonce or branch path suffix.
    function _nonce(bytes32 order) private pure returns (uint32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint32(uint256(order));
    }

    /// @notice Extract the same-tick correction code from a packed branch node.
    /// @dev Zero marks leaves and mixed-tick branches. Uniform-tick branches store correction + 1.
    function _correctionCode(bytes32 node) private pure returns (uint32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint32((uint256(node) >> _CORRECTION_SHIFT) & _CORRECTION_MASK);
    }

    /// @notice Mark packed match metadata as having retained a dirty right-spine anchor.
    /// @param change Existing packed match-change metadata.
    /// @return Updated metadata with the dirty bit set.
    function _markMatchDirty(bytes32 change) private pure returns (bytes32) {
        return bytes32(uint256(change) | _MATCH_CHANGE_DIRTY);
    }

    /// @notice Return whether packed match metadata indicates a dirty right-spine anchor changed.
    /// @param change Packed match-change metadata.
    /// @return True if the dirty bit is set.
    function _matchChangeDirty(bytes32 change) private pure returns (bool) {
        return uint256(change) & _MATCH_CHANGE_DIRTY != 0;
    }

    /// @notice Extract the quantity field from a packed node.
    /// @param order Packed node.
    /// @return 160-bit quantity.
    function _quantity(bytes32 order) private pure returns (uint160) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160((uint256(order) >> _QUANTITY_SHIFT) & _QUANTITY_MASK);
    }
}
