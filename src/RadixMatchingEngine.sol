// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
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
/// and side metadata live in `ownerOfOrder`.
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
contract RadixMatchingEngine {
    using SafeTransferLib for address;

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

    /// @notice Shared branch storage for both bid and ask trees.
    /// @dev
    /// This is the only tree mapping. `bidRoot` and `askRoot` select which conceptual tree is being
    /// walked. Branch keys are self-addressed by their aggregate node word, so the mapping only
    /// needs to hold child pointers.
    mapping(bytes32 => Branch) public tree;

    /// @notice Owner lookup by order node. Zero-quantity keys store side metadata for claims.
    /// @dev
    /// For every active maker order, the original nonzero-quantity order key maps to its owner.
    /// A companion zero-quantity key with the same price and nonce maps to `_BID_SENTINEL` or
    /// `_ASK_SENTINEL`, which lets `cancel` know which root to search. Fill/cancel state is not
    /// stored separately; it is derived by searching the relevant tree and comparing the remaining
    /// live leaf quantity to the original order quantity.
    mapping(bytes32 order => address owner) public ownerOfOrder;

    /// @notice Root node of the bid tree.
    /// @dev Zero means the bid book is empty. Nonzero can be either a leaf order or a branch.
    bytes32 public bidRoot;

    /// @notice Root node of the ask tree.
    /// @dev Zero means the ask book is empty. Nonzero can be either a leaf order or a branch.
    bytes32 public askRoot;

    /// @notice Decrementing nonce. Higher nonce means earlier time priority at the same price.
    /// @dev
    /// The first resting order receives `type(uint40).max`, then the counter decrements. Nonce zero
    /// is reserved as the exhaustion sentinel and is never assigned to a resting order. Private
    /// right-spine dirty flags live above the low 40 bits in this storage slot; the public getter
    /// still returns only the declared `uint40` nonce.
    uint40 public nextNonce = type(uint40).max;

    /// @notice Token sold by asks and received by bid makers when bids fill.
    address public immutable BASE_TOKEN;
    /// @notice Token sold by bids and received by ask makers when asks fill.
    address public immutable QUOTE_TOKEN;

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
    /// @dev Dirty bit stored above the 40-bit `nextNonce` field when bid right-spine anchors are stale.
    uint256 private constant _BID_RIGHT_SPINE_DIRTY = uint256(1) << 40;
    /// @dev Dirty bit stored above the 40-bit `nextNonce` field when ask right-spine anchors are stale.
    uint256 private constant _ASK_RIGHT_SPINE_DIRTY = uint256(1) << 41;

    /// @dev Side marker stored at `_sideKey(order)` for bid orders.
    address private constant _BID_SENTINEL = address(uint160(1));
    /// @dev Side marker stored at `_sideKey(order)` for ask orders.
    address private constant _ASK_SENTINEL = address(uint160(2));
    /// @dev Transient storage slot used by the custom reentrancy guard.
    bytes32 private constant _REENTRANCY_GUARD_SLOT =
        0xc55a21be1c6e869c49c7a5860f6c3a83187eb30a12bcd0421f3cf4f5871dccff;

    /// @notice Emitted when unmatched quantity becomes a resting maker order.
    /// @param order Packed resting order node with contract-assigned nonce.
    /// @param owner Maker that owns the resting order.
    /// @param isBid True for a bid resting in the bid tree, false for an ask resting in the ask tree.
    event OrderRested(bytes32 indexed order, address indexed owner, bool indexed isBid);

    /// @notice Matched resting liquidity. The resting node can be a leaf order or a same-price branch aggregate.
    /// @param restingNode Leaf or same-price aggregate branch consumed by the incoming order.
    /// @param restingIsBid True if the consumed liquidity came from the bid tree.
    /// @param quantity Base quantity matched from the resting liquidity.
    /// @param quoteAmount Quote value of the matched quantity at the resting price.
    event OrderMatched(bytes32 indexed restingNode, bool indexed restingIsBid, uint192 quantity, uint256 quoteAmount);

    /// @notice Emitted when a maker cancels open quantity or claims filled proceeds.
    /// @param order Original packed resting order node.
    /// @param owner Maker that owned the order.
    /// @param baseAmount Base tokens returned or paid to the maker.
    /// @param quoteAmount Quote tokens returned or paid to the maker.
    event OrderCancelled(bytes32 indexed order, address indexed owner, uint256 baseAmount, uint256 quoteAmount);

    /// @notice Token configuration is invalid.
    error InvalidToken();
    /// @notice Order fields are invalid for the requested operation.
    error InvalidOrder();
    /// @notice The decrementing 40-bit nonce space has been exhausted.
    error NonceExhausted();
    /// @notice A duplicate price/nonce path was encountered.
    error DuplicateOrder();
    /// @notice Caller is not the owner recorded for the original order key.
    error NotOrderOwner();
    /// @notice Owner exists, but side metadata needed to route cancellation is missing or corrupt.
    error OrderNotFound();
    /// @notice Reentrant call attempted while `fill` or `cancel` is executing.
    error ReentrantCall();

    /// @dev Guards external entrypoints through transient storage.
    modifier nonReentrant() {
        _enter();
        _;
        _exit();
    }

    /// @notice Deploy an engine for one base/quote token pair.
    /// @param baseToken_ Base token address.
    /// @param quoteToken_ Quote token address.
    /// @dev Both tokens must be nonzero, distinct contracts.
    constructor(address baseToken_, address quoteToken_) {
        if (
            baseToken_ == address(0) || quoteToken_ == address(0) || baseToken_ == quoteToken_
                || baseToken_.code.length == 0 || quoteToken_.code.length == 0
        ) {
            revert InvalidToken();
        }
        BASE_TOKEN = baseToken_;
        QUOTE_TOKEN = quoteToken_;
    }

    /// @notice Submit a bid or ask. Any unfilled quantity rests on that side of the book.
    /// @param order Packed incoming order with price and quantity set, nonce bits set to zero.
    /// @param isBid True for a bid, false for an ask.
    /// @return restingOrder Packed resting order if any quantity remains, otherwise zero.
    /// @dev
    /// Incoming orders must leave the low 40 nonce bits empty; the contract assigns time priority
    /// only to quantities that actually rest.
    ///
    /// Bid flow:
    /// 1. Match against the ask root using the bid limit price.
    /// 2. Rest any remainder in the bid tree.
    /// 3. Pull quote for matched quote value plus remaining bid collateral.
    /// 4. Pay matched base to the taker immediately.
    ///
    /// Ask flow:
    /// 1. Match against the bid root using the ask limit price.
    /// 2. Rest any remainder in the ask tree.
    /// 3. Pull the full base quantity. Matched base remains in the contract for bid maker claims;
    ///    unfilled base collateralizes the resting ask.
    /// 4. Pay matched quote to the taker immediately.
    ///
    /// State changes happen before token transfers, but failed transfers revert the whole call.
    /// The transient reentrancy guard prevents token callbacks from observing or mutating the
    /// intermediate state through `fill` or `cancel`.
    function fill(bytes32 order, bool isBid) external nonReentrant returns (bytes32 restingOrder) {
        (uint24 limitPrice, uint192 quantity) = _priceAndQuantity(order);
        if (limitPrice == 0 || quantity == 0 || uint256(order) & _NONCE_MASK != 0) revert InvalidOrder();

        uint192 remaining = quantity;
        uint192 baseFilled = 0;
        uint256 quoteAmount = 0;

        if (isBid) {
            bytes32 root = askRoot;
            if (root != bytes32(0)) {
                bytes32 newRoot;
                (newRoot, remaining, baseFilled, quoteAmount) = _matchAskTree(root, limitPrice, remaining);
                if (newRoot != root) askRoot = newRoot;
            }

            uint256 quoteCollateral = quoteAmount;
            if (remaining != 0) {
                restingOrder = _restBid(limitPrice, remaining);
                unchecked {
                    quoteCollateral += _quoteValue(limitPrice, remaining);
                }
            }

            QUOTE_TOKEN.safeTransferFrom(msg.sender, address(this), quoteCollateral);
            if (baseFilled != 0) BASE_TOKEN.safeTransfer(msg.sender, baseFilled);
        } else {
            bytes32 root = bidRoot;
            if (root != bytes32(0)) {
                bytes32 newRoot;
                (newRoot, remaining, baseFilled, quoteAmount) = _matchBidTree(root, limitPrice, remaining);
                if (newRoot != root) bidRoot = newRoot;
            }

            if (remaining != 0) {
                restingOrder = _restAsk(limitPrice, remaining);
            }

            BASE_TOKEN.safeTransferFrom(msg.sender, address(this), quantity);
            if (quoteAmount != 0) QUOTE_TOKEN.safeTransfer(msg.sender, quoteAmount);
        }
    }

    /// @notice Cancel an open order or claim a filled order.
    /// @param order Original packed resting order returned by `fill`.
    /// @return baseAmount Base tokens paid to the maker.
    /// @return quoteAmount Quote tokens paid to the maker.
    /// @dev
    /// `cancel` is also the asynchronous claim path. The original order key always stores the
    /// owner while active, even if the live leaf has been partially filled and now has a different
    /// quantity. The side marker at `_sideKey(order)` tells the function which root to search.
    ///
    /// - If the order is absent from the tree, it has fully filled and the maker claims proceeds.
    /// - If a live leaf with the same price/nonce exists, its quantity is returned/canceled and the
    ///   difference between original and remaining quantity is claimed as filled proceeds.
    ///
    /// The owner and side marker are deleted before payout. If a token transfer reverts, the whole
    /// transaction reverts and the claim remains live.
    function cancel(bytes32 order) external nonReentrant returns (uint256 baseAmount, uint256 quoteAmount) {
        uint192 originalQuantity = _quantity(order);
        if (originalQuantity == 0) revert InvalidOrder();

        address owner = ownerOfOrder[order];
        if (owner != msg.sender) revert NotOrderOwner();

        bool isBid = false;
        uint192 remainingQuantity = 0;
        bytes32 removed = bytes32(0);
        bytes32 sideKey = _sideKey(order);
        address marker = ownerOfOrder[sideKey];
        if (marker == _BID_SENTINEL) {
            isBid = true;
        } else if (marker != _ASK_SENTINEL) {
            revert OrderNotFound();
        }

        if (isBid) {
            bytes32 root = bidRoot;
            bytes32 newRoot;
            if (root != bytes32(0)) {
                (newRoot, removed) = _removeBidByKey(root, _bidSortKey(order), true);
                if (removed != bytes32(0) && newRoot != root) {
                    bidRoot = newRoot;
                }
            }
        } else {
            bytes32 root = askRoot;
            bytes32 newRoot;
            if (root != bytes32(0)) {
                (newRoot, removed) = _removeAskByKey(root, _askSortKey(order), true);
                if (removed != bytes32(0) && newRoot != root) {
                    askRoot = newRoot;
                }
            }
        }

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

        delete ownerOfOrder[order];
        delete ownerOfOrder[sideKey];

        if (baseAmount != 0) BASE_TOKEN.safeTransfer(owner, baseAmount);
        if (quoteAmount != 0) QUOTE_TOKEN.safeTransfer(owner, quoteAmount);

        emit OrderCancelled(order, owner, baseAmount, quoteAmount);
    }

    /// @notice Rest unmatched bid quantity in the bid tree.
    /// @param price Bid limit price.
    /// @param quantity Unfilled base quantity to rest.
    /// @return restingOrder Packed resting bid with assigned nonce.
    /// @dev Stores both owner and side marker before insertion. A revert during insertion rolls the
    /// entire rest operation back, including nonce decrement and metadata writes.
    function _restBid(uint24 price, uint192 quantity) private returns (bytes32 restingOrder) {
        if (_rightSpineDirty(true)) {
            bidRoot = _materializeRightSpine(bidRoot);
            _clearRightSpineDirty(true);
        }

        uint40 nonce = nextNonce;
        if (nonce == 0) revert NonceExhausted();
        unchecked {
            nextNonce = nonce - 1;
        }

        restingOrder = _pack(price, quantity, nonce);
        ownerOfOrder[restingOrder] = msg.sender;
        ownerOfOrder[_sideKey(restingOrder)] = _BID_SENTINEL;
        bidRoot = _insertBid(bidRoot, restingOrder, (uint64(price) << 40) | uint64(nonce));

        emit OrderRested(restingOrder, msg.sender, true);
    }

    /// @notice Rest unmatched ask quantity in the ask tree.
    /// @param price Ask limit price.
    /// @param quantity Unfilled base quantity to rest.
    /// @return restingOrder Packed resting ask with assigned nonce.
    /// @dev Uses an inverted price sort key so lower ask prices live on the rightmost path.
    function _restAsk(uint24 price, uint192 quantity) private returns (bytes32 restingOrder) {
        if (_rightSpineDirty(false)) {
            askRoot = _materializeRightSpine(askRoot);
            _clearRightSpineDirty(false);
        }

        uint40 nonce = nextNonce;
        if (nonce == 0) revert NonceExhausted();
        unchecked {
            nextNonce = nonce - 1;
        }

        restingOrder = _pack(price, quantity, nonce);
        ownerOfOrder[restingOrder] = msg.sender;
        ownerOfOrder[_sideKey(restingOrder)] = _ASK_SENTINEL;
        unchecked {
            askRoot = _insertAsk(askRoot, restingOrder, (uint64(_MAX_PRICE - price) << 40) | uint64(nonce));
        }

        emit OrderRested(restingOrder, msg.sender, false);
    }

    /// @notice Match an incoming bid against the ask tree.
    /// @param root Current ask root.
    /// @param limitPrice Bid limit price.
    /// @param remaining Incoming base quantity remaining before matching.
    /// @return newRoot Updated ask root.
    /// @return newRemaining Incoming quantity left after matching.
    /// @return baseFilled Base quantity paid to the bid taker.
    /// @return quoteAmount Quote value owed by the bid taker for matched asks.
    function _matchAskTree(bytes32 root, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        (newRoot, baseFilled, quoteAmount) = _matchAskRightSpine(root, limitPrice, remaining, _rightSpineDirty(false));
        unchecked {
            newRemaining = remaining - baseFilled;
        }
    }

    /// @notice Match an incoming ask against the bid tree.
    /// @param root Current bid root.
    /// @param limitPrice Ask limit price.
    /// @param remaining Incoming base quantity remaining before matching.
    /// @return newRoot Updated bid root.
    /// @return newRemaining Incoming quantity left after matching.
    /// @return baseFilled Base quantity sold into resting bids.
    /// @return quoteAmount Quote value paid to the ask taker.
    function _matchBidTree(bytes32 root, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        (newRoot, baseFilled, quoteAmount) = _matchBidRightSpine(root, limitPrice, remaining, _rightSpineDirty(true));
        unchecked {
            newRemaining = remaining - baseFilled;
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
    function _matchAskLeaf(bytes32 root, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        (uint24 restingPrice, uint192 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice > limitPrice) return (root, remaining, 0, 0);

        uint192 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteValue(restingPrice, fillQuantity);

        emit OrderMatched(root, false, fillQuantity, quoteAmount);

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
    function _matchBidLeaf(bytes32 root, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        (uint24 restingPrice, uint192 restingQuantity) = _priceAndQuantity(root);
        if (restingPrice < limitPrice) return (root, remaining, 0, 0);

        uint192 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteValue(restingPrice, fillQuantity);

        emit OrderMatched(root, true, fillQuantity, quoteAmount);

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
    function _matchAskRightSpine(bytes32 node, uint24 limitPrice, uint192 remaining, bool dirty)
        private
        returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        bytes32 rightNode = tree[node].rightNode;
        if (_price(leftNode) == _price(rightNode)) {
            fillQuantity = _samePriceRightSpineFillQuantity(node, limitPrice, remaining, false, dirty);
            if (fillQuantity != 0) {
                quoteAmount = _quoteValue(_price(node), fillQuantity);
                emit OrderMatched(dirty ? _withQuantity(node, fillQuantity) : node, false, fillQuantity, quoteAmount);
                return (bytes32(0), fillQuantity, quoteAmount);
            }
        }

        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        (newRightNode, rightFillQuantity, rightQuoteAmount) =
            _matchAskRightSpine(rightNode, limitPrice, remaining, dirty);
        if (rightFillQuantity == 0) return (node, 0, 0);

        uint192 leftFillQuantity = 0;
        uint256 leftQuoteAmount = 0;
        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, leftFillQuantity, leftQuoteAmount) = _matchAskSubtree(leftNode, limitPrice, remaining);
        }

        newNode = leftFillQuantity == 0
            ? _replaceRightmostRightChild(node, newLeftNode, newRightNode, false)
            : _replaceBranch(newLeftNode, newRightNode);
        unchecked {
            fillQuantity = rightFillQuantity + leftFillQuantity;
            quoteAmount = rightQuoteAmount + leftQuoteAmount;
        }
    }

    /// @notice Recursively match an incoming bid against an exact ask subtree.
    /// @param node Ask leaf or exact aggregate branch to inspect.
    /// @param limitPrice Bid limit price.
    /// @param remaining Incoming bid quantity available to spend in this subtree.
    /// @return newNode Replacement node for this subtree after matching.
    /// @return fillQuantity Base quantity consumed from this subtree.
    /// @return quoteAmount Quote value consumed from this subtree.
    function _matchAskSubtree(bytes32 node, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchAskLeaf(node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        uint192 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(node) <= limitPrice) {
            quoteAmount = _consumeSubtree(node, false);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 rightNode = tree[node].rightNode;
        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        (newRightNode, rightFillQuantity, rightQuoteAmount) = _matchAskSubtree(rightNode, limitPrice, remaining);
        if (rightFillQuantity == 0) return (node, 0, 0);

        uint192 leftFillQuantity = 0;
        uint256 leftQuoteAmount = 0;
        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, leftFillQuantity, leftQuoteAmount) = _matchAskSubtree(leftNode, limitPrice, remaining);
        }

        newNode = _replaceBranch(newLeftNode, newRightNode);
        unchecked {
            fillQuantity = rightFillQuantity + leftFillQuantity;
            quoteAmount = rightQuoteAmount + leftQuoteAmount;
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
    function _matchBidRightSpine(bytes32 node, uint24 limitPrice, uint192 remaining, bool dirty)
        private
        returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        bytes32 rightNode = tree[node].rightNode;
        if (_price(leftNode) == _price(rightNode)) {
            fillQuantity = _samePriceRightSpineFillQuantity(node, limitPrice, remaining, true, dirty);
            if (fillQuantity != 0) {
                quoteAmount = _quoteValue(_price(node), fillQuantity);
                emit OrderMatched(dirty ? _withQuantity(node, fillQuantity) : node, true, fillQuantity, quoteAmount);
                return (bytes32(0), fillQuantity, quoteAmount);
            }
        }

        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        (newRightNode, rightFillQuantity, rightQuoteAmount) =
            _matchBidRightSpine(rightNode, limitPrice, remaining, dirty);
        if (rightFillQuantity == 0) return (node, 0, 0);

        uint192 leftFillQuantity = 0;
        uint256 leftQuoteAmount = 0;
        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, leftFillQuantity, leftQuoteAmount) = _matchBidSubtree(leftNode, limitPrice, remaining);
        }

        newNode = leftFillQuantity == 0
            ? _replaceRightmostRightChild(node, newLeftNode, newRightNode, true)
            : _replaceBranch(newLeftNode, newRightNode);
        unchecked {
            fillQuantity = rightFillQuantity + leftFillQuantity;
            quoteAmount = rightQuoteAmount + leftQuoteAmount;
        }
    }

    /// @notice Recursively match an incoming ask against an exact bid subtree.
    /// @param node Bid leaf or exact aggregate branch to inspect.
    /// @param limitPrice Ask limit price.
    /// @param remaining Incoming ask quantity available to sell in this subtree.
    /// @return newNode Replacement node for this subtree after matching.
    /// @return fillQuantity Base quantity consumed from this subtree.
    /// @return quoteAmount Quote value consumed from this subtree.
    function _matchBidSubtree(bytes32 node, uint24 limitPrice, uint192 remaining)
        private
        returns (bytes32 newNode, uint192 fillQuantity, uint256 quoteAmount)
    {
        bytes32 leftNode = tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            (newNode,, fillQuantity, quoteAmount) = _matchBidLeaf(node, limitPrice, remaining);
            return (newNode, fillQuantity, quoteAmount);
        }

        uint192 nodeQuantity = _quantity(node);
        if (nodeQuantity <= remaining && _leftmostLeafPrice(node) >= limitPrice) {
            quoteAmount = _consumeSubtree(node, true);
            return (bytes32(0), nodeQuantity, quoteAmount);
        }

        bytes32 rightNode = tree[node].rightNode;
        bytes32 newRightNode;
        uint192 rightFillQuantity;
        uint256 rightQuoteAmount;
        (newRightNode, rightFillQuantity, rightQuoteAmount) = _matchBidSubtree(rightNode, limitPrice, remaining);
        if (rightFillQuantity == 0) return (node, 0, 0);

        uint192 leftFillQuantity = 0;
        uint256 leftQuoteAmount = 0;
        bytes32 newLeftNode = leftNode;
        unchecked {
            remaining -= rightFillQuantity;
        }

        if (remaining != 0) {
            (newLeftNode, leftFillQuantity, leftQuoteAmount) = _matchBidSubtree(leftNode, limitPrice, remaining);
        }

        newNode = _replaceBranch(newLeftNode, newRightNode);
        unchecked {
            fillQuantity = rightFillQuantity + leftFillQuantity;
            quoteAmount = rightQuoteAmount + leftQuoteAmount;
        }
    }

    /// @notice Insert a leaf or branch into the bid tree.
    /// @param root Current subtree root.
    /// @param node Node to insert.
    /// @param nodeKey Bid sort key for `node`.
    /// @return Updated subtree root.
    /// @dev
    /// Insertion follows Patricia/radix-tree rules. If the new key diverges before the current
    /// branch split, a new parent branch is created above `root`. Otherwise recursion continues
    /// into the child selected by the branch split bit.
    function _insertBid(bytes32 root, bytes32 node, uint64 nodeKey) private returns (bytes32) {
        if (root == bytes32(0)) return node;

        bytes32 leftNode = tree[root].leftNode;
        if (leftNode == bytes32(0)) return _storeBranch(root, node, _bidSortKey(root), nodeKey);

        bytes32 rightNode = tree[root].rightNode;
        uint64 leftKey = _bidSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _bidSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            return _storeBranch(root, node, _bidSortKey(root), nodeKey);
        }

        if (_bit(nodeKey, branchDepth)) {
            rightNode = _insertBid(rightNode, node, nodeKey);
        } else {
            leftNode = _insertBid(leftNode, node, nodeKey);
        }

        return _replaceBranch(leftNode, rightNode);
    }

    /// @notice Insert a leaf or branch into the ask tree.
    /// @param root Current subtree root.
    /// @param node Node to insert.
    /// @param nodeKey Ask sort key for `node`.
    /// @return Updated subtree root.
    /// @dev Same insertion algorithm as bids, but callers provide inverted-price ask keys.
    function _insertAsk(bytes32 root, bytes32 node, uint64 nodeKey) private returns (bytes32) {
        if (root == bytes32(0)) return node;

        bytes32 leftNode = tree[root].leftNode;
        if (leftNode == bytes32(0)) return _storeBranch(root, node, _askSortKey(root), nodeKey);

        bytes32 rightNode = tree[root].rightNode;
        uint64 leftKey = _askSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _askSortKey(rightNode));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            return _storeBranch(root, node, _askSortKey(root), nodeKey);
        }

        if (_bit(nodeKey, branchDepth)) {
            rightNode = _insertAsk(rightNode, node, nodeKey);
        } else {
            leftNode = _insertAsk(leftNode, node, nodeKey);
        }

        return _replaceBranch(leftNode, rightNode);
    }

    /// @notice Remove one bid leaf by exact bid sort key.
    /// @param root Current subtree root.
    /// @param targetKey Bid sort key for the original order.
    /// @return newRoot Updated subtree root.
    /// @return removed Live leaf that was removed, or zero if absent.
    /// @dev
    /// Cancel searches by price/nonce, not by full order word, because a partially filled live leaf
    /// has the same price/nonce as the original order but a smaller quantity.
    function _removeBidByKey(bytes32 root, uint64 targetKey, bool rightmost)
        private
        returns (bytes32 newRoot, bytes32 removed)
    {
        if (root == bytes32(0)) return (bytes32(0), bytes32(0));

        bytes32 leftNode = tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            return _bidSortKey(root) == targetKey ? (bytes32(0), root) : (root, bytes32(0));
        }

        bytes32 rightNode = tree[root].rightNode;
        uint64 leftKey = _bidSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _bidSortKey(rightNode));
        if (_commonPrefix(targetKey, leftKey) < branchDepth) return (root, bytes32(0));

        if (_bit(targetKey, branchDepth)) {
            (rightNode, removed) = _removeBidByKey(rightNode, targetKey, rightmost);
        } else {
            (leftNode, removed) = _removeBidByKey(leftNode, targetKey, false);
        }

        if (removed == bytes32(0)) return (root, bytes32(0));
        if (rightmost && _bit(targetKey, branchDepth)) {
            return (_replaceRightmostRightChild(root, leftNode, rightNode, true), removed);
        }
        return (_replaceBranch(leftNode, rightNode), removed);
    }

    /// @notice Remove one ask leaf by exact ask sort key.
    /// @param root Current subtree root.
    /// @param targetKey Ask sort key for the original order.
    /// @return newRoot Updated subtree root.
    /// @return removed Live leaf that was removed, or zero if absent.
    /// @dev Mirrors `_removeBidByKey` using inverted-price ask keys.
    function _removeAskByKey(bytes32 root, uint64 targetKey, bool rightmost)
        private
        returns (bytes32 newRoot, bytes32 removed)
    {
        if (root == bytes32(0)) return (bytes32(0), bytes32(0));

        bytes32 leftNode = tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            return _askSortKey(root) == targetKey ? (bytes32(0), root) : (root, bytes32(0));
        }

        bytes32 rightNode = tree[root].rightNode;
        uint64 leftKey = _askSortKey(leftNode);
        uint8 branchDepth = _commonPrefix(leftKey, _askSortKey(rightNode));
        if (_commonPrefix(targetKey, leftKey) < branchDepth) return (root, bytes32(0));

        if (_bit(targetKey, branchDepth)) {
            (rightNode, removed) = _removeAskByKey(rightNode, targetKey, rightmost);
        } else {
            (leftNode, removed) = _removeAskByKey(leftNode, targetKey, false);
        }

        if (removed == bytes32(0)) return (root, bytes32(0));
        if (rightmost && _bit(targetKey, branchDepth)) {
            return (_replaceRightmostRightChild(root, leftNode, rightNode, false), removed);
        }
        return (_replaceBranch(leftNode, rightNode), removed);
    }

    /// @notice Update a right-spine branch after only its right child changed.
    /// @param branchNode Existing branch node used as the stable right-spine anchor.
    /// @param leftNode Existing left child.
    /// @param rightNode Replacement right child.
    /// @param isBid True if the branch belongs to the bid tree.
    /// @return Replacement subtree root.
    /// @dev
    /// This is the rightmost-branch optimization. The packed branch word is left in place when the
    /// right child changes, so ancestors on the same right spine do not need to be rewritten. The
    /// branch quantity/path can therefore become stale until the next same-side insertion calls
    /// `_materializeRightSpine`.
    function _replaceRightmostRightChild(bytes32 branchNode, bytes32 leftNode, bytes32 rightNode, bool isBid)
        private
        returns (bytes32)
    {
        if (leftNode == bytes32(0)) return rightNode;
        if (rightNode == bytes32(0)) return leftNode;
        if (rightNode == branchNode || rightNode == leftNode) return _replaceBranch(leftNode, rightNode);

        tree[branchNode].rightNode = rightNode;
        _setRightSpineDirty(isBid);
        return branchNode;
    }

    /// @notice Collapse or rewrite a branch after one or both children changed.
    /// @param leftNode Replacement left child.
    /// @param rightNode Replacement right child.
    /// @return Replacement subtree root.
    /// @dev
    /// If one child was consumed or canceled, the other child is promoted. If both remain, the
    /// branch address is recomputed from the child nodes and its pointers are written. Callers pass
    /// children in already-valid left/right order.
    function _replaceBranch(bytes32 leftNode, bytes32 rightNode) private returns (bytes32) {
        bytes32 newBranch;
        if (leftNode == bytes32(0)) {
            newBranch = rightNode;
        } else if (rightNode == bytes32(0)) {
            newBranch = leftNode;
        } else {
            newBranch = _branchNodeForChildren(leftNode, rightNode);
            // Replacement callers preserve left/right ordering from an existing valid branch.
            tree[newBranch] = Branch({leftNode: leftNode, rightNode: rightNode});
        }

        return newBranch;
    }

    /// @notice Rebuild a previously optimized right spine back into exact aggregate branches.
    /// @param node Current subtree root.
    /// @return Exact subtree root.
    /// @dev Only the right spine can contain stable anchors. Left subtrees remain exact because the
    /// optimization is used only for right-child updates.
    function _materializeRightSpine(bytes32 node) private returns (bytes32) {
        bytes32 leftNode = tree[node].leftNode;
        if (leftNode == bytes32(0)) return node;

        bytes32 rightNode = _materializeRightSpine(tree[node].rightNode);
        return _replaceBranch(leftNode, rightNode);
    }

    /// @notice Return the aggregate quantity for a fully crossing same-price subtree on the global right spine.
    /// @param node Right-spine branch to inspect.
    /// @param limitPrice Incoming order limit price.
    /// @param remaining Incoming base quantity available.
    /// @param restingIsBid True if the resting subtree is from the bid tree.
    /// @param dirty True if right-spine branch words may have stale aggregate quantity/path fields.
    /// @return fillQuantity Actual base quantity consumable as one same-price aggregate, or zero.
    /// @dev
    /// Dirty right-spine anchors keep correct child pointers but stale packed aggregate fields. For
    /// same-price subtrees the quote value is still price * actual quantity, so this helper recovers
    /// the one-event aggregate path without rewriting every ancestor branch. Mixed-price dirty
    /// subtrees intentionally fall back to the recursive matcher because their quote value cannot be
    /// computed from one price.
    function _samePriceRightSpineFillQuantity(
        bytes32 node,
        uint24 limitPrice,
        uint192 remaining,
        bool restingIsBid,
        bool dirty
    ) private view returns (uint192 fillQuantity) {
        uint24 price = _singlePriceSubtree(node);
        if (price == 0) return 0;
        if (restingIsBid ? price < limitPrice : price > limitPrice) return 0;

        fillQuantity = dirty ? _actualSubtreeQuantity(node) : _quantity(node);
        if (fillQuantity > remaining) return 0;
    }

    /// @notice Compute the live leaf quantity under a subtree by following child pointers.
    /// @param node Subtree root.
    /// @return quantity Sum of live leaf quantities.
    /// @dev Used only when a right-spine anchor may be stale and its packed quantity cannot be
    /// trusted. Left subtrees below a dirty right spine are exact, but recursion is simpler and
    /// still bounded by the radix tree depth plus the consumed same-price subtree size.
    function _actualSubtreeQuantity(bytes32 node) private view returns (uint192 quantity) {
        bytes32 leftNode = tree[node].leftNode;
        if (leftNode == bytes32(0)) return _quantity(node);

        quantity = _actualSubtreeQuantity(leftNode);
        unchecked {
            quantity += _actualSubtreeQuantity(tree[node].rightNode);
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
    function _storeBranch(bytes32 a, bytes32 b, uint64 aKey, uint64 bKey) private returns (bytes32 branchNode) {
        if (a == bytes32(0)) return b;
        if (b == bytes32(0)) return a;

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
        tree[branchNode] = Branch({leftNode: leftNode, rightNode: rightNode});
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
    /// @return Packed branch node.
    function _branchNode(uint64 key, uint192 quantity) private pure returns (bytes32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint24 prefixPrice = uint24(key >> 40);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 prefixNonce = uint40(key);
        return _pack(prefixPrice, quantity, prefixNonce);
    }

    /// @notice Return the common price for a subtree, or zero if the subtree spans multiple prices.
    /// @param node Subtree root.
    /// @return price Nonzero common price, or zero as the mixed-price sentinel.
    /// @dev
    /// Price zero is invalid for live orders, so zero is safe as the sentinel. The function only
    /// checks the leftmost and rightmost leaf because branch ordering invariants guarantee every
    /// leaf between them is within that price range.
    function _singlePriceSubtree(bytes32 node) private view returns (uint24 price) {
        bytes32 leftmost = node;
        while (true) {
            bytes32 leftNode = tree[leftmost].leftNode;
            if (leftNode == bytes32(0)) break;
            leftmost = leftNode;
        }

        bytes32 rightmost = node;
        while (true) {
            bytes32 rightNode = tree[rightmost].rightNode;
            if (rightNode == bytes32(0)) break;
            rightmost = rightNode;
        }

        price = _price(leftmost);
        if (price != _price(rightmost)) return 0;
    }

    /// @notice Return the price of the leftmost leaf in a subtree.
    /// @param node Subtree root.
    /// @return price Price of the worst executable leaf in the subtree.
    /// @dev
    /// For bids, the leftmost leaf has the lowest bid price. For asks, the leftmost leaf has the
    /// highest ask price because ask sort keys invert price. In both cases this is the "worst"
    /// price that must cross before an entire subtree can be aggregate-consumed.
    function _leftmostLeafPrice(bytes32 node) private view returns (uint24 price) {
        while (true) {
            bytes32 leftNode = tree[node].leftNode;
            if (leftNode == bytes32(0)) {
                price = _price(node);
                break;
            }
            node = leftNode;
        }
    }

    /// @notice Consume a subtree that has already been proven fully crossing and small enough.
    /// @param node Subtree root.
    /// @param restingIsBid True if the consumed subtree is from the bid tree.
    /// @return quoteAmount Total quote value of the consumed subtree.
    /// @dev
    /// Same-price subtrees can be emitted as one aggregate `OrderMatched` event because every maker
    /// fills at the same price. Mixed-price subtrees recurse right first to preserve execution
    /// priority in emitted match events.
    function _consumeSubtree(bytes32 node, bool restingIsBid) private returns (uint256 quoteAmount) {
        uint192 quantity = _quantity(node);
        bytes32 leftNode = tree[node].leftNode;
        if (leftNode == bytes32(0)) {
            quoteAmount = _quoteValue(_price(node), quantity);
            emit OrderMatched(node, restingIsBid, quantity, quoteAmount);
            return quoteAmount;
        }

        uint24 price = _singlePriceSubtree(node);
        if (price != 0) {
            quoteAmount = _quoteValue(price, quantity);
            emit OrderMatched(node, restingIsBid, quantity, quoteAmount);
            return quoteAmount;
        }

        quoteAmount = _consumeSubtree(tree[node].rightNode, restingIsBid);
        unchecked {
            quoteAmount += _consumeSubtree(leftNode, restingIsBid);
        }
    }

    /// @notice Build the bid sort key from an order or branch node.
    /// @param order Packed node.
    /// @return Bid sort key: `price || nonce`.
    /// @dev Higher keys are better bids: higher price first, then higher nonce for earlier time.
    function _bidSortKey(bytes32 order) private pure returns (uint64) {
        uint256 packed = uint256(order);
        return uint64(((packed >> _PRICE_SHIFT) << _QUANTITY_SHIFT) | (packed & _NONCE_MASK));
    }

    /// @notice Build the ask sort key from an order or branch node.
    /// @param order Packed node.
    /// @return Ask sort key: `(maxPrice - price) || nonce`.
    /// @dev Higher keys are better asks: lower price first after inversion, then higher nonce for earlier time.
    function _askSortKey(bytes32 order) private pure returns (uint64) {
        uint256 packed = uint256(order);
        unchecked {
            return uint64(((_MAX_PRICE - (packed >> _PRICE_SHIFT)) << _QUANTITY_SHIFT) | (packed & _NONCE_MASK));
        }
    }

    /// @notice Build the raw address path key from a node.
    /// @param order Packed node.
    /// @return Raw `price || nonce` key, ignoring quantity.
    /// @dev Branch addresses use raw path keys for both sides of the book.
    function _pathKey(bytes32 order) private pure returns (uint64) {
        uint256 packed = uint256(order);
        return uint64(((packed >> _PRICE_SHIFT) << _QUANTITY_SHIFT) | (packed & _NONCE_MASK));
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
    /// @return True if the selected bit is one.
    function _bit(uint64 key, uint8 depth) private pure returns (bool) {
        unchecked {
            return ((key >> (63 - depth)) & 1) == 1;
        }
    }

    /// @notice Return whether a side has optimized right-spine anchors that need materialization before insert.
    /// @param isBid True for the bid tree, false for the ask tree.
    /// @return dirty True if the side's right spine contains stale branch aggregate words.
    function _rightSpineDirty(bool isBid) private view returns (bool dirty) {
        uint256 flag = isBid ? _BID_RIGHT_SPINE_DIRTY : _ASK_RIGHT_SPINE_DIRTY;
        assembly {
            dirty := iszero(iszero(and(sload(nextNonce.slot), flag)))
        }
    }

    /// @notice Mark a side's right spine dirty.
    /// @param isBid True for the bid tree, false for the ask tree.
    function _setRightSpineDirty(bool isBid) private {
        uint256 flag = isBid ? _BID_RIGHT_SPINE_DIRTY : _ASK_RIGHT_SPINE_DIRTY;
        assembly {
            let nonceSlot := sload(nextNonce.slot)
            if iszero(and(nonceSlot, flag)) { sstore(nextNonce.slot, or(nonceSlot, flag)) }
        }
    }

    /// @notice Clear a side's right-spine dirty bit after materialization.
    /// @param isBid True for the bid tree, false for the ask tree.
    function _clearRightSpineDirty(bool isBid) private {
        uint256 flag = isBid ? _BID_RIGHT_SPINE_DIRTY : _ASK_RIGHT_SPINE_DIRTY;
        assembly {
            sstore(nextNonce.slot, and(sload(nextNonce.slot), not(flag)))
        }
    }

    /// @notice Build the side metadata key for an original order.
    /// @param order Packed order.
    /// @return Zero-quantity key with the same price and nonce.
    /// @dev
    /// Zero-quantity orders are invalid external inputs, so this namespace can store bid/ask side
    /// markers without colliding with real orders. The side marker is what lets `cancel` decide
    /// which root to search after an order has partially or fully filled.
    function _sideKey(bytes32 order) private pure returns (bytes32) {
        return bytes32(uint256(order) & _PATH_MASK);
    }

    /// @notice Compute quote value for a base quantity at a 24-bit integer price.
    /// @param price Integer quote-per-base price.
    /// @param quantity Base quantity.
    /// @return Quote amount.
    /// @dev The product is at most 216 bits, so it cannot overflow `uint256`.
    function _quoteValue(uint24 price, uint192 quantity) private pure returns (uint256) {
        unchecked {
            return uint256(price) * uint256(quantity);
        }
    }

    /// @notice Decode price and quantity from a packed node.
    /// @param order Packed node.
    /// @return price 24-bit price.
    /// @return quantity 192-bit quantity.
    function _priceAndQuantity(bytes32 order) private pure returns (uint24 price, uint192 quantity) {
        uint256 packed = uint256(order);
        // forge-lint: disable-next-line(unsafe-typecast)
        price = uint24(packed >> _PRICE_SHIFT);
        // forge-lint: disable-next-line(unsafe-typecast)
        quantity = uint192((packed >> _QUANTITY_SHIFT) & _QUANTITY_MASK);
    }

    /// @notice Enter the transient reentrancy guard.
    /// @dev
    /// Uses EIP-1153 transient storage, available under the configured Cancun EVM version. The slot
    /// is cleared by `_exit` at the end of successful external calls and automatically discarded at
    /// transaction end. Reverts roll the transient write back with the rest of the call frame.
    function _enter() private {
        /// @solidity memory-safe-assembly
        assembly {
            if tload(_REENTRANCY_GUARD_SLOT) {
                mstore(0x00, 0x37ed32e8) // `ReentrantCall()`.
                revert(0x1c, 0x04)
            }
            tstore(_REENTRANCY_GUARD_SLOT, 1)
        }
    }

    /// @notice Exit the transient reentrancy guard.
    /// @dev Clears the guard slot for later calls in the same transaction.
    function _exit() private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_REENTRANCY_GUARD_SLOT, 0)
        }
    }

    /// @notice Replace the quantity field of a packed order while preserving price and nonce.
    /// @param order Original packed order or leaf.
    /// @param quantity New remaining quantity.
    /// @return Packed node with updated quantity.
    /// @dev Used for partial fills. The returned reduced leaf intentionally has no owner mapping;
    /// ownership remains on the original full-quantity order key.
    function _withQuantity(bytes32 order, uint192 quantity) private pure returns (bytes32) {
        return bytes32((uint256(order) & _PATH_MASK) | (uint256(quantity) << _QUANTITY_SHIFT));
    }

    /// @notice Pack price, quantity, and nonce into a node.
    /// @param price 24-bit price.
    /// @param quantity 192-bit quantity.
    /// @param nonce 40-bit nonce or branch path suffix.
    /// @return Packed `bytes32` node.
    function _pack(uint24 price, uint192 quantity, uint40 nonce) private pure returns (bytes32) {
        return bytes32((uint256(price) << _PRICE_SHIFT) | (uint256(quantity) << _QUANTITY_SHIFT) | uint256(nonce));
    }

    /// @notice Extract the price field from a packed node.
    /// @param order Packed node.
    /// @return 24-bit price.
    function _price(bytes32 order) private pure returns (uint24) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(order) >> _PRICE_SHIFT);
    }

    /// @notice Extract the quantity field from a packed node.
    /// @param order Packed node.
    /// @return 192-bit quantity.
    function _quantity(bytes32 order) private pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192((uint256(order) >> _QUANTITY_SHIFT) & _QUANTITY_MASK);
    }
}
