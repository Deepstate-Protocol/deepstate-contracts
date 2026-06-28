// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {RadixMatchingEngine} from "../src/RadixMatchingEngine.sol";
import {TestERC20} from "./RadixMatchingEngine.t.sol";

contract RadixMatchingEngineHandler is Test {
    struct TrackedOrder {
        bytes32 order;
        address owner;
        bool isBid;
        bool active;
    }

    TestERC20 internal immutable BASE;
    TestERC20 internal immutable QUOTE;
    RadixMatchingEngine internal immutable ENGINE;

    uint256 internal constant MAX_TRACKED_ORDERS = 64;

    address[] internal actors;
    TrackedOrder[] internal trackedOrders;

    uint256 public unexpectedFillReverts;
    uint256 public unexpectedCancelReverts;
    bytes4 public lastFillRevertSelector;
    bytes4 public lastCancelRevertSelector;

    constructor(TestERC20 base_, TestERC20 quote_, RadixMatchingEngine engine_) {
        BASE = base_;
        QUOTE = quote_;
        ENGINE = engine_;

        actors.push(address(0xA11CE));
        actors.push(address(0xB0B));
        actors.push(address(0xCA201));
        actors.push(address(0xD00D));

        for (uint256 i; i < actors.length; ++i) {
            BASE.mint(actors[i], 1e30);
            QUOTE.mint(actors[i], 1e30);

            vm.startPrank(actors[i]);
            BASE.approve(address(ENGINE), type(uint256).max);
            QUOTE.approve(address(ENGINE), type(uint256).max);
            vm.stopPrank();
        }
    }

    function placeBid(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed) external {
        _place(actorSeed, priceSeed, quantitySeed, true);
    }

    function placeAsk(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed) external {
        _place(actorSeed, priceSeed, quantitySeed, false);
    }

    function cancel(uint256 orderSeed) external {
        if (trackedOrders.length == 0) return;

        uint256 index = bound(orderSeed, 0, trackedOrders.length - 1);
        TrackedOrder storage tracked = trackedOrders[index];
        if (!tracked.active) return;

        vm.prank(tracked.owner);
        try ENGINE.cancel(tracked.order) {
            tracked.active = false;
        } catch (bytes memory reason) {
            ++unexpectedCancelReverts;
            if (reason.length >= 4) {
                // forge-lint: disable-next-line(unsafe-typecast)
                lastCancelRevertSelector = bytes4(reason);
            }
        }
    }

    function orderCount() external view returns (uint256) {
        return trackedOrders.length;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 index) external view returns (address) {
        return actors[index];
    }

    function orderAt(uint256 index) external view returns (bytes32 order, address owner, bool isBid, bool active) {
        TrackedOrder storage tracked = trackedOrders[index];
        return (tracked.order, tracked.owner, tracked.isBid, tracked.active);
    }

    function _place(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed, bool isBid) private {
        if (trackedOrders.length >= MAX_TRACKED_ORDERS) return;

        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint24 price = uint24(bound(priceSeed, 1, 1_000));
        uint192 quantity = uint192(bound(quantitySeed, 1, 100));
        bytes32 order = bytes32((uint256(price) << 232) | (uint256(quantity) << 40));

        vm.prank(actor);
        try ENGINE.fill(order, isBid) returns (bytes32 restingOrder) {
            if (restingOrder != bytes32(0)) {
                trackedOrders.push(TrackedOrder({order: restingOrder, owner: actor, isBid: isBid, active: true}));
            }
        } catch (bytes memory reason) {
            ++unexpectedFillReverts;
            if (reason.length >= 4) {
                // forge-lint: disable-next-line(unsafe-typecast)
                lastFillRevertSelector = bytes4(reason);
            }
        }
    }
}

