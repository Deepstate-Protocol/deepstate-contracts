// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

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
    /// @dev Resting orders start below the maximum value, leaving the top nonce endpoint unused by orders.
    uint40 public nextNonce = _MAX_ORDER_NONCE;

    address public immutable BASE_TOKEN;
    address public immutable QUOTE_TOKEN;

    uint256 private constant _PRICE_SHIFT = 232;
    uint256 private constant _QUANTITY_SHIFT = 40;
    uint256 private constant _QUANTITY_MASK = (uint256(1) << 192) - 1;
    uint256 private constant _NONCE_MASK = (uint256(1) << 40) - 1;
    uint40 private constant _RESERVED_MAX_NONCE = type(uint40).max;
    uint40 private constant _MAX_ORDER_NONCE = _RESERVED_MAX_NONCE - 1;
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
    error TokenBalanceQueryFailed();
    error InexactTokenTransfer();

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
            (askRoot, remaining, baseFilled, quoteAmount) = _match(askRoot, limitPrice, remaining, false);

            if (quoteAmount != 0) _safeTransferFromExact(QUOTE_TOKEN, msg.sender, address(this), quoteAmount);
            if (baseFilled != 0) _safeTransferExact(BASE_TOKEN, msg.sender, baseFilled);

            if (remaining != 0) {
                restingOrder = _rest(order, remaining, true);
                _safeTransferFromExact(QUOTE_TOKEN, msg.sender, address(this), _quoteValue(limitPrice, remaining));
            }
        } else {
            (bidRoot, remaining, baseFilled, quoteAmount) = _match(bidRoot, limitPrice, remaining, true);

            if (baseFilled != 0) _safeTransferFromExact(BASE_TOKEN, msg.sender, address(this), baseFilled);
            if (quoteAmount != 0) _safeTransferExact(QUOTE_TOKEN, msg.sender, quoteAmount);

            if (remaining != 0) {
                restingOrder = _rest(order, remaining, false);
                _safeTransferFromExact(BASE_TOKEN, msg.sender, address(this), remaining);
            }
        }
    }

    /// @notice Cancel an open order or claim a filled order.
    function cancel(bytes32 order) external nonReentrant returns (uint256 baseAmount, uint256 quoteAmount) {
        address owner = ownerOfOrder[order];
        if (owner != msg.sender) revert NotOrderOwner();

        bool isBid = _orderIsBid(order);
        bytes32 currentNode = isBid ? _find(bidRoot, order, true) : _find(askRoot, order, false);

        uint192 originalQuantity = _quantity(order);
        uint192 remainingQuantity;

        if (currentNode != bytes32(0)) {
            remainingQuantity = _quantity(currentNode);

            bytes32 removed;
            if (isBid) {
                (bidRoot, removed) = _removeByKey(bidRoot, order, true);
            } else {
                (askRoot, removed) = _removeByKey(askRoot, order, false);
            }
            if (removed == bytes32(0)) revert OrderNotFound();
        }

        if (remainingQuantity > originalQuantity) revert InvalidOrder();
        uint192 filledQuantity = originalQuantity - remainingQuantity;
        uint24 limitPrice = _price(order);

        if (isBid) {
            baseAmount = filledQuantity;
            quoteAmount = _quoteValue(limitPrice, remainingQuantity);
        } else {
            baseAmount = remainingQuantity;
            quoteAmount = _quoteValue(limitPrice, filledQuantity);
        }

        delete ownerOfOrder[order];
        delete ownerOfOrder[_sideKey(order)];

        if (baseAmount != 0) _safeTransferExact(BASE_TOKEN, owner, baseAmount);
        if (quoteAmount != 0) _safeTransferExact(QUOTE_TOKEN, owner, quoteAmount);

        emit OrderCancelled(order, owner, baseAmount, quoteAmount);
    }

    function _rest(bytes32 order, uint192 quantity, bool isBid) private returns (bytes32 restingOrder) {
        uint40 nonce = nextNonce;
        if (nonce == 0) revert NonceExhausted();
        unchecked {
            nextNonce = nonce - 1;
        }

        restingOrder = _pack(_price(order), quantity, nonce);
        if (ownerOfOrder[restingOrder] != address(0)) revert DuplicateOrder();

        ownerOfOrder[restingOrder] = msg.sender;
        ownerOfOrder[_sideKey(restingOrder)] = isBid ? _BID_SENTINEL : _ASK_SENTINEL;

        if (isBid) {
            bidRoot = _insert(bidRoot, restingOrder, true);
        } else {
            askRoot = _insert(askRoot, restingOrder, false);
        }

        emit OrderRested(restingOrder, msg.sender, isBid);
    }

    function _match(bytes32 root, uint24 limitPrice, uint192 remaining, bool restingIsBid)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        if (root == bytes32(0) || remaining == 0) return (root, remaining, 0, 0);

        if (_isBranch(root)) return _matchBranch(root, limitPrice, remaining, restingIsBid);
        return _matchLeaf(root, limitPrice, remaining, restingIsBid);
    }

    function _matchBranch(bytes32 root, uint24 limitPrice, uint192 remaining, bool restingIsBid)
        private
        returns (bytes32 newRoot, uint192 newRemaining, uint192 baseFilled, uint256 quoteAmount)
    {
        Branch memory branch = tree[root];
        (branch.rightNode, remaining, baseFilled, quoteAmount) =
            _match(branch.rightNode, limitPrice, remaining, restingIsBid);

        if (remaining == 0 || branch.rightNode != bytes32(0)) {
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
        if (!_canMatch(root, limitPrice, restingIsBid)) return (root, remaining, 0, 0);

        uint192 restingQuantity = _quantity(root);
        uint192 fillQuantity = remaining < restingQuantity ? remaining : restingQuantity;
        quoteAmount = _quoteValue(_price(root), fillQuantity);

        emit OrderMatched(root, restingIsBid, fillQuantity, quoteAmount);

        unchecked {
            newRemaining = remaining - fillQuantity;
            baseFilled += fillQuantity;
        }

        if (fillQuantity < restingQuantity) {
            newRoot = _withQuantity(root, restingQuantity - fillQuantity);
        }
    }

    function _insert(bytes32 root, bytes32 node, bool isBidTree) private returns (bytes32) {
        if (root == bytes32(0)) return node;

        if (!_isBranch(root)) return _storeBranch(root, node, isBidTree);

        uint64 nodeKey = _nodeKey(node, isBidTree);
        uint8 branchDepth = _branchDepth(root, isBidTree);
        if (_commonPrefix(nodeKey, _nodeKey(root, isBidTree)) < branchDepth) {
            return _storeBranch(root, node, isBidTree);
        }

        Branch memory branch = tree[root];
        if (_bit(nodeKey, branchDepth)) {
            branch.rightNode = _insert(branch.rightNode, node, isBidTree);
        } else {
            branch.leftNode = _insert(branch.leftNode, node, isBidTree);
        }

        return _replaceBranch(root, branch.leftNode, branch.rightNode, isBidTree);
    }

    function _find(bytes32 root, bytes32 order, bool isBidTree) private view returns (bytes32) {
        uint64 targetKey = _sortKey(order, isBidTree);

        while (root != bytes32(0) && _isBranch(root)) {
            uint8 branchDepth = _branchDepth(root, isBidTree);
            if (_commonPrefix(targetKey, _nodeKey(root, isBidTree)) < branchDepth) return bytes32(0);

            Branch memory branch = tree[root];
            root = _bit(targetKey, branchDepth) ? branch.rightNode : branch.leftNode;
        }

        return root != bytes32(0) && _sortKey(root, isBidTree) == targetKey ? root : bytes32(0);
    }

    function _removeByKey(bytes32 root, bytes32 order, bool isBidTree)
        private
        returns (bytes32 newRoot, bytes32 removed)
    {
        if (root == bytes32(0)) return (bytes32(0), bytes32(0));

        uint64 targetKey = _sortKey(order, isBidTree);
        if (!_isBranch(root)) {
            return _sortKey(root, isBidTree) == targetKey ? (bytes32(0), root) : (root, bytes32(0));
        }

        Branch memory branch = tree[root];
        uint8 branchDepth = _branchDepth(root, isBidTree);
        if (_commonPrefix(targetKey, _nodeKey(root, isBidTree)) < branchDepth) return (root, bytes32(0));

        if (_bit(targetKey, branchDepth)) {
            (branch.rightNode, removed) = _removeByKey(branch.rightNode, order, isBidTree);
        } else {
            (branch.leftNode, removed) = _removeByKey(branch.leftNode, order, isBidTree);
        }

        if (removed == bytes32(0)) return (root, bytes32(0));
        return (_replaceBranch(root, branch.leftNode, branch.rightNode, isBidTree), removed);
    }

    function _replaceBranch(bytes32 oldBranch, bytes32 leftNode, bytes32 rightNode, bool isBidTree)
        private
        returns (bytes32)
    {
        bytes32 newBranch = _storeBranch(leftNode, rightNode, isBidTree);
        if (newBranch != oldBranch) delete tree[oldBranch];
        return newBranch;
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
        tree[branchNode] = Branch({leftNode: leftNode, rightNode: rightNode});
    }

    function _canMatch(bytes32 restingOrder, uint24 limitPrice, bool restingIsBid) private pure returns (bool) {
        uint24 restingPrice = _price(restingOrder);
        return restingIsBid ? restingPrice >= limitPrice : restingPrice <= limitPrice;
    }

    function _branchNodeForChildren(bytes32 a, bytes32 b) private view returns (bytes32) {
        uint64 aAddressKey = _nodeAddressKey(a);
        uint64 bAddressKey = _nodeAddressKey(b);
        uint8 addressDepth = _commonPrefix(aAddressKey, bAddressKey);
        if (addressDepth == 64) revert DuplicateOrder();
        return _branchNode(aAddressKey, addressDepth, _nodeQuantity(a) + _nodeQuantity(b));
    }

    function _branchNode(uint64 key, uint8 depth, uint192 quantity) private pure returns (bytes32) {
        uint64 prefix = _branchCode(key, depth);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint24 prefixPrice = uint24(prefix >> 40);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 prefixNonce = uint40(prefix);
        return _pack(prefixPrice, quantity, prefixNonce);
    }

    function _branchCode(uint64 key, uint8 depth) private pure returns (uint64) {
        uint64 prefix = depth == 0 ? 0 : key & (type(uint64).max << (64 - depth));
        return prefix | (uint64(1) << (63 - depth));
    }

    function _isBranch(bytes32 node) private view returns (bool) {
        return tree[node].leftNode != bytes32(0) || tree[node].rightNode != bytes32(0);
    }

    function _branchDepth(bytes32 branchNode, bool isBidTree) private view returns (uint8) {
        Branch memory branch = tree[branchNode];
        return _commonPrefix(_nodeKey(branch.leftNode, isBidTree), _nodeKey(branch.rightNode, isBidTree));
    }

    function _nodeKey(bytes32 node, bool isBidTree) private view returns (uint64) {
        if (!_isBranch(node)) return _sortKey(node, isBidTree);
        Branch memory branch = tree[node];
        return _nodeKey(branch.leftNode != bytes32(0) ? branch.leftNode : branch.rightNode, isBidTree);
    }

    function _nodeAddressKey(bytes32 node) private view returns (uint64) {
        if (!_isBranch(node)) return _pathKey(node);
        Branch memory branch = tree[node];
        return _nodeAddressKey(branch.leftNode != bytes32(0) ? branch.leftNode : branch.rightNode);
    }

    function _nodeQuantity(bytes32 node) private pure returns (uint192) {
        return _quantity(node);
    }

    function _sortKey(bytes32 order, bool isBidTree) private pure returns (uint64) {
        uint24 price = _price(order);
        uint40 nonce = _nonce(order);
        uint24 sortablePrice = isBidTree ? price : _MAX_PRICE - price;
        return (uint64(sortablePrice) << 40) | uint64(nonce);
    }

    function _pathKey(bytes32 order) private pure returns (uint64) {
        return (uint64(_price(order)) << 40) | uint64(_nonce(order));
    }

    function _commonPrefix(uint64 a, uint64 b) private pure returns (uint8 prefixLength) {
        for (; prefixLength < 64; ++prefixLength) {
            if (_bit(a, prefixLength) != _bit(b, prefixLength)) return prefixLength;
        }
    }

    function _bit(uint64 key, uint8 depth) private pure returns (bool) {
        return ((key >> (63 - depth)) & 1) == 1;
    }

    function _orderIsBid(bytes32 order) private view returns (bool) {
        address marker = ownerOfOrder[_sideKey(order)];
        if (marker == _BID_SENTINEL) return true;
        if (marker == _ASK_SENTINEL) return false;
        revert OrderNotFound();
    }

    function _sideKey(bytes32 order) private pure returns (bytes32) {
        return _pack(_price(order), 0, _nonce(order));
    }

    function _quoteValue(uint24 price, uint192 quantity) private pure returns (uint256) {
        return uint256(price) * uint256(quantity);
    }

    function _safeTransferFromExact(address token, address from, address to, uint256 amount) private {
        uint256 balanceBefore = _balanceOf(token, to);
        token.safeTransferFrom(from, to, amount);
        if (_balanceOf(token, to) != balanceBefore + amount) revert InexactTokenTransfer();
    }

    function _safeTransferExact(address token, address to, uint256 amount) private {
        uint256 balanceBefore = _balanceOf(token, to);
        token.safeTransfer(to, amount);
        if (_balanceOf(token, to) != balanceBefore + amount) revert InexactTokenTransfer();
    }

    function _balanceOf(address token, address account) private view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(0x04, account)
            if iszero(staticcall(gas(), token, 0x00, 0x24, 0x00, 0x20)) {
                mstore(0x00, 0xa8b0ccad) // `TokenBalanceQueryFailed()`.
                revert(0x1c, 0x04)
            }
            if lt(returndatasize(), 0x20) {
                mstore(0x00, 0xa8b0ccad) // `TokenBalanceQueryFailed()`.
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
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
        return _pack(_price(order), quantity, _nonce(order));
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
