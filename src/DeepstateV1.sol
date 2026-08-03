// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LibBit} from "solady/utils/LibBit.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IHook} from "./interfaces/IHook.sol";
import {TickMath32} from "./libraries/TickMath32.sol";

/// @title Deepstate V1
/// @notice Multi-pool, fully on-chain limit-order matching engine backed by radix trees.
/// @dev
/// Orders and aggregate branches are both represented by a single `bytes32` node word:
///
/// - bits 224-255: signed 32-bit logarithmic tick.
/// - bits  64-223: 160-bit quantity.
/// - bits  32-63: 32-bit same-tick branch correction code; zero for leaves/mixed branches.
/// - bits   0-31: 32-bit nonce/path suffix.
///
/// Tick `t` represents the dimensionless quote/base price `2 ** (96 * t / 2**31)`.
/// Tick zero is therefore exactly 1:1, the full signed domain spans approximately
/// `[2**-96, 2**96)`, and adjacent ticks differ by about 0.000309861 basis points.
/// Prices multiply raw token-unit quantities; token decimal normalization belongs in the tick
/// selected by the caller/router, not in token transfers performed by the engine.
///
/// The strict exponent bound is also an arithmetic invariant. A live tree contains at most
/// `type(uint160).max` aggregate quantity and every price is strictly below `2**96`, leaving every
/// aggregate quote below `2**256`. Recursive quantity and quote sums may therefore use unchecked
/// arithmetic after their child results have been validated. The routing layer separately rejects
/// any final signed settlement delta that exceeds `int256`.
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
/// Pools use sorted token addresses, and each pool epoch derives an isolated book id. `fillRoute`
/// mutates every selected book before settling one net transient delta per touched token. Optional
/// fees are taken from matched taker output and settled after user deltas. Top-of-book hooks are
/// similarly isolated: the matcher records the outgoing order and incoming nonce in transient slots,
/// then the outer fill/cancel flow invokes the configured pool hook after the book mutation.
/// Token settlement treats `address(0)` as native ETH and otherwise uses Solady safe transfer
/// helpers with standard, non-fee-on-transfer ERC20 behavior. Malicious or inexact token behavior
/// is outside the engine's accounting model and must be excluded by deployment configuration.
contract DeepstateV1 is Ownable {
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

    /// @dev Transient slot carrying the complete displaced top-order leaf back to the router.
    bytes32 private constant _TOP_CHANGE_OUTGOING_ORDER_SLOT =
        0x64b7215baea1c17e16f66db8b03af21431032e2e221c15ac43b0752d82a69b31;
    /// @dev Transient slot carrying the nonce of the new top order back to the router.
    bytes32 private constant _TOP_CHANGE_INCOMING_NONCE_SLOT =
        0xf95dfdfe2cf36f265e91ff578507ac6f6f9bffb77b95dcb89aef8ed16e5b1f45;

    /// @dev Transient pointer to the current fill leg's dynamically growing in-memory match buffer.
    bytes32 private constant _MATCH_BUFFER_SLOT = 0x7f8fe082ccb9a281fa5fa179f118219e229bb906df4e4aa8aee95977b867f45d;

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
    /// @dev `restingNode` uses the normal packed-node layout, except its quantity is the quantity
    /// filled by this event and its correction field makes the quote amount exactly recoverable.
    /// Let `delta = int256(uint256(correctionCode)) - 1`; the quote amount is the tick notional
    /// rounded down, minus `delta`. Code zero therefore represents a one-unit positive correction.
    /// @param bookId Book that supplied the resting ask.
    /// @param restingNode Self-contained ask fill node carrying tick, fill quantity, correction,
    /// and the consumed leaf or aggregate path identity.
    event AskMatched(bytes32 bookId, bytes32 restingNode);

    /// @notice Multiple resting ask aggregates matched by one incoming order.
    /// @dev Nodes use the exact `AskMatched` encoding and remain in execution-priority order.
    /// This event is emitted only when one fill leg discovers at least two match nodes.
    event AsksMatched(bytes32 bookId, bytes32[] restingNodes);

    /// @notice Matched resting bid liquidity.
    /// @dev `restingNode` uses the normal packed-node layout, except its quantity is the quantity
    /// filled by this event and its correction field makes the quote amount exactly recoverable.
    /// Let `delta = int256(uint256(correctionCode)) - 1`; the quote amount is the tick notional
    /// rounded up, plus `delta`. Code zero therefore represents a one-unit negative correction.
    /// @param bookId Book that supplied the resting bid.
    /// @param restingNode Self-contained bid fill node carrying tick, fill quantity, correction,
    /// and the consumed leaf or aggregate path identity.
    event BidMatched(bytes32 bookId, bytes32 restingNode);

    /// @notice Multiple resting bid aggregates matched by one incoming order.
    /// @dev Nodes use the exact `BidMatched` encoding and remain in execution-priority order.
    /// This event is emitted only when one fill leg discovers at least two match nodes.
    event BidsMatched(bytes32 bookId, bytes32[] restingNodes);

    /// @notice Matched a fully consumed exact mixed-price ask subtree.
    /// @dev The event signature identifies the ask side without an additional boolean data word.
    /// `subtreeRoot` identifies the historical child graph; individual maker fills are omitted.
    /// @param bookId Book that supplied the resting asks.
    /// @param subtreeRoot Root of the fully consumed mixed-price ask subtree.
    /// @param quantity Total base quantity consumed from the subtree.
    /// @param quoteAmount Exact total quote paid across the subtree.
    event AskSubtreeMatched(bytes32 bookId, bytes32 subtreeRoot, uint160 quantity, uint256 quoteAmount);

    /// @notice Matched a fully consumed exact mixed-price bid subtree.
    /// @dev Mirrors `AskSubtreeMatched`; the event signature identifies the bid side.
    /// @param bookId Book that supplied the resting bids.
    /// @param subtreeRoot Root of the fully consumed mixed-price bid subtree.
    /// @param quantity Total base quantity consumed from the subtree.
    /// @param quoteAmount Exact total quote paid across the subtree.
    event BidSubtreeMatched(bytes32 bookId, bytes32 subtreeRoot, uint160 quantity, uint256 quoteAmount);

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
    /// @notice A pool consumed the final epoch representable beside its packed hook flags.
    error EpochExhausted();
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
    function ownerOfOrder(bytes32 orderKey) public view virtual returns (address) {
        return orderOf[orderKey].owner;
    }

    /// @notice Return whether an active order id belongs to the bid tree.
    /// @dev The value is meaningful only when `ownerOfOrder(orderKey) != address(0)`.
    function isBidOrder(bytes32 orderKey) public view virtual returns (bool) {
        return orderOf[orderKey].isBid;
    }

    /// @notice Match an incoming order against a routed book without transferring tokens.
    /// @param id Globally unique book id.
    /// @param book Book storage selected by `id`.
    /// @param order Packed incoming order with price and quantity set, nonce bits set to zero.
    /// @param isBid True for a bid, false for an ask.
    /// @param hookEnabled True when changes to the resting side's top order should be recorded.
    /// @return limitPrice Incoming limit price.
    /// @return remaining Incoming base quantity left unmatched.
    /// @return baseFilled Base quantity matched.
    /// @return quoteAmount Quote value matched.
    function _matchBook(bytes32 id, Book storage book, bytes32 order, bool isBid, bool hookEnabled)
        internal
        returns (int32 limitPrice, uint160 remaining, uint160 baseFilled, uint256 quoteAmount)
    {
        (limitPrice, remaining) = _validateIncomingOrder(order);

        _beginMatchBuffer();

        if (isBid) {
            (remaining, baseFilled, quoteAmount) = _matchIncomingBid(id, book, limitPrice, remaining, hookEnabled);
        } else {
            (remaining, baseFilled, quoteAmount) = _matchIncomingAsk(id, book, limitPrice, remaining, hookEnabled);
        }

        _emitBufferedMatches(id, !isBid);
    }

    /// @notice Match an incoming bid against the ask root.
    /// @param id Book id whose ask tree is being consumed.
    /// @param book Book storage selected by `id`.
    /// @param limitPrice Highest ask price the bid will accept.
    /// @param remaining Incoming bid quantity before matching.
    /// @param hookEnabled True to record top-ask changes for the routing hook.
    /// @return newRemaining Bid quantity left unmatched.
    /// @return baseFilled Base quantity bought.
    /// @return quoteAmount Quote paid at resting ask prices.
    /// @dev The ask root lives in `tree[0].leftNode`.
    function _matchIncomingBid(bytes32 id, Book storage book, int32 limitPrice, uint160 remaining, bool hookEnabled)
        private
        returns (uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
        bytes32 root = book.tree[_ROOT_NODE].leftNode;
        if (root == bytes32(0)) return (remaining, 0, 0);

        if (!_rightSpineDirty(book, false) && limitPrice == type(int32).max && _quantity(root) <= remaining) {
            baseFilled = _quantity(root);
            if (hookEnabled) _recordTopOrderChange(_rightmostLeaf(book, root), 0);
            quoteAmount = _consumeSubtree(id, book, root, false);
            book.tree[_ROOT_NODE].leftNode = bytes32(0);
            unchecked {
                newRemaining = remaining - baseFilled;
            }
            return (newRemaining, baseFilled, quoteAmount);
        }

        bytes32 newRoot;
        bytes32 matchChange;
        uint256 matchFlags = _rightSpineDirty(book, false) ? _MATCH_DIRTY : 0;
        if (hookEnabled) matchFlags |= _MATCH_HOOK;
        (newRoot, baseFilled, quoteAmount, matchChange) =
            _matchAskRightSpine(id, book, root, limitPrice, remaining, matchFlags);
        unchecked {
            newRemaining = remaining - baseFilled;
        }
        if (newRoot != root) book.tree[_ROOT_NODE].leftNode = newRoot;
        if (_matchChangeDirty(matchChange) && newRoot != bytes32(0)) _setRightSpineDirty(book, false);
    }

    /// @notice Match an incoming ask against the bid root.
    /// @param id Book id whose bid tree is being consumed.
    /// @param book Book storage selected by `id`.
    /// @param limitPrice Lowest bid price the ask will accept.
    /// @param remaining Incoming ask quantity before matching.
    /// @param hookEnabled True to record top-bid changes for the routing hook.
    /// @return newRemaining Ask quantity left unmatched.
    /// @return baseFilled Base quantity sold.
    /// @return quoteAmount Quote received at resting bid prices.
    /// @dev The bid root lives in `tree[0].rightNode`.
    function _matchIncomingAsk(bytes32 id, Book storage book, int32 limitPrice, uint160 remaining, bool hookEnabled)
        private
        returns (uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
        bytes32 root = book.tree[_ROOT_NODE].rightNode;
        if (root == bytes32(0)) return (remaining, 0, 0);

        if (!_rightSpineDirty(book, true) && limitPrice == type(int32).min && _quantity(root) <= remaining) {
            baseFilled = _quantity(root);
            if (hookEnabled) _recordTopOrderChange(_rightmostLeaf(book, root), 0);
            quoteAmount = _consumeSubtree(id, book, root, true);
            book.tree[_ROOT_NODE].rightNode = bytes32(0);
            unchecked {
                newRemaining = remaining - baseFilled;
            }
            return (newRemaining, baseFilled, quoteAmount);
        }

        bytes32 newRoot;
        bytes32 matchChange;
        uint256 matchFlags = _rightSpineDirty(book, true) ? _MATCH_DIRTY : 0;
        if (hookEnabled) matchFlags |= _MATCH_HOOK;
        (newRoot, baseFilled, quoteAmount, matchChange) =
            _matchBidRightSpine(id, book, root, limitPrice, remaining, matchFlags);
        unchecked {
            newRemaining = remaining - baseFilled;
        }
        if (newRoot != root) book.tree[_ROOT_NODE].rightNode = newRoot;
        if (_matchChangeDirty(matchChange) && newRoot != bytes32(0)) _setRightSpineDirty(book, true);
    }

    /// @notice Cancel an open order or claim a filled order.
    /// @param id Book id that scopes the original order.
    /// @param book Book storage selected by `id`.
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
    function _cancelBook(bytes32 id, Book storage book, bytes32 order, address caller, uint256 hookFlags)
        internal
        returns (address owner, bool isBid, uint256 baseAmount, uint256 quoteAmount)
    {
        bytes32 orderKey = _orderId(id, order);
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

        emit OrderCancelled(id, order, owner, baseAmount, quoteAmount);
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
                    _recordTopOrderChange(removed, _replacementTopNonce(book, newRoot));
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
                    _recordTopOrderChange(removed, _replacementTopNonce(book, newRoot));
                }
            }
        }
    }

    /// @notice Rest unmatched quantity in one book.
    /// @param id Globally unique book id.
    /// @param book Book storage selected by `id`.
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
    /// avoid rewriting ancestors. A side that becomes empty may conservatively retain its dirty
    /// flag. `_materializeRightSpine` treats its zero root as an empty subtree, then the flag clear
    /// is folded into the nonce decrement written below instead of consuming a standalone SSTORE.
    function _restBook(
        bytes32 id,
        Book storage book,
        uint256 nonceAndFlags,
        int32 price,
        uint160 quantity,
        bool isBid,
        address owner,
        bool hookEnabled
    ) internal returns (bytes32 restingOrder, uint32 nextNonceAfter) {
        _validateRestingQuoteDomain(price, quantity, isBid);

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
        orderOf[_orderId(id, restingOrder)] = OrderState({owner: owner, isBid: isBid});

        _insertRestingOrder(book, restingOrder, isBid, hookEnabled);

        emit OrderRested(id, restingOrder, owner, isBid);
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
    function _matchAskLeaf(bytes32 root, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newRoot, uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
        (int32 restingPrice, uint160 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice > limitPrice) return (root, remaining, 0, 0);

        uint160 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        uint32 eventCorrectionCode = 1;
        if (fillQuantity == restingQuantity) {
            quoteAmount = _quoteValue(restingPrice, restingQuantity, false);
        } else {
            (quoteAmount, eventCorrectionCode) =
                _quoteDifferenceAndEventCode(restingPrice, restingQuantity, restingQuantity - fillQuantity, false);
        }

        _recordMatch(_withQuantityAndCorrection(root, fillQuantity, eventCorrectionCode));

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
    function _matchBidLeaf(bytes32 root, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newRoot, uint160 newRemaining, uint160 baseFilled, uint256 quoteAmount)
    {
        (int32 restingPrice, uint160 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice < limitPrice) return (root, remaining, 0, 0);

        uint160 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        uint32 eventCorrectionCode = 1;
        if (fillQuantity == restingQuantity) {
            quoteAmount = _quoteValue(restingPrice, restingQuantity, true);
        } else {
            (quoteAmount, eventCorrectionCode) =
                _quoteDifferenceAndEventCode(restingPrice, restingQuantity, restingQuantity - fillQuantity, true);
        }

        _recordMatch(_withQuantityAndCorrection(root, fillQuantity, eventCorrectionCode));

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
    function _emitAskRightSpineMatch(bytes32 node, uint160 fillQuantity, uint256 quoteAmount, uint256 matchFlags)
        private
    {
        _recordMatch(
            matchFlags & _MATCH_DIRTY != 0 ? _aggregateMatchEventNode(node, fillQuantity, quoteAmount, false) : node
        );
    }

    /// @notice Emit a bid match event from the right-spine matcher.
    /// @dev Mirrors `_emitAskRightSpineMatch` for bid-side same-price aggregate fills.
    function _emitBidRightSpineMatch(bytes32 node, uint160 fillQuantity, uint256 quoteAmount, uint256 matchFlags)
        private
    {
        _recordMatch(
            matchFlags & _MATCH_DIRTY != 0 ? _aggregateMatchEventNode(node, fillQuantity, quoteAmount, true) : node
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
        bytes32 id,
        Book storage book,
        bytes32 node,
        int32 limitPrice,
        uint160 remaining,
        uint256 matchFlags
    ) private returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount, bytes32 matchChange) {
        (bytes32 rightNode, uint256 branchSlot) = _rightNodeAndBranchSlot(book, node);
        if (rightNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(node, limitPrice, remaining);
            if (matchFlags & _MATCH_HOOK != 0 && fillQuantity != 0) {
                _recordTopOrderChange(node, newNode == bytes32(0) ? 0 : _nonce(newNode));
            }
            return (newNode, fillQuantity, quoteAmount, matchChange);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
        uint256 rightQuoteAmount;
        bytes32 leftNode = bytes32(0);
        {
            bool samePrice = _correctionCode(node) != 0;
            if (matchFlags & _MATCH_DIRTY != 0) {
                leftNode = _leftNodeAt(branchSlot);
                samePrice = _price(leftNode) == _price(rightNode);
            }
            if (samePrice) {
                bytes32 outgoingTopOrder;
                (fillQuantity, quoteAmount, outgoingTopOrder) =
                    _samePriceRightSpineFillQuantity(book, node, limitPrice, remaining, matchFlags);
                if (fillQuantity != 0) {
                    if (matchFlags & _MATCH_HOOK != 0) {
                        _recordTopOrderChange(outgoingTopOrder, 0);
                    }
                    _emitAskRightSpineMatch(node, fillQuantity, quoteAmount, matchFlags);
                    return (bytes32(0), fillQuantity, quoteAmount, matchChange);
                }
            }

            (newRightNode, rightFillQuantity, rightQuoteAmount, matchChange) =
                _matchAskRightSpine(id, book, rightNode, limitPrice, remaining, matchFlags);
        }
        if (rightFillQuantity == 0) return (node, 0, 0, bytes32(0));

        if (leftNode == bytes32(0)) leftNode = _leftNodeAt(branchSlot);
        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchAskSubtree(id, book, leftNode, limitPrice, remaining);
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
    function _matchAskSubtree(bytes32 id, Book storage book, bytes32 node, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        if (_correctionCode(node) != 0) {
            int32 tick = _price(node);
            if (tick > limitPrice) return (node, 0, 0);
            return _matchUniformSubtree(book, node, remaining, false, tick);
        }

        uint160 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(book, node) <= limitPrice) {
            quoteAmount = _consumeSubtree(id, book, node, false);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            (newRightNode, rightFillQuantity, rightQuoteAmount) =
                _matchAskSubtree(id, book, rightNode, limitPrice, remaining);
        }
        if (rightFillQuantity == 0) return (node, 0, 0);

        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchAskSubtree(id, book, leftNode, limitPrice, remaining);
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
        bytes32 id,
        Book storage book,
        bytes32 node,
        int32 limitPrice,
        uint160 remaining,
        uint256 matchFlags
    ) private returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount, bytes32 matchChange) {
        (bytes32 rightNode, uint256 branchSlot) = _rightNodeAndBranchSlot(book, node);
        if (rightNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(node, limitPrice, remaining);
            if (matchFlags & _MATCH_HOOK != 0 && fillQuantity != 0) {
                _recordTopOrderChange(node, newNode == bytes32(0) ? 0 : _nonce(newNode));
            }
            return (newNode, fillQuantity, quoteAmount, matchChange);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
        uint256 rightQuoteAmount;
        bytes32 leftNode = bytes32(0);
        {
            bool samePrice = _correctionCode(node) != 0;
            if (matchFlags & _MATCH_DIRTY != 0) {
                leftNode = _leftNodeAt(branchSlot);
                samePrice = _price(leftNode) == _price(rightNode);
            }
            if (samePrice) {
                bytes32 outgoingTopOrder;
                (fillQuantity, quoteAmount, outgoingTopOrder) = _samePriceRightSpineFillQuantity(
                    book, node, limitPrice, remaining, matchFlags | _MATCH_RESTING_BID
                );
                if (fillQuantity != 0) {
                    if (matchFlags & _MATCH_HOOK != 0) {
                        _recordTopOrderChange(outgoingTopOrder, 0);
                    }
                    _emitBidRightSpineMatch(node, fillQuantity, quoteAmount, matchFlags);
                    return (bytes32(0), fillQuantity, quoteAmount, matchChange);
                }
            }

            (newRightNode, rightFillQuantity, rightQuoteAmount, matchChange) =
                _matchBidRightSpine(id, book, rightNode, limitPrice, remaining, matchFlags);
        }
        if (rightFillQuantity == 0) return (node, 0, 0, bytes32(0));

        if (leftNode == bytes32(0)) leftNode = _leftNodeAt(branchSlot);
        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchBidSubtree(id, book, leftNode, limitPrice, remaining);
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
    function _matchBidSubtree(bytes32 id, Book storage book, bytes32 node, int32 limitPrice, uint160 remaining)
        private
        returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        if (_correctionCode(node) != 0) {
            int32 tick = _price(node);
            if (tick < limitPrice) return (node, 0, 0);
            return _matchUniformSubtree(book, node, remaining, true, tick);
        }

        uint160 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(book, node) >= limitPrice) {
            quoteAmount = _consumeSubtree(id, book, node, true);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 newRightNode;
        uint160 rightFillQuantity;
        uint256 rightQuoteAmount;
        {
            bytes32 rightNode = book.tree[node].rightNode;
            (newRightNode, rightFillQuantity, rightQuoteAmount) =
                _matchBidSubtree(id, book, rightNode, limitPrice, remaining);
        }
        if (rightFillQuantity == 0) return (node, 0, 0);

        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, fillQuantity, quoteAmount) = _matchBidSubtree(id, book, leftNode, limitPrice, remaining);
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
            if (hookEnabled) _recordTopOrderChange(bytes32(0), _nonce(node));
            return node;
        }

        bytes32 leftNode = book.tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            if (hookEnabled && nodeKey > _bidSortKey(root)) {
                _recordTopOrderChange(root, _nonce(node));
            }
            return _storeBranch(book, root, node, _bidSortKey(root), nodeKey, true);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _bidSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _bidSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            if (hookEnabled && _bit(nodeKey, _commonPrefix(nodeKey, leftKey))) {
                _recordTopOrderChange(_rightmostLeaf(book, root), _nonce(node));
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
            if (hookEnabled) _recordTopOrderChange(bytes32(0), _nonce(node));
            return node;
        }

        bytes32 leftNode = book.tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            if (hookEnabled && nodeKey > _askSortKey(root)) {
                _recordTopOrderChange(root, _nonce(node));
            }
            return _storeBranch(book, root, node, _askSortKey(root), nodeKey, false);
        }

        bytes32 rightNode = book.tree[root].rightNode;
        uint64 leftKey = _askSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _askSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            if (hookEnabled && _bit(nodeKey, _commonPrefix(nodeKey, leftKey))) {
                _recordTopOrderChange(_rightmostLeaf(book, root), _nonce(node));
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

    /// @notice Partially consume a clean same-tick subtree while decoding its tick only once.
    /// @dev The nonzero correction code proves that every descendant has `tick`. Exact quote
    /// deltas returned by child frames let each surviving ancestor update its correction without
    /// independently repricing both children.
    function _matchUniformSubtree(Book storage book, bytes32 node, uint160 remaining, bool restingIsBid, int32 tick)
        private
        returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount)
    {
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
        return _matchUniformSubtreeAtFactor(book, node, remaining, restingIsBid, factor, shift);
    }

    /// @dev Uniform-subtree recursion with the decoded price factor carried through every frame.
    function _matchUniformSubtreeAtFactor(
        Book storage book,
        bytes32 node,
        uint160 remaining,
        bool restingIsBid,
        uint256 factor,
        uint16 shift
    ) private returns (bytes32 newNode, uint160 fillQuantity, uint256 quoteAmount) {
        uint160 nodeQuantity = _quantity(node);
        bytes32 leftNode = book.tree[node].leftNode;

        if (nodeQuantity <= remaining) {
            quoteAmount = leftNode == bytes32(0)
                ? _quoteAtFactor(factor, shift, nodeQuantity, restingIsBid)
                : _uniformNodeQuoteAtFactor(book, node, restingIsBid, factor, shift);
            bytes32 eventNode = leftNode == bytes32(0) ? _withQuantityAndCorrection(node, nodeQuantity, 1) : node;
            _recordMatch(eventNode);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        if (leftNode == bytes32(0)) {
            uint160 newQuantity;
            unchecked {
                newQuantity = nodeQuantity - remaining;
            }
            quoteAmount = _quoteAtFactor(factor, shift, nodeQuantity, restingIsBid)
                - _quoteAtFactor(factor, shift, newQuantity, restingIsBid);
            uint256 standaloneQuote = _quoteAtFactor(factor, shift, remaining, restingIsBid);
            uint32 eventCorrectionCode = quoteAmount == standaloneQuote ? 1 : 0;
            _recordMatch(_withQuantityAndCorrection(node, remaining, eventCorrectionCode));
            return (_withQuantity(node, newQuantity), remaining, quoteAmount);
        }

        bytes32 rightNode = book.tree[node].rightNode;
        uint160 rightFillQuantity;
        uint256 rightQuoteAmount;
        (rightNode, rightFillQuantity, rightQuoteAmount) =
            _matchUniformSubtreeAtFactor(book, rightNode, remaining, restingIsBid, factor, shift);

        unchecked {
            remaining -= rightFillQuantity;
        }
        if (remaining != 0) {
            (leftNode, fillQuantity, quoteAmount) =
                _matchUniformSubtreeAtFactor(book, leftNode, remaining, restingIsBid, factor, shift);
        }

        unchecked {
            fillQuantity += rightFillQuantity;
            quoteAmount += rightQuoteAmount;
        }
        newNode = _replaceUniformBranchAfterFill(
            book, node, leftNode, rightNode, restingIsBid, fillQuantity, quoteAmount, factor, shift
        );
    }

    /// @dev Derive a surviving uniform branch's correction from its exact removed quote delta.
    function _replaceUniformBranchAfterFill(
        Book storage book,
        bytes32 oldNode,
        bytes32 leftNode,
        bytes32 rightNode,
        bool isBid,
        uint160 fillQuantity,
        uint256 quoteAmount,
        uint256 factor,
        uint16 shift
    ) private returns (bytes32 newNode) {
        // Uniform matching consumes the right child first. If this branch survives, the left child
        // therefore cannot be empty; an empty right child collapses to the untouched left child.
        if (rightNode == bytes32(0)) return leftNode;

        uint160 oldQuantity = _quantity(oldNode);
        uint160 newQuantity;
        unchecked {
            newQuantity = oldQuantity - fillQuantity;
        }

        uint256 oldAggregateQuote = _quoteAtFactor(factor, shift, oldQuantity, isBid);
        uint256 newAggregateQuote = _quoteAtFactor(factor, shift, newQuantity, isBid);
        uint256 oldCorrection = uint256(_correctionCode(oldNode)) - 1;
        uint256 correction;
        if (isBid) {
            correction = oldAggregateQuote + oldCorrection - quoteAmount - newAggregateQuote;
        } else {
            correction = newAggregateQuote + oldCorrection + quoteAmount - oldAggregateQuote;
        }
        uint64 leftKey = _pathKey(leftNode);
        uint64 rightKey = _pathKey(rightNode);
        // A correction is at most liveLeafCount - 1. The decrementing nonce admits at most
        // 2^32 - 2 resting leaves, so correction + 1 is strictly representable in uint32.
        // forge-lint: disable-next-line(unsafe-typecast)
        newNode = _branchNode(leftKey > rightKey ? leftKey : rightKey, newQuantity, uint32(correction + 1));
        book.tree[newNode] = Branch({leftNode: leftNode, rightNode: rightNode});
    }

    /// @notice Rebuild a previously optimized right spine back into exact aggregate branches.
    /// @param node Current subtree root.
    /// @return Exact subtree root.
    /// @dev Only the right spine can contain stable anchors. Left subtrees remain exact because the
    /// optimization is used only for right-child updates. Node zero is the shared root anchor, not
    /// a branch; treating it as an empty subtree prevents one side from aliasing the other root.
    function _materializeRightSpine(Book storage book, bytes32 node, bool isBid) private returns (bytes32) {
        if (node == bytes32(0)) return bytes32(0);

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
    ) private view returns (uint160 fillQuantity, uint256 quoteAmount, bytes32 outgoingTopOrder) {
        bool isBid = matchFlags & _MATCH_RESTING_BID != 0;
        int32 price;
        bool uniform;
        if (matchFlags & _MATCH_DIRTY != 0) {
            (uniform, price, fillQuantity, quoteAmount, outgoingTopOrder) = _dirtyRightSpineData(book, node, isBid);
        } else {
            uniform = _correctionCode(node) != 0;
            price = _price(node);
            fillQuantity = _quantity(node);
            quoteAmount = uniform ? _uniformBranchQuote(node, isBid) : 0;
            if (matchFlags & _MATCH_HOOK != 0) {
                outgoingTopOrder = _rightmostLeaf(book, node);
            }
        }
        if (!uniform) return (0, 0, bytes32(0));
        if (matchFlags & _MATCH_RESTING_BID != 0 ? price < limitPrice : price > limitPrice) {
            return (0, 0, bytes32(0));
        }
        if (fillQuantity > remaining) return (0, 0, bytes32(0));
    }

    /// @notice Recover exact same-tick quantity and quote value from a stale global right spine.
    /// @dev Only right children can themselves be stale. Every left child is an exact off-spine
    /// subtree, so its packed correction gives its exact rounded quote value in O(1). Recursing
    /// solely through right children keeps recovery bounded by the 64-bit radix depth.
    function _dirtyRightSpineData(Book storage book, bytes32 node, bool isBid)
        private
        view
        returns (bool uniform, int32 tick, uint160 quantity, uint256 quoteAmount, bytes32 rightmostOrder)
    {
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            quantity = _quantity(node);
            return (true, _price(node), quantity, _quoteValue(_price(node), quantity, isBid), node);
        }

        bytes32 rightNode = book.tree[node].rightNode;
        bool leftUniform = book.tree[leftNode].leftNode == bytes32(0) || _correctionCode(leftNode) != 0;
        if (!leftUniform) return (false, 0, 0, 0, 0);

        (bool rightUniform, int32 rightTick, uint160 rightQuantity, uint256 rightQuote, bytes32 rightmostLeaf) =
            _dirtyRightSpineData(book, rightNode, isBid);
        if (!rightUniform || _price(leftNode) != rightTick) return (false, 0, 0, 0, bytes32(0));

        tick = rightTick;
        quantity = _quantity(leftNode) + rightQuantity;
        quoteAmount = _uniformNodeQuote(book, leftNode, isBid) + rightQuote;
        rightmostOrder = rightmostLeaf;
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
        uint32 correctionCode = 0;

        if (_price(a) == _price(b) && _uniformNode(book, a) && _uniformNode(book, b)) {
            int32 tick = _price(a);
            (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(tick);
            uint256 childQuote = _uniformNodeQuoteAtFactor(book, a, isBid, factor, shift)
                + _uniformNodeQuoteAtFactor(book, b, isBid, factor, shift);
            uint256 aggregateQuote = _quoteAtFactor(factor, shift, quantity, isBid);
            uint256 correction = isBid ? childQuote - aggregateQuote : aggregateQuote - childQuote;
            // A correction is at most liveLeafCount - 1. The decrementing nonce admits at most
            // 2^32 - 2 resting leaves, so correction + 1 is strictly representable in uint32.
            // forge-lint: disable-next-line(unsafe-typecast)
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

        return _applyUniformCorrection(node, quoteAmount, isBid);
    }

    /// @dev Return a uniform branch's exact rounded quote when branch status is already known.
    function _uniformBranchQuote(bytes32 node, bool isBid) private pure returns (uint256 quoteAmount) {
        quoteAmount = _quoteValue(_price(node), _quantity(node), isBid);
        return _applyUniformCorrection(node, quoteAmount, isBid);
    }

    /// @dev Apply the correction encoded as `correction + 1` on a uniform branch.
    function _applyUniformCorrection(bytes32 node, uint256 quoteAmount, bool isBid) private pure returns (uint256) {
        uint256 correction = uint256(_correctionCode(node)) - 1;
        return isBid ? quoteAmount + correction : quoteAmount - correction;
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

    /// @dev Load a branch's right child and retain its mapping slot so the left child can be read
    /// later without hashing `tree[node]` a second time.
    function _rightNodeAndBranchSlot(Book storage book, bytes32 node)
        private
        view
        returns (bytes32 rightNode, uint256 branchSlot)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, node)
            mstore(0x20, add(book.slot, 1))
            branchSlot := keccak256(0, 0x40)
            rightNode := sload(add(branchSlot, 1))
        }
    }

    /// @dev Load the left child paired with a slot returned by `_rightNodeAndBranchSlot`.
    function _leftNodeAt(uint256 branchSlot) private view returns (bytes32 leftNode) {
        /// @solidity memory-safe-assembly
        assembly {
            leftNode := sload(branchSlot)
        }
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
        uint32 incomingNonce;
        /// @solidity memory-safe-assembly
        assembly {
            incomingNonce := tload(_TOP_CHANGE_INCOMING_NONCE_SLOT)
        }
        // Callers reach this helper only after a top fill has recorded a nonzero outgoing order.
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

    /// @notice Start an empty, dynamically growing match buffer for one fill leg.
    /// @dev Memory layout is `capacity || length || nodes...`. Capacity starts at one so ordinary
    /// single-maker fills reserve only three words. `_recordMatch` doubles it only when required.
    function _beginMatchBuffer() private {
        /// @solidity memory-safe-assembly
        assembly {
            let pointer := mload(0x40)
            mstore(pointer, 1)
            mstore(add(pointer, 0x20), 0)
            mstore(0x40, add(pointer, 0x60))
            tstore(_MATCH_BUFFER_SLOT, pointer)
        }
    }

    /// @notice Append an exact packed match node to the current fill leg's memory buffer.
    /// @dev Geometric growth keeps appends amortized constant time and imposes no fixed event cap.
    /// Old allocations remain reserved until the call returns, as required by Solidity's monotonic
    /// free-memory convention.
    function _recordMatch(bytes32 node) private {
        /// @solidity memory-safe-assembly
        assembly {
            let pointer := tload(_MATCH_BUFFER_SLOT)
            let capacity := mload(pointer)
            let length := mload(add(pointer, 0x20))

            if eq(length, capacity) {
                let newCapacity := shl(1, capacity)
                let newPointer := mload(0x40)
                mstore(newPointer, newCapacity)
                mstore(add(newPointer, 0x20), length)

                mcopy(add(newPointer, 0x40), add(pointer, 0x40), shl(5, length))

                mstore(0x40, add(add(newPointer, 0x40), shl(5, newCapacity)))
                pointer := newPointer
                tstore(_MATCH_BUFFER_SLOT, pointer)
            }

            mstore(add(add(pointer, 0x40), shl(5, length)), node)
            mstore(add(pointer, 0x20), add(length, 1))
        }
    }

    /// @notice Emit the current leg as one compact event or one ABI-decodable batch event.
    /// @param id Book that supplied the resting liquidity.
    /// @param restingIsBid True when the buffered nodes came from the bid tree.
    function _emitBufferedMatches(bytes32 id, bool restingIsBid) private {
        uint256 length;
        bytes32 singleNode;
        bytes32[] memory nodes;

        /// @solidity memory-safe-assembly
        assembly {
            let pointer := tload(_MATCH_BUFFER_SLOT)
            length := mload(add(pointer, 0x20))
            switch length
            case 1 { singleNode := mload(add(pointer, 0x40)) }
            default { nodes := add(pointer, 0x20) }
            tstore(_MATCH_BUFFER_SLOT, 0)
        }

        if (length == 0) return;
        if (length == 1) {
            if (restingIsBid) emit BidMatched(id, singleNode);
            else emit AskMatched(id, singleNode);
            return;
        }

        if (restingIsBid) emit BidsMatched(id, nodes);
        else emit AsksMatched(id, nodes);
    }

    /// @notice Record one top-order change in transient storage for the router to consume.
    /// @dev Either slot being nonzero is the signal that a hook should be considered. The complete
    /// outgoing leaf is retained so the router can report the sold token and sold amount without
    /// widening the hook callback. A first rest writes only `incomingNonce`.
    function _recordTopOrderChange(bytes32 outgoingOrder, uint32 incomingNonce) private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_TOP_CHANGE_OUTGOING_ORDER_SLOT, outgoingOrder)
            tstore(_TOP_CHANGE_INCOMING_NONCE_SLOT, incomingNonce)
        }
    }

    /// @notice Consume and clear the latest recorded top-order change.
    /// @return outgoingOrder Previous top order's complete live leaf.
    /// @return incomingNonce New top order nonce, or zero if the side is empty/unknown.
    function _takeTopOrderChange() internal returns (bytes32 outgoingOrder, uint32 incomingNonce) {
        /// @solidity memory-safe-assembly
        assembly {
            outgoingOrder := tload(_TOP_CHANGE_OUTGOING_ORDER_SLOT)
            incomingNonce := tload(_TOP_CHANGE_INCOMING_NONCE_SLOT)
            tstore(_TOP_CHANGE_OUTGOING_ORDER_SLOT, 0)
            tstore(_TOP_CHANGE_INCOMING_NONCE_SLOT, 0)
        }
    }

    /// @notice Consume a subtree that has already been proven fully crossing and small enough.
    /// @param node Subtree root.
    /// @param restingIsBid True if the consumed subtree is from the bid tree.
    /// @return quoteAmount Total quote value of the consumed subtree.
    /// @dev
    /// This helper is reached only for an exact mixed-price subtree that fully crosses and fits
    /// inside the incoming remainder. Quote calculation still visits every mixed child, but the
    /// traversal emits one summary rather than one event per consumed leaf or uniform child.
    function _consumeSubtree(bytes32 id, Book storage book, bytes32 node, bool restingIsBid)
        private
        returns (uint256 quoteAmount)
    {
        uint160 quantity = _quantity(node);
        quoteAmount = _subtreeQuote(book, node, restingIsBid);

        // Keep logs in execution-priority order across buffered leaf matches and subtree summaries.
        _emitBufferedMatches(id, restingIsBid);

        if (restingIsBid) {
            emit BidSubtreeMatched(id, node, quantity, quoteAmount);
        } else {
            emit AskSubtreeMatched(id, node, quantity, quoteAmount);
        }

        _beginMatchBuffer();
    }

    /// @notice Compute the exact quote sum for a fully consumed subtree without emitting child logs.
    /// @dev Uniform branches remain O(1) through their correction code. Mixed branches recurse in
    /// the matcher's established right-first order and preserve every leaf-level rounding result.
    function _subtreeQuote(Book storage book, bytes32 node, bool restingIsBid)
        private
        view
        returns (uint256 quoteAmount)
    {
        uint160 quantity = _quantity(node);
        bytes32 leftNode = book.tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            return _quoteValue(_price(node), quantity, restingIsBid);
        }

        if (_correctionCode(node) != 0) {
            return _uniformNodeQuote(book, node, restingIsBid);
        }

        quoteAmount = _subtreeQuote(book, book.tree[node].rightNode, restingIsBid);
        unchecked {
            quoteAmount += _subtreeQuote(book, leftNode, restingIsBid);
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

    /// @notice Build the globally unique owner key for an order in a book.
    /// @param bookKey Book id that scopes the order.
    /// @param order Original packed order node.
    /// @return id `keccak256(bookKey, order)`.
    function _orderId(bytes32 bookKey, bytes32 order) internal pure returns (bytes32 id) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, bookKey)
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

    /// @dev Reject maker liquidity that cannot be represented by the signed settlement deltas.
    function _validateRestingQuoteDomain(int32 price, uint160 quantity, bool isBid) private pure {
        if (_quoteValue(price, quantity, isBid) > uint256(type(int256).max)) revert InvalidOrder();
    }

    /// @dev Difference between two same-tick notionals while decoding the tick only once.
    function _quoteDifference(int32 price, uint160 largerQuantity, uint160 smallerQuantity, bool roundUp)
        private
        pure
        returns (uint256 quoteAmount)
    {
        if (price == 0) return largerQuantity - smallerQuantity;
        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(price);
        quoteAmount = _quoteDifferenceAtFactor(factor, shift, largerQuantity, smallerQuantity, roundUp);
    }

    /// @dev Quote a partial leaf fill and encode its event rounding delta without decoding the tick twice.
    function _quoteDifferenceAndEventCode(int32 price, uint160 largerQuantity, uint160 smallerQuantity, bool roundUp)
        private
        pure
        returns (uint256 quoteAmount, uint32 correctionCode)
    {
        uint160 fillQuantity;
        unchecked {
            fillQuantity = largerQuantity - smallerQuantity;
        }
        if (price == 0) return (fillQuantity, 1);

        (uint256 factor, uint16 shift) = TickMath32.getPriceFactorAtTick(price);
        quoteAmount = _quoteDifferenceAtFactor(factor, shift, largerQuantity, smallerQuantity, roundUp);
        correctionCode = quoteAmount == _quoteAtFactor(factor, shift, fillQuantity, roundUp) ? 1 : 0;
    }

    /// @dev Difference between same-tick rounded notionals without requiring either full notional to fit.
    function _quoteDifferenceAtFactor(
        uint256 factor,
        uint16 shift,
        uint160 largerQuantity,
        uint160 smallerQuantity,
        bool roundUp
    ) private pure returns (uint256 quoteAmount) {
        uint160 fillQuantity;
        unchecked {
            fillQuantity = largerQuantity - smallerQuantity;
        }
        if (fillQuantity == 0) return 0;

        // Slither's assembly shift detector does not recognize the parenthesized mask arithmetic.
        // slither-disable-start incorrect-shift
        /// @solidity memory-safe-assembly
        assembly {
            let productLow := mul(fillQuantity, factor)
            let productHigh := 0
            if or(shr(128, fillQuantity), shr(128, factor)) {
                let mm := mulmod(fillQuantity, factor, not(0))
                productHigh := sub(mm, add(productLow, lt(mm, productLow)))
            }

            let smallerLow := mul(smallerQuantity, factor)
            quoteAmount := or(shl(sub(256, shift), productHigh), shr(shift, productLow))
            let mask := sub(shl(shift, 1), 1)
            let remainder := and(productLow, mask)
            let smallerRemainder := and(smallerLow, mask)
            let sum := add(smallerRemainder, remainder)
            if gt(sum, mask) { quoteAmount := add(quoteAmount, 1) }
            let largerRemainder := and(sum, mask)

            if and(roundUp, iszero(iszero(largerRemainder))) {
                quoteAmount := add(quoteAmount, 1)
            }
            if and(roundUp, iszero(iszero(smallerRemainder))) {
                quoteAmount := sub(quoteAmount, 1)
            }
        }
        // slither-disable-end incorrect-shift
    }

    /// @dev Multiply quantity by a Q128 fractional price factor and fold in its binary exponent.
    /// The ±96 tick exponent keeps `shift` in `[32, 224]`, so the quotient is always produced by
    /// the general right-shift path and cannot overflow a uint256 for a live uint160 quantity.
    function _quoteAtFactor(uint256 factor, uint16 shift, uint160 quantity, bool roundUp)
        private
        pure
        returns (uint256 quoteAmount)
    {
        // Every internal caller supplies a live or filled quantity. `_quoteValue` handles the only
        // public-facing zero-quantity case before decoding the tick factor.
        // Slither's assembly shift detector does not recognize the parenthesized mask arithmetic.
        // slither-disable-start incorrect-shift
        /// @solidity memory-safe-assembly
        assembly {
            let productLow := mul(quantity, factor)
            let productHigh := 0
            // The product fits one word only when both operands fit 128 bits. Nearest-boundary
            // factors may exceed Q128, so quantity alone cannot prove that the high word is zero.
            if or(shr(128, quantity), shr(128, factor)) {
                let mm := mulmod(quantity, factor, not(0))
                productHigh := sub(mm, add(productLow, lt(mm, productLow)))
            }
            quoteAmount := or(shl(sub(256, shift), productHigh), shr(shift, productLow))
            let remainder := and(productLow, sub(shl(shift, 1), 1))

            if and(roundUp, iszero(iszero(remainder))) {
                quoteAmount := add(quoteAmount, 1)
            }
        }
        // slither-disable-end incorrect-shift
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
        // Slither's assembly shift detector does not recognize this parenthesized field mask.
        // slither-disable-start incorrect-shift
        /// @solidity memory-safe-assembly
        assembly {
            updated := or(
                and(order, not(shl(_QUANTITY_SHIFT, 0xffffffffffffffffffffffffffffffffffffffff))),
                shl(_QUANTITY_SHIFT, quantity)
            )
        }
        // slither-disable-end incorrect-shift
    }

    /// @notice Build a self-contained event node for a dirty same-tick aggregate fill.
    /// @dev Right-spine anchors may have stale quantity and correction fields. The event node keeps
    /// the anchor's tick/path identity, replaces quantity with the amount filled, and derives the
    /// exact leaf-rounding correction from the already-computed quote amount. Offchain consumers
    /// can therefore reconstruct quote value without two additional event words.
    function _aggregateMatchEventNode(bytes32 node, uint160 quantity, uint256 quoteAmount, bool isBid)
        private
        pure
        returns (bytes32 updated)
    {
        uint256 aggregateQuote = _quoteValue(_price(node), quantity, isBid);
        uint256 correction = isBid ? quoteAmount - aggregateQuote : aggregateQuote - quoteAmount;
        // A correction is at most matchedLeafCount - 1. The decrementing nonce admits at most
        // 2^32 - 2 resting leaves, so correction + 1 is strictly representable in uint32.
        // forge-lint: disable-next-line(unsafe-typecast)
        updated = _withQuantityAndCorrection(node, quantity, uint32(correction + 1));
    }

    /// @notice Replace the quantity and event-correction fields of a packed node.
    /// @dev Match events interpret `correctionCode - 1` as a signed one-sided rounding delta:
    /// bids add it to the rounded-up notional and asks subtract it from the rounded-down notional.
    /// Code zero therefore represents the only negative case, a one-unit inverse correction from
    /// a partial leaf fill; code one means no correction.
    function _withQuantityAndCorrection(bytes32 node, uint160 quantity, uint32 correctionCode)
        private
        pure
        returns (bytes32 updated)
    {
        // Slither's assembly shift detector does not recognize these parenthesized field masks.
        // slither-disable-start incorrect-shift
        /// @solidity memory-safe-assembly
        assembly {
            updated := or(
                and(
                    node,
                    not(
                        or(
                            shl(_QUANTITY_SHIFT, 0xffffffffffffffffffffffffffffffffffffffff),
                            shl(_CORRECTION_SHIFT, 0xffffffff)
                        )
                    )
                ),
                or(shl(_QUANTITY_SHIFT, quantity), shl(_CORRECTION_SHIFT, correctionCode))
            )
        }
        // slither-disable-end incorrect-shift
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
        /// @notice Lower token address in the sorted pair.
        address token0;
        /// @notice Higher token address in the sorted pair.
        address token1;
        /// @notice Book epoch to match against.
        uint256 epoch;
        /// @notice Incoming order packed as `price || quantity || 0 nonce`.
        bytes32 order;
        /// @notice True for a bid buying token0 with token1; false for an ask selling token0.
        bool isBid;
        /// @notice True to discard any unmatched quantity instead of resting it.
        bool noRest;
        /// @notice True to require the entire input quantity to match.
        bool fillOrKill;
    }

    /// @notice Mutable in-memory accumulator for a route.
    /// @dev
    /// `touched` and `feeTouched` are deduplicated token lists. The actual signed token deltas live
    /// in transient storage keyed by token address, while protocol fee amounts use `_feeSlot(token)`
    /// to avoid colliding with user deltas for the same token.
    struct RouteState {
        /// @notice Tokens with nonzero user settlement deltas.
        address[] touched;
        /// @notice Number of populated entries in `touched`.
        uint256 touchedCount;
        /// @notice Tokens with nonzero protocol fee balances.
        address[] feeTouched;
        /// @notice Number of populated entries in `feeTouched`.
        uint256 feeTouchedCount;
    }

    /// @dev Low 254 bits of `_poolEpochAndHookFlags`; high bits are hook activation flags.
    uint256 private constant _POOL_EPOCH_MASK = (uint256(1) << 254) - 1;
    /// @dev Pool flag enabling hooks when token0 buyers change, i.e. bid-side top changes.
    uint256 private constant _POOL_HOOK_TOKEN0_ACTIVE = uint256(1) << 254;
    /// @dev Pool flag enabling hooks when token1 buyers change, i.e. ask-side top changes.
    uint256 private constant _POOL_HOOK_TOKEN1_ACTIVE = uint256(1) << 255;
    /// @dev Mask for all pool-level hook activation bits.
    uint256 private constant _POOL_HOOK_ACTIVE_MASK = _POOL_HOOK_TOKEN0_ACTIVE | _POOL_HOOK_TOKEN1_ACTIVE;
    /// @dev Book-local copy of token0 hook activation, stored above nonce/right-spine flags.
    uint256 private constant _BOOK_HOOK_TOKEN0_ACTIVE = uint256(1) << 34;
    /// @dev Book-local copy of token1 hook activation, stored above nonce/right-spine flags.
    uint256 private constant _BOOK_HOOK_TOKEN1_ACTIVE = uint256(1) << 35;
    /// @dev Mask for all book-local hook activation bits.
    uint256 private constant _BOOK_HOOK_ACTIVE_MASK = _BOOK_HOOK_TOKEN0_ACTIVE | _BOOK_HOOK_TOKEN1_ACTIVE;
    /// @dev Basis-point denominator used by protocol fee math.
    uint256 private constant _BPS_DENOMINATOR = 10_000;
    /// @dev Maximum fee rate: 100 bps = 1%.
    uint16 private constant _MAX_FEE_BPS = 100;
    /// @dev Maximum gas forwarded to an optional hook. Matching must remain usable if a hook loops.
    uint256 private constant _HOOK_GAS_LIMIT = 200_000;
    /// @dev High-bit domain separator for transient protocol fee slots.
    uint256 private constant _FEE_DELTA_DOMAIN = uint256(1) << 255;
    /// @notice Latest restable epoch for each sorted token pair.
    mapping(bytes32 poolId => uint256 epochAndHookFlags) private _poolEpochAndHookFlags;

    /// @notice Optional top-of-book hook config by sorted-token pool.
    mapping(bytes32 poolId => address hook) public poolHook;

    /// @dev Protocol fee config packed as `recipient | bps << 160`. A zero recipient disables fees.
    /// The owner may set a nonzero recipient with zero bps; this leaves fee logic enabled but
    /// produces no fee amounts.
    uint256 private _feeConfig;

    /// @notice Emitted when a book is initialized.
    /// @param poolId Canonical sorted-token pool id.
    /// @param bookId Book id derived from sorted tokens and epoch.
    /// @param epoch Epoch initialized for the pool.
    event BookInitialized(bytes32 poolId, bytes32 bookId, uint256 epoch);

    /// @notice Emitted when top-of-book hooks are configured for a pool.
    /// @param poolId Canonical sorted-token pool id.
    /// @param hook Hook contract, or zero when all hook flags are disabled.
    /// @param token0Active True if bid-side top-buyer changes should call the hook.
    /// @param token1Active True if ask-side top-buyer changes should call the hook.
    event PoolHookConfigured(bytes32 poolId, address hook, bool token0Active, bool token1Active);

    /// @notice Emitted when protocol fill fees are configured.
    /// @param recipient Protocol fee recipient. Zero disables fees.
    /// @param bps Fee rate in basis points.
    event FeeConfigured(address recipient, uint16 bps);

    /// @notice Hook config is invalid.
    error InvalidHook();
    /// @notice Fee config is invalid.
    error InvalidFeeConfig();
    /// @notice A token delta cannot be represented in the signed settlement accumulator.
    error DeltaOverflow();
    /// @notice Supplied native ETH is less than the caller's net ETH debit.
    error InvalidNativeValue();

    /// @notice Set deployer as owner.
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
    /// @return recipient Current protocol fee recipient.
    /// @return bps Current fee rate in basis points.
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
    /// @param hook Hook contract called when a side's top order changes.
    /// @param token0Active True to hook token0 buyers, i.e. top bids.
    /// @param token1Active True to hook token1 buyers, i.e. top asks.
    function setPoolHookConfig(address token0, address token1, address hook, bool token0Active, bool token1Active)
        external
        onlyOwner
    {
        _requireSortedTokens(token0, token1);

        uint256 activeFlags = 0;
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

    /// @notice Submit one bid or ask and optionally rest unmatched quantity in the routed epoch.
    /// @param params Fill parameters.
    /// @return restingOrder Packed order node if any quantity rested, otherwise zero.
    /// @dev
    /// The routed `epoch` is used for matching. An initialized book with nonce one is exhausted and
    /// historical; its unmatched remainder is automatically no-rest even when `params.noRest` is
    /// false. Callers that want maker liquidity must submit a separate leg against the active epoch.
    /// Settlement is output, input, fee, then any `msg.value` above the net ETH input is refunded.
    function fill(FillParams calldata params) external payable nonReentrant returns (bytes32 restingOrder) {
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

        uint256 nativeRefund = _settleDeltas(params.token0, token0Delta, params.token1, token1Delta);
        if (feeAmount != 0) {
            address feeRecipient;
            /// @solidity memory-safe-assembly
            assembly {
                feeRecipient := config
            }
            _safeTransferOut(params.isBid ? params.token0 : params.token1, feeRecipient, feeAmount);
        }
        _refundNativeValue(nativeRefund);
    }

    /// @notice Execute multiple routed fills atomically and settle each touched token once.
    /// @param fills Sequential route legs.
    /// @dev
    /// Each leg may target a different sorted pair and epoch. State changes are applied leg by leg,
    /// but transfers are delayed until all legs complete. Native ETH uses `address(0)`, is netted
    /// across every leg. Any `msg.value` above the caller's net ETH input is refunded after fees.
    function fillRoute(FillParams[] calldata fills) external payable nonReentrant {
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

        uint256 nativeRefund = _settleTouched(route.touched, route.touchedCount);
        if (config != 0) {
            address feeRecipient;
            /// @solidity memory-safe-assembly
            assembly {
                feeRecipient := config
            }
            _settleFees(feeRecipient, route.feeTouched, route.feeTouchedCount);
        }
        _refundNativeValue(nativeRefund);
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

        if (baseAmount != 0) _safeTransferOut(token0, owner, baseAmount);
        if (quoteAmount != 0) token1.safeTransfer(owner, quoteAmount);
    }

    /// @notice Compute the canonical pool id for a sorted token pair.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @return id `keccak256(token0, token1)`.
    /// @dev Does not validate sorting; callers that accept user input should call `_requireSortedTokens` first.
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
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @param epoch Pool epoch.
    /// @return id `keccak256(token0, token1, epoch)`.
    /// @dev Does not validate sorting; callers that accept user input should call `_requireSortedTokens` first.
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
    /// @param id Book id.
    /// @param order Original packed order node.
    /// @return Globally unique order id used by `ownerOfOrder`.
    function orderId(bytes32 id, bytes32 order) external pure returns (bytes32) {
        return _orderId(id, order);
    }

    /// @notice Return the nonce and live sold amount of one book side's best order.
    /// @param id Canonical book id.
    /// @param isBid True for the bid tree, false for the ask tree.
    /// @return nonce Current best order nonce, or zero when the side is empty.
    /// @return soldAmount Current collateral sold by that order, saturated at `uint160.max`.
    function topOrder(bytes32 id, bool isBid) external view returns (uint32 nonce, uint160 soldAmount) {
        Book storage book = books[id];
        bytes32 root = isBid ? book.tree[_ROOT_NODE].rightNode : book.tree[_ROOT_NODE].leftNode;
        if (root == bytes32(0)) return (0, 0);

        bytes32 order = _rightmostLeaf(book, root);
        return (_nonce(order), _hookAmount(order, isBid));
    }

    /// @notice Return the active book id for a sorted token pair.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @return Current active book id for rests in the pair.
    function activeBookId(address token0, address token1) external view returns (bytes32) {
        _requireSortedTokens(token0, token1);
        return bookId(token0, token1, poolEpoch(poolId(token0, token1)));
    }

    /// @notice Return the active restable epoch for a sorted-token pool id.
    /// @param pid Canonical sorted-token pool id.
    /// @return Active epoch. Zero is a valid first epoch.
    function poolEpoch(bytes32 pid) public view returns (uint256) {
        return _poolEpoch(_poolEpochAndHookFlags[pid]);
    }

    /// @notice Return the low 32-bit next nonce for a book.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @param epoch Book epoch.
    /// @return Next decrementing nonce, or zero if the book has not been initialized.
    function nextNonce(address token0, address token1, uint256 epoch) external view returns (uint32) {
        _requireSortedTokens(token0, token1);
        return _nextNonce(books[bookId(token0, token1, epoch)]);
    }

    /// @notice Return roots for a book. `askRoot` is `tree[0].leftNode`; `bidRoot` is `tree[0].rightNode`.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @param epoch Book epoch.
    /// @return askRoot Ask tree root.
    /// @return bidRoot Bid tree root.
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
    /// @param id Book id.
    /// @param node Leaf or branch node.
    /// @return leftNode Stored left child, or zero if `node` is a leaf/empty.
    /// @return rightNode Stored right child, or zero if `node` is a leaf/empty.
    function tree(bytes32 id, bytes32 node) external view returns (bytes32 leftNode, bytes32 rightNode) {
        Branch storage branch = books[id].tree[node];
        leftNode = branch.leftNode;
        rightNode = branch.rightNode;
    }

    /// @notice Execute one fill leg and return signed token deltas without settling ERC20s.
    /// @param params Fill parameters for one routed leg.
    /// @return restingOrder Packed resting order if unmatched quantity rested.
    /// @return token0Delta Positive if token0 should be paid to the caller, negative if pulled.
    /// @return token1Delta Positive if token1 should be paid to the caller, negative if pulled.
    /// @dev
    /// Deltas are taker-relative. For a bid, matched base is positive token0 and spent quote is
    /// negative token1; any resting bid collateral is also negative token1. For an ask, matched
    /// base is negative token0 and received quote is positive token1; any resting ask collateral is
    /// negative token0.
    // Hook callbacks are reached only through `fill`, `fillRoute`, and `cancel`, all of which hold
    // the transient reentrancy guard. The only unguarded mutators are owner-only configuration;
    // a hook can call them only when the trusted owner deliberately makes the hook itself owner.
    // slither-disable-start reentrancy-no-eth,reentrancy-benign
    function _executeFill(FillParams calldata params)
        private
        returns (bytes32 restingOrder, int256 token0Delta, int256 token1Delta)
    {
        _requireSortedTokens(params.token0, params.token1);
        bytes32 routedBookId = bookId(params.token0, params.token1, params.epoch);
        Book storage routedBook = books[routedBookId];
        uint256 routedNonceAndFlags = routedBook.nonceAndFlags;
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 routedNonce = uint32(routedNonceAndFlags);

        int32 limitPrice;
        uint160 remaining;
        uint160 baseFilled;
        uint256 quoteAmount;

        (limitPrice, remaining, baseFilled, quoteAmount) =
            _matchOrValidate(params, routedBookId, routedBook, routedNonceAndFlags);

        // Rotation initializes the successor as soon as nonce two is assigned, so a nonce-one
        // book is exhausted and historical under valid state transitions. It remains matchable,
        // but unmatched quantity from it is automatically no-rest.
        bool restAllowed = !params.noRest && routedNonce != 1;

        if (remaining != 0 && params.fillOrKill) revert FillOrKill();

        if (params.isBid) {
            token0Delta = int256(uint256(baseFilled));
            token1Delta = _debitDelta(0, quoteAmount);

            if (remaining != 0 && restAllowed) {
                restingOrder = _restRemaining(
                    params.token0,
                    params.token1,
                    params.epoch,
                    routedBookId,
                    routedBook,
                    routedNonce == 0,
                    limitPrice,
                    remaining,
                    true
                );
                uint256 collateral = _quoteValue(limitPrice, remaining, true);
                token1Delta = _debitDelta(token1Delta, collateral);
            }
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            token0Delta = -int256(uint256(baseFilled));
            token1Delta = _creditDelta(quoteAmount);

            if (remaining != 0 && restAllowed) {
                restingOrder = _restRemaining(
                    params.token0,
                    params.token1,
                    params.epoch,
                    routedBookId,
                    routedBook,
                    routedNonce == 0,
                    limitPrice,
                    remaining,
                    false
                );
                token0Delta -= int256(uint256(remaining));
            }
        }
    }

    /// @notice Execute one `fillRoute` leg and merge its deltas into route transient storage.
    /// @param params Fill parameters for the leg.
    /// @param config Packed fee configuration loaded once by `fillRoute`.
    /// @param route In-memory touched-token accumulator.
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

    /// @notice Match against an initialized routed book, or validate an order that may only rest.
    /// @param params Fill parameters.
    /// @param routedBookId Book id derived from `params`.
    /// @param routedBook Storage pointer for `routedBookId`.
    /// @param routedNonceAndFlags Packed nonce/flags loaded before matching.
    /// @return limitPrice Decoded incoming price.
    /// @return remaining Incoming base quantity left after matching.
    /// @return baseFilled Base quantity matched.
    /// @return quoteAmount Quote value matched.
    /// @dev
    /// A zero nonce means the routed book does not exist. That is valid only when the order is
    /// allowed to rest, because no matching can occur in an uninitialized book. If the book exists,
    /// hook handling is enabled only for the opposite side whose top order may change.
    function _matchOrValidate(
        FillParams calldata params,
        bytes32 routedBookId,
        Book storage routedBook,
        uint256 routedNonceAndFlags
    ) private returns (int32 limitPrice, uint160 remaining, uint160 baseFilled, uint256 quoteAmount) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 routedNonce = uint32(routedNonceAndFlags);
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

    /// @notice Rest unmatched quantity in an eligible routed book.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @param routedEpoch Epoch requested by the fill leg.
    /// @param routedBookId Book id requested by the fill leg.
    /// @param routedBook Storage pointer for `routedBookId`.
    /// @param routedBookWasEmpty True when matching skipped because the routed book nonce was zero.
    /// @param limitPrice Incoming limit price.
    /// @param remaining Unmatched base quantity.
    /// @param isBid True to rest as a bid, false to rest as an ask.
    /// @return restingOrder Packed order with assigned nonce.
    /// @dev
    /// An initialized routed book reaches this function only while it has nonce space. A nonce-one
    /// book is filtered by `_executeFill` and is automatically no-rest. An uninitialized routed
    /// book may initialize only when its epoch is the pool's active epoch.
    function _restRemaining(
        address token0,
        address token1,
        uint256 routedEpoch,
        bytes32 routedBookId,
        Book storage routedBook,
        bool routedBookWasEmpty,
        int32 limitPrice,
        uint160 remaining,
        bool isBid
    ) private returns (bytes32 restingOrder) {
        bytes32 restBookId = routedBookId;
        Book storage restBook = routedBook;
        uint256 restNonceAndFlags;
        if (routedBookWasEmpty) {
            restNonceAndFlags = _initializeRoutedBook(token0, token1, routedEpoch, routedBookId);
        } else {
            restNonceAndFlags = routedBook.nonceAndFlags;
        }
        uint32 nextNonceAfter;
        bool hookEnabled = _bookHookEnabled(restNonceAndFlags, isBid);
        (restingOrder, nextNonceAfter) = _restSelectedBook(
            token0, token1, restBookId, restBook, restNonceAndFlags, limitPrice, remaining, isBid, hookEnabled
        );
        if (nextNonceAfter == 1) _rotateIfExhausted(token0, token1);
    }

    /// @notice Rest into a concrete book and execute a top-order hook if resting changed the top.
    /// @return restingOrder Packed order with assigned nonce.
    /// @return nextNonceAfter Book nonce after assignment.
    function _restSelectedBook(
        address token0,
        address token1,
        bytes32 id,
        Book storage book,
        uint256 nonceAndFlags,
        int32 limitPrice,
        uint160 remaining,
        bool isBid,
        bool hookEnabled
    ) private returns (bytes32 restingOrder, uint32 nextNonceAfter) {
        (restingOrder, nextNonceAfter) =
            _restBook(id, book, nonceAndFlags, limitPrice, remaining, isBid, msg.sender, hookEnabled);
        if (hookEnabled) _executeTopOrderHook(token0, token1, id, isBid);
    }

    /// @notice Prepare nonce and hook flags for an empty routed book.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @param routedEpoch Epoch requested by the fill leg.
    /// @param routedBookId Book id requested by the fill leg.
    /// @return nonceAndFlags Packed nonce/flags to pass into `_restBook`.
    /// @dev
    /// A zero-nonce routed book can initialize only if its epoch is currently active. Historical
    /// nonce-one books never reach this helper because `_executeFill` makes them no-rest.
    function _initializeRoutedBook(address token0, address token1, uint256 routedEpoch, bytes32 routedBookId)
        private
        returns (uint256 nonceAndFlags)
    {
        bytes32 pid = poolId(token0, token1);
        uint256 poolState = _poolEpochAndHookFlags[pid];
        uint256 epoch = _poolEpoch(poolState);
        if (routedEpoch != epoch) revert InvalidBook();

        uint256 bookHookFlags = 0;
        if (poolState & _POOL_HOOK_ACTIVE_MASK != 0) bookHookFlags = _bookHookFlags(poolState);
        nonceAndFlags = uint256(type(uint32).max) | bookHookFlags;
        emit BookInitialized(pid, routedBookId, epoch);
    }

    /// @notice Rotate a pool immediately after a rest consumes the final assignable nonce.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @dev
    /// The order that receives nonce `2` leaves `nextNonce == 1`; that exhausted book remains
    /// matchable and cancelable, but later fills against it are automatically no-rest. A caller must
    /// route a separate leg to the next active epoch to create maker liquidity. Hook flags are
    /// removed from the old book and copied into the newly initialized book.
    function _rotateIfExhausted(address token0, address token1) private {
        bytes32 pid = poolId(token0, token1);
        uint256 poolState = _poolEpochAndHookFlags[pid];
        uint256 oldEpoch = _poolEpoch(poolState);
        if (oldEpoch == _POOL_EPOCH_MASK) revert EpochExhausted();
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

    /// @notice Consume transient top-change data and call the configured pool hook if needed.
    /// @param token0 Lower token address.
    /// @param token1 Higher token address.
    /// @param id Book id where the top change occurred.
    /// @param isBid True if the bid-side top order changed, false for ask-side.
    /// @dev
    /// Matching/resting code records only the outgoing leaf and incoming nonce. This function adds
    /// pool/book context and converts the leaf into sold-token units at the top layer. Hook failures
    /// are intentionally swallowed so a bad hook implementation cannot block the matching engine.
    function _executeTopOrderHook(address token0, address token1, bytes32 id, bool isBid) private {
        (bytes32 outgoingOrder, uint32 incomingNonce) = _takeTopOrderChange();
        if (outgoingOrder == bytes32(0) && incomingNonce == 0) return;

        bytes32 pid = poolId(token0, token1);
        address hook = poolHook[pid];
        if (hook == address(0)) return;

        address token = isBid ? token1 : token0;
        uint160 outgoingAmount = _hookAmount(outgoingOrder, isBid);
        // A gas cap makes the best-effort guarantee meaningful for a hook that loops or otherwise
        // consumes all gas. Reverts and out-of-gas inside this bounded call are intentionally ignored.
        // slither-disable-next-line calls-loop
        try IHook(hook).execute{gas: _HOOK_GAS_LIMIT}(pid, id, token, outgoingAmount, incomingNonce) {} catch {}
    }

    /// @notice Convert one live order into the collateral amount it is offering to sell.
    /// @dev Bids sell quote (`token1`) and asks sell base (`token0`). Saturation is sufficient for
    /// bounded reward thresholds while avoiding a hook ABI expansion for extreme quote values.
    function _hookAmount(bytes32 order, bool isBid) private pure returns (uint160 amount) {
        if (order == bytes32(0)) return 0;
        if (!isBid) return _quantity(order);

        uint256 quoteAmount = _quoteValue(_price(order), _quantity(order), true);
        // The preceding comparison proves the quote amount fits in 160 bits.
        // forge-lint: disable-next-line(unsafe-typecast)
        return quoteAmount > type(uint160).max ? type(uint160).max : uint160(quoteAmount);
    }

    // slither-disable-end reentrancy-no-eth,reentrancy-benign

    /// @notice Extract the active epoch from a packed pool state word.
    function _poolEpoch(uint256 poolState) private pure returns (uint256) {
        return poolState & _POOL_EPOCH_MASK;
    }

    /// @notice Replace the epoch bits in a packed pool state while preserving hook flags.
    function _withPoolEpoch(uint256 poolState, uint256 epoch) private pure returns (uint256) {
        return (poolState & _POOL_HOOK_ACTIVE_MASK) | epoch;
    }

    /// @notice Return whether a book has hooks enabled for the side whose top may change.
    /// @param nonceAndFlags Book nonce/flags word.
    /// @param isBid True for token0 buyers/top bids, false for token1 buyers/top asks.
    function _bookHookEnabled(uint256 nonceAndFlags, bool isBid) private pure returns (bool) {
        uint256 flag = isBid ? _BOOK_HOOK_TOKEN0_ACTIVE : _BOOK_HOOK_TOKEN1_ACTIVE;
        return nonceAndFlags & flag != 0;
    }

    /// @notice Convert book hook bits into compact cancel flags used by the inherited engine.
    function _cancelHookFlags(uint256 nonceAndFlags) private pure returns (uint256 flags) {
        if (nonceAndFlags & _BOOK_HOOK_TOKEN0_ACTIVE != 0) flags |= _CANCEL_HOOK_BID;
        if (nonceAndFlags & _BOOK_HOOK_TOKEN1_ACTIVE != 0) flags |= _CANCEL_HOOK_ASK;
    }

    /// @notice Return whether canceling this side should emit a top-order hook.
    function _cancelHookEnabled(uint256 hookFlags, bool isBid) private pure returns (bool) {
        uint256 flag = isBid ? _CANCEL_HOOK_BID : _CANCEL_HOOK_ASK;
        return hookFlags & flag != 0;
    }

    /// @notice Convert pool hook activation bits into the corresponding book-local bits.
    function _bookHookFlags(uint256 poolState) private pure returns (uint256 flags) {
        if (poolState & _POOL_HOOK_TOKEN0_ACTIVE != 0) flags |= _BOOK_HOOK_TOKEN0_ACTIVE;
        if (poolState & _POOL_HOOK_TOKEN1_ACTIVE != 0) flags |= _BOOK_HOOK_TOKEN1_ACTIVE;
    }

    /// @notice Update a book's hook activation bits without touching nonce or right-spine flags.
    function _setBookHookFlags(Book storage book, uint256 flags) private {
        uint256 nonceAndFlags = book.nonceAndFlags;
        uint256 nextNonceAndFlags = (nonceAndFlags & ~_BOOK_HOOK_ACTIVE_MASK) | flags;
        if (nextNonceAndFlags != nonceAndFlags) book.nonceAndFlags = nextNonceAndFlags;
    }

    /// @notice Initialize a new book with nonce max and inherited hook flags.
    function _initializeBookWithHookFlags(Book storage book, uint256 flags) private {
        if (_nextNonce(book) != 0) return;
        book.nonceAndFlags = uint256(type(uint32).max) | flags;
    }

    /// @notice Require canonical sorted token addresses; `address(0)` is native ETH and can only be token0.
    /// @dev Token code existence is intentionally not checked; deployers decide which ERC20s are supported.
    function _requireSortedTokens(address token0, address token1) internal pure virtual {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(lt(token0, token1)) {
                mstore(0x00, 0xc1ab6dc1) // `InvalidToken()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Add a signed user settlement amount to transient storage.
    /// @param token Token whose net user delta changes.
    /// @param amount Signed caller-relative delta.
    /// @param touched Deduplicated in-memory token list.
    /// @param touchedCount Number of populated entries in `touched`.
    /// @return Updated touched count.
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

    /// @notice Add a protocol fee amount to transient storage.
    /// @param token Token collected as a fee.
    /// @param amount Fee amount.
    /// @param touched Deduplicated in-memory fee-token list.
    /// @param touchedCount Number of populated entries in `touched`.
    /// @return Updated touched count.
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

    /// @notice Return whether a token is already in a touched-token list.
    function _isTouched(address token, address[] memory touched, uint256 touchedCount) private pure returns (bool) {
        for (uint256 i; i < touchedCount;) {
            if (touched[i] == token) return true;
            unchecked {
                ++i;
            }
        }
        return false;
    }

    /// @notice Convert an unsigned outgoing amount into a positive signed settlement delta.
    function _creditDelta(uint256 amount) private pure returns (int256) {
        if (amount > uint256(type(int256).max)) revert DeltaOverflow();
        // forge-lint: disable-next-line(unsafe-typecast)
        return int256(amount);
    }

    /// @notice Subtract an unsigned incoming amount from a signed settlement delta.
    function _debitDelta(int256 current, uint256 amount) private pure returns (int256) {
        if (amount > uint256(type(int256).max)) revert DeltaOverflow();
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 signedAmount = int256(amount);
        if (current < type(int256).min + signedAmount) revert DeltaOverflow();
        return current - signedAmount;
    }

    /// @notice Settle route user deltas after all route legs have completed.
    /// @dev
    /// Positive deltas are paid first, then negative deltas are pulled. Since all route state
    /// mutations already happened and the function is reentrancy-guarded, this keeps user-facing
    /// accounting easy to reason about while still clearing transient slots as each token settles.
    function _settleTouched(address[] memory touched, uint256 touchedCount) private returns (uint256 nativeRefund) {
        int256 nativeDelta;
        assembly {
            nativeDelta := tload(0)
        }
        nativeRefund = _nativeRefund(nativeDelta);

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
                _safeTransferOut(token, msg.sender, uint256(amount));
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
                if (token != address(0)) {
                    // forge-lint: disable-next-line(unsafe-typecast)
                    token.safeTransferFrom(msg.sender, address(this), uint256(-amount));
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Settle one non-routed fill's signed token deltas.
    /// @dev Same transfer ordering as route settlement: pay outgoing tokens before pulling inputs.
    function _settleDeltas(address token0, int256 amount0, address token1, int256 amount1)
        private
        returns (uint256 nativeRefund)
    {
        nativeRefund = _nativeRefund(token0 == address(0) ? amount0 : int256(0));

        if (amount0 > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            _safeTransferOut(token0, msg.sender, uint256(amount0));
        }
        if (amount1 > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token1.safeTransfer(msg.sender, uint256(amount1));
        }
        if (amount0 < 0 && token0 != address(0)) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token0.safeTransferFrom(msg.sender, address(this), uint256(-amount0));
        }
        if (amount1 < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token1.safeTransferFrom(msg.sender, address(this), uint256(-amount1));
        }
    }

    /// @notice Transfer accumulated route protocol fees to the configured recipient.
    /// @dev Fees are settled after user deltas so caller accounting is not interleaved with protocol skim.
    function _settleFees(address recipient, address[] memory touched, uint256 touchedCount) private {
        for (uint256 i; i < touchedCount;) {
            address token = touched[i];
            bytes32 slot = _feeSlot(token);
            uint256 amount;
            assembly {
                amount := tload(slot)
                tstore(slot, 0)
            }

            if (amount != 0) _safeTransferOut(token, recipient, amount);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Carve protocol fee from the taker's outgoing matched token.
    /// @param isBid True when the taker is buying token0; fee is taken from positive token0 output.
    /// @param token0Delta Caller-relative token0 delta before fee.
    /// @param token1Delta Caller-relative token1 delta before fee.
    /// @param feeBps Fee rate in basis points.
    /// @return nextToken0Delta Caller-relative token0 delta after fee.
    /// @return nextToken1Delta Caller-relative token1 delta after fee.
    /// @return feeAmount Amount to pay to the fee recipient.
    /// @dev Rested collateral is not charged directly. Fees apply only to positive matched output.
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
            feeAmount = _feeAmount(uint256(token0Delta), feeBps);
            // forge-lint: disable-next-line(unsafe-typecast)
            nextToken0Delta = token0Delta - int256(feeAmount);
        } else {
            if (token1Delta <= 0) return (token0Delta, token1Delta, 0);
            // forge-lint: disable-next-line(unsafe-typecast)
            feeAmount = _feeAmount(uint256(token1Delta), feeBps);
            // forge-lint: disable-next-line(unsafe-typecast)
            nextToken1Delta = token1Delta - int256(feeAmount);
        }
    }

    /// @dev Return `floor(amount * feeBps / 10_000)` without overflowing for signed-delta-sized amounts.
    function _feeAmount(uint256 amount, uint16 feeBps) private pure returns (uint256 feeAmount) {
        // This quotient/remainder decomposition is exactly equivalent to multiplying first, but it
        // avoids overflowing when `amount` is near int256.max.
        // slither-disable-next-line divide-before-multiply
        uint256 whole = amount / _BPS_DENOMINATOR;
        uint256 remainder = amount % _BPS_DENOMINATOR;
        // `feeBps <= 100`: each multiplication is bounded even when `amount` is int256.max.
        feeAmount = whole * uint256(feeBps) + (remainder * uint256(feeBps)) / _BPS_DENOMINATOR;
    }

    /// @notice Transient storage slot for protocol fees in one token.
    function _feeSlot(address token) private pure returns (bytes32) {
        return bytes32(_FEE_DELTA_DOMAIN | uint256(uint160(token)));
    }

    /// @notice Validate the caller's net native ETH debit and return any excess value.
    /// @dev A positive or zero caller-relative delta requires no ETH, so all `msg.value` is excess.
    function _nativeRefund(int256 nativeDelta) private view returns (uint256 refund) {
        uint256 required;
        if (nativeDelta < 0) {
            /// @solidity memory-safe-assembly
            assembly {
                required := sub(0, nativeDelta)
            }
        }
        if (msg.value < required) revert InvalidNativeValue();
        unchecked {
            refund = msg.value - required;
        }
    }

    /// @notice Return native ETH supplied above the caller's net debit.
    function _refundNativeValue(uint256 amount) private {
        if (amount != 0) _safeTransferOut(address(0), msg.sender, amount);
    }

    /// @notice Pay either native ETH (`token == address(0)`) or an ERC20.
    function _safeTransferOut(address token, address to, uint256 amount) private {
        if (token == address(0)) {
            to.safeTransferETH(amount);
        } else {
            token.safeTransfer(to, amount);
        }
    }
}
