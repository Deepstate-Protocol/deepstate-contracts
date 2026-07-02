// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {RoutingEngine} from "../src/RoutingEngine.sol";
import {TestERC20} from "./RadixMatchingEngine.t.sol";

contract RadixMatchingEngineGasTest is Test {
    uint40 internal constant MAX_ORDER_NONCE = type(uint40).max;
    uint256 internal constant QUANTITY_SHIFT = 40;
    uint256 internal constant QUANTITY_MASK = (uint256(1) << 192) - 1;
    uint256 internal constant LARGE_BOOK_ORDERS = 5_000;
    uint24 internal constant LARGE_BID_BASE_PRICE = 1_000_000;
    uint24 internal constant LARGE_ASK_BASE_PRICE = 2_000_000;
    uint24 internal constant LARGE_REST_BID_PRICE = 1_750_000;
    uint24 internal constant LARGE_REST_ASK_PRICE = 1_750_001;

    struct LargeRandomBook {
        bytes32 bestBid;
        bytes32 bestAsk;
        uint24 bestBidPrice;
        uint24 bestAskPrice;
        uint192 bestBidQuantity;
        uint192 bestAskQuantity;
    }

    TestERC20 internal base;
    TestERC20 internal quote;
    RoutingEngine internal engine;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);

    function setUp() public {
        TestERC20 tokenA = new TestERC20("Base", "BASE");
        TestERC20 tokenB = new TestERC20("Quote", "QUOTE");
        if (address(tokenA) < address(tokenB)) {
            base = tokenA;
            quote = tokenB;
        } else {
            base = tokenB;
            quote = tokenA;
        }
        engine = new RoutingEngine();

        _fundAndApprove(alice);
        _fundAndApprove(bob);
        _fundAndApprove(carol);
    }

    function testGas_FillRestBidEmptyBook() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(100, 5, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, _order(100, 5, type(uint40).max));
        assertEq(_bidRoot(), restingBid);
        vm.resumeGasMetering();
    }

    function testGas_FillRestAskEmptyBook() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(100, 5, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, _order(100, 5, type(uint40).max));
        assertEq(_askRoot(), restingAsk);
        vm.resumeGasMetering();
    }

    function testGas_FillBidFullyMatchesSingleAsk() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingAsk = _fill(_order(90, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(100, 5, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(_askRoot(), bytes32(0));
        assertEq(_ownerOfOrder(restingAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskFullyMatchesSingleBid() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingBid = _fill(_order(100, 5, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(90, 5, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(_bidRoot(), bytes32(0));
        assertEq(_ownerOfOrder(restingBid), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillBidPartiallyMatchesSingleAsk() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingAsk = _fill(_order(90, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(100, 2, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(_askRoot(), _order(90, 3, type(uint40).max));
        assertEq(_ownerOfOrder(restingAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskPartiallyMatchesSingleBid() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        bytes32 restingBid = _fill(_order(100, 5, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(90, 2, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(_bidRoot(), _order(100, 3, type(uint40).max));
        assertEq(_ownerOfOrder(restingBid), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesAskAndRestsRemainder() public {
        vm.pauseGasMetering();
        vm.prank(bob);
        _fill(_order(90, 3, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(100, 5, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, _order(100, 2, type(uint40).max - 1));
        assertEq(_bidRoot(), restingBid);
        assertEq(_askRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_LargeRandomBookBidMatchesOneAsk() public {
        vm.pauseGasMetering();
        LargeRandomBook memory book = _buildLargeRandomBook();

        vm.prank(carol);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(book.bestAskPrice, book.bestAskQuantity, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(_ownerOfOrder(book.bestAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_LargeRandomBookAskMatchesOneBid() public {
        vm.pauseGasMetering();
        LargeRandomBook memory book = _buildLargeRandomBook();

        vm.prank(carol);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(book.bestBidPrice, book.bestBidQuantity, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(_ownerOfOrder(book.bestBid), alice);
        vm.resumeGasMetering();
    }

    function testGas_LargeRandomBookPartialFillsBid() public {
        vm.pauseGasMetering();
        LargeRandomBook memory book = _buildLargeRandomBook();
        uint192 fillQuantity = book.bestBidQuantity - 1;

        vm.prank(carol);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(book.bestBidPrice, fillQuantity, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(_ownerOfOrder(book.bestBid), alice);
        vm.resumeGasMetering();
    }

    function testGas_LargeRandomBookPartialFillsAsk() public {
        vm.pauseGasMetering();
        LargeRandomBook memory book = _buildLargeRandomBook();
        uint192 fillQuantity = book.bestAskQuantity - 1;

        vm.prank(carol);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(book.bestAskPrice, fillQuantity, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(_ownerOfOrder(book.bestAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_LargeRandomBookRestsBid() public {
        vm.pauseGasMetering();
        LargeRandomBook memory book = _buildLargeRandomBook();

        vm.prank(carol);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(LARGE_REST_BID_PRICE, 7, 0), true);
        vm.pauseGasMetering();

        assertTrue(restingBid != bytes32(0));
        assertEq(_ownerOfOrder(restingBid), carol);
        assertEq(_ownerOfOrder(book.bestAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_LargeRandomBookRestsAsk() public {
        vm.pauseGasMetering();
        LargeRandomBook memory book = _buildLargeRandomBook();

        vm.prank(carol);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(LARGE_REST_ASK_PRICE, 7, 0), false);
        vm.pauseGasMetering();

        assertTrue(restingAsk != bytes32(0));
        assertEq(_ownerOfOrder(restingAsk), carol);
        assertEq(_ownerOfOrder(book.bestBid), alice);
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesSamePriceAskSubtree() public {
        vm.pauseGasMetering();
        bytes32 firstAsk;
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            bytes32 restingAsk = _fill(_order(90, 1, 0), false);
            if (i == 0) firstAsk = restingAsk;
        }

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(90, 16, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(_askRoot(), bytes32(0));
        assertEq(_ownerOfOrder(firstAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesDirtySamePriceAskSubtree() public {
        vm.pauseGasMetering();
        bytes32 firstAsk;
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            bytes32 restingAsk = _fill(_order(90, 1, 0), false);
            if (i == 0) firstAsk = restingAsk;
        }

        vm.prank(alice);
        _fill(_order(90, 1, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(90, 15, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(_askRoot(), bytes32(0));
        assertEq(_ownerOfOrder(firstAsk), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskConsumesDirtySamePriceBidSubtree() public {
        vm.pauseGasMetering();
        bytes32 firstBid;
        for (uint256 i; i < 16; ++i) {
            vm.prank(bob);
            bytes32 restingBid = _fill(_order(90, 1, 0), true);
            if (i == 0) firstBid = restingBid;
        }

        vm.prank(alice);
        _fill(_order(90, 1, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(90, 15, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(_bidRoot(), bytes32(0));
        assertEq(_ownerOfOrder(firstBid), bob);
        vm.resumeGasMetering();
    }

    function testGas_FillAskConsumesFullDepthBidComb() public {
        vm.pauseGasMetering();
        _buildFullDepthBidNonceComb();

        address seller = address(0x5E11E2);
        _fundAndApprove(seller);

        vm.prank(seller);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(1, 65, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, bytes32(0));
        assertEq(_bidRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_FillBidConsumesMaxValidDepthAskComb() public {
        vm.pauseGasMetering();
        _buildMaxValidDepthAskNonceComb();

        address buyer = address(0xB0DE6A);
        _fundAndApprove(buyer);
        quote.mint(buyer, 2_000_000_000);

        vm.prank(buyer);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(type(uint24).max, 64, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, bytes32(0));
        assertEq(_askRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelFullDepthBidCombRightmost() public {
        vm.pauseGasMetering();
        bytes32 targetBid = _buildFullDepthBidNonceComb();
        _assertRightSpine(_bidRoot(), targetBid, 64);
        assertEq(_subtreeQuantity(_bidRoot()), 65);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = _cancel(targetBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, type(uint24).max);
        assertEq(_ownerOfOrder(targetBid), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelMaxValidDepthAskCombRightmost() public {
        vm.pauseGasMetering();
        bytes32 targetAsk = _buildMaxValidDepthAskNonceComb();
        _assertRightSpine(_askRoot(), targetAsk, 63);
        assertEq(_subtreeQuantity(_askRoot()), 64);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = _cancel(targetAsk);
        vm.pauseGasMetering();

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(_ownerOfOrder(targetAsk), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelAskSkipsPathologicalBidTree() public {
        vm.pauseGasMetering();
        _buildSamePriceBidNonceComb(1);

        vm.prank(bob);
        bytes32 targetAsk = _fill(_order(2, 1, 0), false);

        vm.prank(bob);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = _cancel(targetAsk);
        vm.pauseGasMetering();

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(_ownerOfOrder(targetAsk), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelUnfilledBid() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingBid = _fill(_order(100, 5, 0), true);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = _cancel(restingBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, 500);
        assertEq(_bidRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelUnfilledAsk() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingAsk = _fill(_order(100, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = _cancel(restingAsk);
        vm.pauseGasMetering();

        assertEq(baseAmount, 5);
        assertEq(quoteAmount, 0);
        assertEq(_askRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelFilledBidClaim() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingBid = _fill(_order(100, 5, 0), true);

        vm.prank(bob);
        _fill(_order(90, 5, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = _cancel(restingBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 5);
        assertEq(quoteAmount, 0);
        assertEq(_ownerOfOrder(restingBid), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelPartialBid() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        bytes32 restingBid = _fill(_order(100, 5, 0), true);

        vm.prank(bob);
        _fill(_order(90, 2, 0), false);

        vm.prank(alice);
        vm.resumeGasMetering();
        (uint256 baseAmount, uint256 quoteAmount) = _cancel(restingBid);
        vm.pauseGasMetering();

        assertEq(baseAmount, 2);
        assertEq(quoteAmount, 300);
        assertEq(_bidRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function _fundAndApprove(address account) internal {
        base.mint(account, 1_000_000);
        quote.mint(account, 1_000_000);

        vm.startPrank(account);
        base.approve(address(engine), type(uint256).max);
        quote.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _fundLargeAndApprove(address account) internal {
        base.mint(account, 1e30);
        quote.mint(account, 1e30);

        vm.startPrank(account);
        base.approve(address(engine), type(uint256).max);
        quote.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _fill(bytes32 order, bool isBid) internal returns (bytes32 restingOrder) {
        restingOrder = engine.fill(
            RoutingEngine.FillParams({
                token0: address(base),
                token1: address(quote),
                epoch: 0,
                order: order,
                isBid: isBid,
                noRest: false,
                fillOrKill: false
            })
        );
    }

    function _cancel(bytes32 order) internal returns (uint256 baseAmount, uint256 quoteAmount) {
        return engine.cancel(address(base), address(quote), 0, order);
    }

    function _bidRoot() internal view returns (bytes32 bidRoot) {
        (, bidRoot) = engine.roots(address(base), address(quote), 0);
    }

    function _askRoot() internal view returns (bytes32 askRoot) {
        (askRoot,) = engine.roots(address(base), address(quote), 0);
    }

    function _ownerOfOrder(bytes32 order) internal view returns (address owner) {
        owner = engine.ownerOfOrder(engine.orderId(_bookId(), order));
    }

    function _tree(bytes32 node) internal view returns (bytes32 leftNode, bytes32 rightNode) {
        return engine.tree(_bookId(), node);
    }

    function _buildLargeRandomBook() internal returns (LargeRandomBook memory book) {
        _fundLargeAndApprove(alice);
        _fundLargeAndApprove(bob);
        _fundLargeAndApprove(carol);

        for (uint256 i; i < LARGE_BOOK_ORDERS;) {
            uint24 price = _largeBidPrice(i);
            uint192 quantity = _largeQuantity(i, 17);

            vm.prank(alice);
            bytes32 restingBid = _fill(_order(price, quantity, 0), true);

            if (price > book.bestBidPrice) {
                book.bestBid = restingBid;
                book.bestBidPrice = price;
                book.bestBidQuantity = quantity;
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < LARGE_BOOK_ORDERS;) {
            uint24 price = _largeAskPrice(i);
            uint192 quantity = _largeQuantity(i, 97);

            vm.prank(bob);
            bytes32 restingAsk = _fill(_order(price, quantity, 0), false);

            if (book.bestAsk == bytes32(0) || price < book.bestAskPrice) {
                book.bestAsk = restingAsk;
                book.bestAskPrice = price;
                book.bestAskQuantity = quantity;
            }

            unchecked {
                ++i;
            }
        }
    }

    function _largeBidPrice(uint256 index) internal pure returns (uint24) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(LARGE_BID_BASE_PRICE) + uint256(_largeOffset(index, 7919)));
    }

    function _largeAskPrice(uint256 index) internal pure returns (uint24) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(LARGE_ASK_BASE_PRICE) + uint256(_largeOffset(index, 313)));
    }

    function _largeOffset(uint256 index, uint256 salt) internal pure returns (uint24) {
        // 4813 is odd, so multiplication by it permutes values modulo 2^13.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24((index * 4813 + salt) & 8191);
    }

    function _largeQuantity(uint256 index, uint256 salt) internal pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192(2 + ((index * 37 + salt) % 9));
    }

    function _buildFullDepthBidNonceComb() internal returns (bytes32 targetOrder) {
        uint64 targetKey = type(uint64).max;
        quote.mint(alice, 2_000_000_000);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = _fill(_order(type(uint24).max, 1, 0), true);

        for (uint256 depth; depth < 64; ++depth) {
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint24 price = uint24(siblingKey >> 40);
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = uint40(siblingKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            _fill(_order(price, 1, 0), true);
        }
    }

    function _buildMaxValidDepthAskNonceComb() internal returns (bytes32 targetOrder) {
        uint24 targetSortPrice = type(uint24).max - 1;

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = _fill(_order(1, 1, 0), false);

        uint256 orderIndex = 1;
        for (uint256 depth; depth < 23; ++depth) {
            // forge-lint: disable-next-line(unsafe-typecast)
            uint24 sortPrice = targetSortPrice ^ uint24(uint256(1) << (23 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = MAX_ORDER_NONCE - uint40(10_000 + orderIndex);
            uint24 price = type(uint24).max - sortPrice;

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            _fill(_order(price, 1, 0), false);

            unchecked {
                ++orderIndex;
            }
        }

        for (uint256 depth = 24; depth < 64; ++depth) {
            uint64 sortKey = (uint64(targetSortPrice) << 40) | uint64(MAX_ORDER_NONCE);
            sortKey ^= uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = uint40(sortKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            _fill(_order(1, 1, 0), false);
        }
    }

    function _buildSamePriceBidNonceComb(uint24 price) internal returns (bytes32 targetOrder) {
        uint64 targetKey = (uint64(price) << 40) | uint64(MAX_ORDER_NONCE);
        quote.mint(alice, 2_000_000_000);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = _fill(_order(price, 1, 0), true);

        for (uint256 depth = 24; depth < 64; ++depth) {
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40 nonce = uint40(siblingKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            _fill(_order(price, 1, 0), true);
        }
    }

    function _order(uint24 price, uint192 quantity, uint40 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(price) << 232) | (uint256(quantity) << 40) | uint256(nonce));
    }

    function _quantity(bytes32 order) internal pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192((uint256(order) >> QUANTITY_SHIFT) & QUANTITY_MASK);
    }

    function _assertRightSpine(bytes32 root, bytes32 expectedLeaf, uint256 expectedBranchCount) internal view {
        bytes32 node = root;
        for (uint256 i; i < expectedBranchCount;) {
            (bytes32 leftNode, bytes32 rightNode) = _tree(node);
            assertTrue(leftNode != bytes32(0));
            assertTrue(rightNode != bytes32(0));
            node = rightNode;
            unchecked {
                ++i;
            }
        }
        assertEq(node, expectedLeaf);
    }

    function _subtreeQuantity(bytes32 node) internal view returns (uint192 quantity) {
        if (node == bytes32(0)) return 0;

        (bytes32 leftNode, bytes32 rightNode) = _tree(node);
        if (leftNode == bytes32(0)) return _quantity(node);

        return _subtreeQuantity(leftNode) + _subtreeQuantity(rightNode);
    }

    function _bookId() internal view returns (bytes32) {
        return engine.bookId(address(base), address(quote), 0);
    }

    function _nextNonceSlot() internal view returns (bytes32) {
        return keccak256(abi.encode(_bookId(), uint256(0)));
    }
}