contract RadixMatchingEngineInvariantTest is StdInvariant, Test {
    struct SubtreeStats {
        uint192 quantity;
        uint64 minKey;
        uint64 maxKey;
        uint24 bestPrice;
        bool exists;
    }

    TestERC20 internal base;
    TestERC20 internal quote;
    RadixMatchingEngine internal engine;
    RadixMatchingEngineHandler internal handler;

    uint256 private constant _PRICE_SHIFT = 232;
    uint256 private constant _QUANTITY_SHIFT = 40;
    uint256 private constant _QUANTITY_MASK = (uint256(1) << 192) - 1;
    uint40 private constant _RESERVED_MAX_NONCE = type(uint40).max;
    uint24 private constant _MAX_PRICE = type(uint24).max;
    address private constant _BID_SENTINEL = address(uint160(1));
    address private constant _ASK_SENTINEL = address(uint160(2));

    function setUp() public {
        base = new TestERC20("Base", "BASE");
        quote = new TestERC20("Quote", "QUOTE");
        engine = new RadixMatchingEngine(address(base), address(quote));
        handler = new RadixMatchingEngineHandler(base, quote, engine);

        targetContract(address(handler));
    }

    function invariant_CollateralEqualsOutstandingClaims() public view {
        uint256 expectedBase;
        uint256 expectedQuote;
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            uint192 originalQuantity = _quantity(order);
            uint192 remainingQuantity = _remainingQuantity(order, isBid);
            uint192 filledQuantity = originalQuantity - remainingQuantity;
            uint24 limitPrice = _price(order);

            if (isBid) {
                expectedBase += filledQuantity;
                expectedQuote += _quoteValue(limitPrice, remainingQuantity);
            } else {
                expectedBase += remainingQuantity;
                expectedQuote += _quoteValue(limitPrice, filledQuantity);
            }
        }

        assertEq(base.balanceOf(address(engine)), expectedBase, "base collateral");
        assertEq(quote.balanceOf(address(engine)), expectedQuote, "quote collateral");
    }

    function invariant_TotalTokenSupplyConserved() public view {
        assertEq(_trackedBalanceSum(base), base.totalSupply(), "base supply");
        assertEq(_trackedBalanceSum(quote), quote.totalSupply(), "quote supply");
    }

    function invariant_NoUnexpectedHandlerReverts() public view {
        assertEq(handler.unexpectedFillReverts(), 0, "unexpected fill revert");
        assertEq(handler.unexpectedCancelReverts(), 0, "unexpected cancel revert");
    }

    function invariant_TreeAggregatesAndBranchShape() public view {
        _assertSubtree(engine.bidRoot(), 0, true);
        _assertSubtree(engine.askRoot(), 0, false);
    }

    function invariant_BooksAreNotCrossed() public view {
        SubtreeStats memory bidStats = _assertSubtree(engine.bidRoot(), 0, true);
        SubtreeStats memory askStats = _assertSubtree(engine.askRoot(), 0, false);

        if (bidStats.exists && askStats.exists) assertLt(bidStats.bestPrice, askStats.bestPrice, "crossed book");
    }

    function invariant_OwnerMappingMatchesTrackedOrders() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order, address owner,, bool active) = handler.orderAt(i);
            assertEq(engine.ownerOfOrder(order), active ? owner : address(0), "tracked owner");
        }
    }

    function invariant_SideMetadataMatchesTrackedOrders() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            address expectedMarker = active ? (isBid ? _BID_SENTINEL : _ASK_SENTINEL) : address(0);
            assertEq(engine.ownerOfOrder(_sideKey(order)), expectedMarker, "side marker");
        }
    }

    function _remainingQuantity(bytes32 order, bool isBid) private view returns (uint192) {
        bytes32 root = isBid ? engine.bidRoot() : engine.askRoot();
        bytes32 current = _find(root, order, isBid);
        return current == bytes32(0) ? 0 : _quantity(current);
    }

    function _trackedBalanceSum(TestERC20 token) private view returns (uint256 sum) {
        sum = token.balanceOf(address(engine));
        uint256 length = handler.actorCount();
        for (uint256 i; i < length; ++i) {
            sum += token.balanceOf(handler.actorAt(i));
        }
    }

    function _assertSubtree(bytes32 node, uint256 depth, bool isBidTree)
        private
        view
        returns (SubtreeStats memory stats)
    {
        if (node == bytes32(0)) return stats;
        assertLe(depth, 64, "radix depth");

        if (!_isBranch(node)) {
            assertGt(_quantity(node), 0, "leaf quantity");
            assertLt(_nonce(node), _RESERVED_MAX_NONCE, "leaf nonce");
            uint64 key = _sortKey(node, isBidTree);
            stats.quantity = _quantity(node);
            stats.minKey = key;
            stats.maxKey = key;
            stats.bestPrice = _price(node);
            stats.exists = true;
            return stats;
        }

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        assertTrue(leftNode != bytes32(0), "left child");
        assertTrue(rightNode != bytes32(0), "right child");
        assertEq(node, _branchNodeForChildren(leftNode, rightNode), "branch address");

        uint8 branchDepth = _branchDepth(node, isBidTree);
        SubtreeStats memory leftStats = _assertSubtree(leftNode, depth + 1, isBidTree);
        SubtreeStats memory rightStats = _assertSubtree(rightNode, depth + 1, isBidTree);

        _assertBranchOrder(branchDepth, leftStats, rightStats);

        stats.quantity = leftStats.quantity + rightStats.quantity;
        stats.minKey = leftStats.minKey;
        stats.maxKey = rightStats.maxKey;
        stats.bestPrice = rightStats.bestPrice;
        stats.exists = true;
        assertEq(_quantity(node), stats.quantity, "branch quantity");
    }

    function _assertBranchOrder(uint8 branchDepth, SubtreeStats memory leftStats, SubtreeStats memory rightStats)
        private
        pure
    {
        assertTrue(leftStats.exists, "left subtree");
        assertTrue(rightStats.exists, "right subtree");
        assertLt(leftStats.maxKey, rightStats.minKey, "branch order");
        assertFalse(_bit(leftStats.minKey, branchDepth), "left min bit");
        assertFalse(_bit(leftStats.maxKey, branchDepth), "left max bit");
        assertTrue(_bit(rightStats.minKey, branchDepth), "right min bit");
        assertTrue(_bit(rightStats.maxKey, branchDepth), "right max bit");
        if (leftStats.minKey != leftStats.maxKey) {
            assertGe(_commonPrefix(leftStats.minKey, leftStats.maxKey), branchDepth + 1, "left prefix");
        }
        if (rightStats.minKey != rightStats.maxKey) {
            assertGe(_commonPrefix(rightStats.minKey, rightStats.maxKey), branchDepth + 1, "right prefix");
        }
    }

    function _find(bytes32 root, bytes32 order, bool isBidTree) private view returns (bytes32) {
        uint64 targetKey = _sortKey(order, isBidTree);

        while (root != bytes32(0) && _isBranch(root)) {
            uint8 branchDepth = _branchDepth(root, isBidTree);
            if (_commonPrefix(targetKey, _nodeKey(root, isBidTree)) < branchDepth) return bytes32(0);

            (bytes32 leftNode, bytes32 rightNode) = engine.tree(root);
            root = _bit(targetKey, branchDepth) ? rightNode : leftNode;
        }

        return root != bytes32(0) && _sortKey(root, isBidTree) == targetKey ? root : bytes32(0);
    }

    function _isBranch(bytes32 node) private view returns (bool) {
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        return leftNode != bytes32(0) || rightNode != bytes32(0);
    }

    function _branchDepth(bytes32 branchNode, bool isBidTree) private view returns (uint8) {
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(branchNode);
        return _commonPrefix(_nodeKey(leftNode, isBidTree), _nodeKey(rightNode, isBidTree));
    }

    function _nodeKey(bytes32 node, bool isBidTree) private view returns (uint64) {
        if (!_isBranch(node)) return _sortKey(node, isBidTree);
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        return _nodeKey(leftNode != bytes32(0) ? leftNode : rightNode, isBidTree);
    }

    function _branchNodeForChildren(bytes32 leftNode, bytes32 rightNode) private view returns (bytes32) {
        uint64 leftAddressKey = _nodeAddressKey(leftNode);
        uint64 rightAddressKey = _nodeAddressKey(rightNode);
        uint8 addressDepth = _commonPrefix(leftAddressKey, rightAddressKey);
        assertLt(addressDepth, 64, "branch address depth");

        uint192 quantity = _quantity(leftNode) + _quantity(rightNode);
        uint64 prefix = _branchCode(leftAddressKey, addressDepth);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint24 prefixPrice = uint24(prefix >> 40);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 prefixNonce = uint40(prefix);
        return _pack(prefixPrice, quantity, prefixNonce);
    }

    function _nodeAddressKey(bytes32 node) private view returns (uint64) {
        if (!_isBranch(node)) return _pathKey(node);
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        return _nodeAddressKey(leftNode != bytes32(0) ? leftNode : rightNode);
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

    function _branchCode(uint64 key, uint8 depth) private pure returns (uint64) {
        uint64 prefix = depth == 0 ? 0 : key & (type(uint64).max << (64 - depth));
        return prefix | (uint64(1) << (63 - depth));
    }

    function _commonPrefix(uint64 a, uint64 b) private pure returns (uint8 prefixLength) {
        for (; prefixLength < 64; ++prefixLength) {
            if (_bit(a, prefixLength) != _bit(b, prefixLength)) return prefixLength;
        }
    }

    function _bit(uint64 key, uint8 depth) private pure returns (bool) {
        return ((key >> (63 - depth)) & 1) == 1;
    }

    function _quoteValue(uint24 price, uint192 quantity) private pure returns (uint256) {
        return uint256(price) * uint256(quantity);
    }

    function _sideKey(bytes32 order) private pure returns (bytes32) {
        return _pack(_price(order), 0, _nonce(order));
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
        return uint40(uint256(order));
    }
}
