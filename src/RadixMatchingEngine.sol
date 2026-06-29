// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibBit} from "solady/utils/LibBit.sol";

/// @notice First-pass radix-style matching engine with strict bytes32 resting order nodes.
contract RadixMatchingEngine {
    using SafeTransferLib for address;

    /// @notice Resting order branch.
    struct Branch {
        bytes32 leftNode;
        bytes32 rightNode;
    }

    mapping(bytes32 => Branch) public tree;

    /// @notice Owner lookup by order node. Fill/cancel state is derived by searching trees.
    mapping(bytes32 => address) public ownerOfOrder;

    bytes32 public bidRoot;

    /// @notice Root node of the ask tree.
    bytes32 public askRoot;

    /// @notice Decrementing nonce. Higher nonce means earlier time priority at the same price.
    uint40 public nextNonce = type(uint40).max;

    address public immutable BASE_TOKEN;
    address public immutable QUOTE_TOKEN;

    uint256 private constant _PRICE_SHIFT = 232;
    uint256 private constant _QUANTITY_SHIFT = 40;
    uint256 private constant _QUANTITY_MASK = (uint256(1) << 192) - 1;
    uint256 private constant _NONCE_MASK = (uint256(1) << 40) - 1;
    uint256 private constant _PATH_MASK = ~(_QUANTITY_MASK << _QUANTITY_SHIFT);
    uint24 private constant _MAX_PRICE = type(uint24).max;

    address private constant _BID_SENTINEL = address(uint160(1));
    address private constant _ASK_SENTINEL = address(uint160(2));
    bytes32 private constant _REENTRANCY_GUARD_SLOT =
        0xc55a21be1c6e869c49c7a5860f6c3a83187eb30a12bcd0421f3cf4f5871dccff;

    event OrderRested(bytes32 indexed order, address indexed owner, bool indexed isBid);
    event OrderMatched(bytes32 indexed restingOrder, bool indexed restingIsBid, uint192 quantity, uint256 quoteAmount);
    event OrderCancelled(bytes32 indexed order, address indexed owner, uint256 baseAmount, uint256 quoteAmount);

    error InvalidToken();
    error InvalidOrder();
    error NonceExhausted();
    error DuplicateOrder();
    error NotOrderOwner();
    error OrderNotFound();
    error ReentrantCall();

    modifier nonReentrant() {
        _enter();
        _;
        _exit();
    }

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
    /// @dev Incoming orders must leave the low 40 nonce bits empty; the contract assigns time priority.
    function fill(bytes32 order, bool isBid) external nonReentrant returns (bytes32 restingOrder) {
        uint24 limitPrice = _price(order);
        uint192 quantity = _quantity(order);
        if (limitPrice == 0 || quantity == 0 || _nonce(order) != 0) revert InvalidOrder();

        uint192 remaining = quantity;
        uint192 baseFilled;
        uint256 quoteAmount;

        if (isBid) {
            bytes32 root = askRoot;
            bytes32 newRoot;
            (newRoot, remaining, baseFilled, quoteAmount) = _match(root, limitPrice, remaining, false);
            if (newRoot != root) askRoot = newRoot;

            uint256 quoteCollateral;
            if (remaining != 0) {
                restingOrder = _rest(limitPrice, remaining, true);
                quoteCollateral = _quoteValue(limitPrice, remaining);
            }
            unchecked {
                quoteCollateral += quoteAmount;
            }

            if (quoteCollateral != 0) QUOTE_TOKEN.safeTransferFrom(msg.sender, address(this), quoteCollateral);
            if (baseFilled != 0) BASE_TOKEN.safeTransfer(msg.sender, baseFilled);
        } else {
            bytes32 root = bidRoot;
            bytes32 newRoot;
            (newRoot, remaining, baseFilled, quoteAmount) = _match(root, limitPrice, remaining, true);
            if (newRoot != root) bidRoot = newRoot;

            if (remaining != 0) {
                restingOrder = _rest(limitPrice, remaining, false);
            }

            BASE_TOKEN.safeTransferFrom(msg.sender, address(this), quantity);
            if (quoteAmount != 0) QUOTE_TOKEN.safeTransfer(msg.sender, quoteAmount);
        }
    }

    /// @notice Cancel an open order or claim a filled order.
    function cancel(bytes32 order) external nonReentrant returns (uint256 baseAmount, uint256 quoteAmount) {
        uint192 originalQuantity = _quantity(order);
        if (originalQuantity == 0) revert InvalidOrder();

        address owner = ownerOfOrder[order];
        if (owner != msg.sender) revert NotOrderOwner();

        bytes32 sideKey = _sideKey(order);
        address marker = ownerOfOrder[sideKey];
        bool isBid;
        if (marker == _BID_SENTINEL) {
            isBid = true;
        } else if (marker != _ASK_SENTINEL) {
            revert OrderNotFound();
        }

        uint192 remainingQuantity = 0;
        bytes32 removed;

        if (isBid) {
            bytes32 root = bidRoot;
            if (root != bytes32(0)) {
                bytes32 newRoot;
                (newRoot, removed) = _removeByKey(root, _sortKey(order, true), true);
                if (newRoot != root) bidRoot = newRoot;
            }
        } else {
            bytes32 root = askRoot;
            if (root != bytes32(0)) {
                bytes32 newRoot;
                (newRoot, removed) = _removeByKey(root, _sortKey(order, false), false);
                if (newRoot != root) askRoot = newRoot;
            }
        }

        if (removed != bytes32(0)) remainingQuantity = _quantity(removed);
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

    function _rest(uint24 price, uint192 quantity, bool isBid) private returns (bytes32 restingOrder) {
        uint40 nonce = nextNonce;
        if (nonce == 0) revert NonceExhausted();
        unchecked {
            nextNonce = nonce - 1;
        }

        restingOrder = _pack(price, quantity, nonce);
        ownerOfOrder[restingOrder] = msg.sender;
        ownerOfOrder[_sideKey(restingOrder)] = isBid ? _BID_SENTINEL : _ASK_SENTINEL;

        if (isBid) {
            bidRoot = _insert(bidRoot, restingOrder, _sortKey(restingOrder, true), true);
        } else {
            askRoot = _insert(askRoot, restingOrder, _sortKey(restingOrder, false), false);
        }

        emit OrderRested(restingOrder, msg.sender, isBid);
    }

    function _match(bytes32 root, uint24 limitPrice, uint192 remaining, bool restingIsBid)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        if (root == bytes32(0) || remaining == 0) return (root, remaining, 0, 0);

        bytes32 leftNode = tree[root].leftNode;
        if (leftNode == bytes32(0)) return _matchLeaf(root, limitPrice, remaining, restingIsBid);

        return _matchBranch(
            root, Branch({leftNode: leftNode, rightNode: tree[root].rightNode}), limitPrice, remaining, restingIsBid
        );
    }

    function _matchBranch(bytes32 root, Branch memory branch, uint24 limitPrice, uint192 remaining, bool restingIsBid)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        bytes32 oldRightNode = branch.rightNode;
        (branch.rightNode, remaining, baseFilled, quoteAmount) =
            _match(branch.rightNode, limitPrice, remaining, restingIsBid);

        if (remaining == 0 || branch.rightNode != bytes32(0)) {
            if (branch.rightNode == oldRightNode) return (root, remaining, baseFilled, quoteAmount);
            return
                (
                    _replaceBranch(root, branch.leftNode, branch.rightNode, restingIsBid),
                    remaining,
                    baseFilled,
                    quoteAmount
                );
        }

        uint192 leftBaseFilled;
        uint256 leftQuoteAmount;
        (branch.leftNode, newRemaining, leftBaseFilled, leftQuoteAmount) =
            _match(branch.leftNode, limitPrice, remaining, restingIsBid);

        unchecked {
            baseFilled += leftBaseFilled;
            quoteAmount += leftQuoteAmount;
        }

        newRoot = _replaceBranch(root, branch.leftNode, branch.rightNode, restingIsBid);
    }

    function _matchLeaf(bytes32 root, uint24 limitPrice, uint192 remaining, bool restingIsBid)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        uint24 restingPrice = _price(root);
        if (restingIsBid ? restingPrice < limitPrice : restingPrice > limitPrice) return (root, remaining, 0, 0);

        uint192 restingQuantity = _quantity(root);
        uint192 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteValue(restingPrice, fillQuantity);

        emit OrderMatched(root, restingIsBid, fillQuantity, quoteAmount);

        unchecked {
            newRemaining = remaining - fillQuantity;
            baseFilled += fillQuantity;
        }

        if (fillQuantity < restingQuantity) {
            unchecked {
                newRoot = _withQuantity(root, restingQuantity - fillQuantity);
            }
        }
    }

    function _insert(bytes32 root, bytes32 node, uint64 nodeKey, bool isBidTree) private returns (bytes32) {
        if (root == bytes32(0)) return node;

        bytes32 leftNode = tree[root].leftNode;
        if (leftNode == bytes32(0)) return _storeBranch(root, node, isBidTree);

        Branch memory branch = Branch({leftNode: leftNode, rightNode: tree[root].rightNode});
        uint64 leftKey = _nodeKey(branch.leftNode, isBidTree);
        uint8 branchDepth = _commonPrefix(leftKey, _nodeKey(branch.rightNode, isBidTree));
        if (_commonPrefix(nodeKey, leftKey) < branchDepth) {
            return _storeBranch(root, node, isBidTree);
        }

        if (_bit(nodeKey, branchDepth)) {
            branch.rightNode = _insert(branch.rightNode, node, nodeKey, isBidTree);
        } else {
            branch.leftNode = _insert(branch.leftNode, node, nodeKey, isBidTree);
        }

        return _replaceBranch(root, branch.leftNode, branch.rightNode, isBidTree);
    }

    function _removeByKey(bytes32 root, uint64 targetKey, bool isBidTree)
        private
        returns (bytes32 newRoot, bytes32 removed)
    {
        if (root == bytes32(0)) return (bytes32(0), bytes32(0));

        bytes32 leftNode = tree[root].leftNode;
        if (leftNode == bytes32(0)) {
            return _sortKey(root, isBidTree) == targetKey ? (bytes32(0), root) : (root, bytes32(0));
        }

        Branch memory branch = Branch({leftNode: leftNode, rightNode: tree[root].rightNode});
        uint64 leftKey = _nodeKey(branch.leftNode, isBidTree);
        uint8 branchDepth = _commonPrefix(leftKey, _nodeKey(branch.rightNode, isBidTree));
        if (_commonPrefix(targetKey, leftKey) < branchDepth) return (root, bytes32(0));

        if (_bit(targetKey, branchDepth)) {
            (branch.rightNode, removed) = _removeByKey(branch.rightNode, targetKey, isBidTree);
        } else {
            (branch.leftNode, removed) = _removeByKey(branch.leftNode, targetKey, isBidTree);
        }

        if (removed == bytes32(0)) return (root, bytes32(0));
        return (_replaceBranch(root, branch.leftNode, branch.rightNode, isBidTree), removed);
    }

    function _replaceBranch(bytes32 oldBranch, bytes32 leftNode, bytes32 rightNode, bool isBidTree)
        private
        returns (bytes32)
    {
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

        if (newBranch != oldBranch && oldBranch != leftNode && oldBranch != rightNode) {
            if (_quantity(oldBranch) > _quantity(newBranch) || !_containsBranch(newBranch, oldBranch, isBidTree)) {
                delete tree[oldBranch];
            }
        }
        return newBranch;
    }

    function _containsBranch(bytes32 root, bytes32 target, bool isBidTree) private view returns (bool) {
        uint64 targetKey = _nodeKey(target, isBidTree);

        while (root != bytes32(0)) {
            if (root == target) return true;

            bytes32 leftNode = tree[root].leftNode;
            if (leftNode == bytes32(0)) return false;

            bytes32 rightNode = tree[root].rightNode;
            uint64 leftKey = _nodeKey(leftNode, isBidTree);
            uint8 branchDepth = _commonPrefix(leftKey, _nodeKey(rightNode, isBidTree));
            if (_commonPrefix(targetKey, leftKey) < branchDepth) return false;

            root = _bit(targetKey, branchDepth) ? rightNode : leftNode;
        }

        return false;
    }

    function _storeBranch(bytes32 a, bytes32 b, bool isBidTree) private returns (bytes32 branchNode) {
        if (a == bytes32(0)) return b;
        if (b == bytes32(0)) return a;

        uint64 aKey = _nodeKey(a, isBidTree);
        uint64 bKey = _nodeKey(b, isBidTree);
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

    function _branchNodeForChildren(bytes32 a, bytes32 b) private pure returns (bytes32) {
        uint64 aAddressKey = _pathKey(a);
        uint64 bAddressKey = _pathKey(b);
        uint64 boundaryKey = aAddressKey > bAddressKey ? aAddressKey : bAddressKey;
        return _branchNode(boundaryKey, _quantity(a) + _quantity(b));
    }

    function _branchNode(uint64 key, uint192 quantity) private pure returns (bytes32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint24 prefixPrice = uint24(key >> 40);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 prefixNonce = uint40(key);
        return _pack(prefixPrice, quantity, prefixNonce);
    }

    function _nodeKey(bytes32 node, bool isBidTree) private pure returns (uint64) {
        return _sortKey(node, isBidTree);
    }

    function _sortKey(bytes32 order, bool isBidTree) private pure returns (uint64) {
        uint24 price = _price(order);
        uint40 nonce = _nonce(order);
        uint24 sortablePrice;
        unchecked {
            sortablePrice = isBidTree ? price : _MAX_PRICE - price;
        }
        return (uint64(sortablePrice) << 40) | uint64(nonce);
    }

    function _pathKey(bytes32 order) private pure returns (uint64) {
        return (uint64(_price(order)) << 40) | uint64(_nonce(order));
    }

    function _commonPrefix(uint64 a, uint64 b) private pure returns (uint8 prefixLength) {
        uint256 differingBits = uint256(a ^ b);
        if (differingBits == 0) return 64;

        unchecked {
            prefixLength = uint8(LibBit.clz(differingBits << 192));
        }
    }

    function _bit(uint64 key, uint8 depth) private pure returns (bool) {
        unchecked {
            return ((key >> (63 - depth)) & 1) == 1;
        }
    }

    function _sideKey(bytes32 order) private pure returns (bytes32) {
        return bytes32(uint256(order) & _PATH_MASK);
    }

    function _quoteValue(uint24 price, uint192 quantity) private pure returns (uint256) {
        unchecked {
            return uint256(price) * uint256(quantity);
        }
    }

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

    function _exit() private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(_REENTRANCY_GUARD_SLOT, 0)
        }
    }

    function _withQuantity(bytes32 order, uint192 quantity) private pure returns (bytes32) {
        return bytes32((uint256(order) & _PATH_MASK) | (uint256(quantity) << _QUANTITY_SHIFT));
    }

    function _pack(uint24 price, uint192 quantity, uint40 nonce) private pure returns (bytes32) {
        return bytes32((uint256(price) << _PRICE_SHIFT) | (uint256(quantity) << _QUANTITY_SHIFT) | uint256(nonce));
    }

    function _price(bytes32 order) private pure returns (uint24) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(order) >> _PRICE_SHIFT);
    }

    function _quantity(bytes32 order) private pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192((uint256(order) >> _QUANTITY_SHIFT) & _QUANTITY_MASK);
    }

    function _nonce(bytes32 order) private pure returns (uint40) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint40(uint256(order) & _NONCE_MASK);
    }
}
