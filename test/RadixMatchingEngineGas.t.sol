// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {RoutingEngine} from "../src/RoutingEngine.sol";
import {TickMath32} from "../src/libraries/TickMath32.sol";

contract GasTestERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Gas Test Token";
    }

    function symbol() public pure override returns (string memory) {
        return "GAS";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockHook {
    function execute(bytes32, bytes32, address, uint160, uint32) external {}
}

contract RadixMatchingEngineGasTest is Test {
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;
    uint256 internal constant QUANTITY_SHIFT = 64;
    uint256 internal constant QUANTITY_MASK = (uint256(1) << 160) - 1;
    uint256 internal constant LARGE_BOOK_ORDERS = 5_000;
    int32 internal constant LARGE_BID_BASE_PRICE = 1_000_000;
    int32 internal constant LARGE_ASK_BASE_PRICE = 2_000_000;
    int32 internal constant LARGE_REST_BID_PRICE = 1_750_000;
    int32 internal constant LARGE_REST_ASK_PRICE = 1_750_001;
    uint256 internal constant BOOK_HOOK_TOKEN0_ACTIVE = uint256(1) << 34;
    uint256 internal constant BOOK_HOOK_TOKEN1_ACTIVE = uint256(1) << 35;

    struct LargeRandomBook {
        bytes32 bestBid;
        bytes32 bestAsk;
        int32 bestBidPrice;
        int32 bestAskPrice;
        uint160 bestBidQuantity;
        uint160 bestAskQuantity;
    }

    GasTestERC20 internal base;
    GasTestERC20 internal quote;
    RoutingEngine internal engine;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);

    function setUp() public virtual {
        GasTestERC20 tokenA = new GasTestERC20();
        GasTestERC20 tokenB = new GasTestERC20();
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

        _afterSetUp();
    }

    function _afterSetUp() internal virtual {}

    function testGas_FillRestBidEmptyBook() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(100, 5, 0), true);
        vm.pauseGasMetering();

        assertEq(restingBid, _order(100, 5, type(uint32).max));
        assertEq(_bidRoot(), restingBid);
        vm.resumeGasMetering();
    }

    function testGas_FillRestAskEmptyBook() public {
        vm.pauseGasMetering();
        vm.prank(alice);
        vm.resumeGasMetering();
        bytes32 restingAsk = _fill(_order(100, 5, 0), false);
        vm.pauseGasMetering();

        assertEq(restingAsk, _order(100, 5, type(uint32).max));
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
        assertEq(_askRoot(), _order(90, 3, type(uint32).max));
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
        assertEq(_bidRoot(), _order(100, 3, type(uint32).max));
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

        assertEq(restingBid, _order(100, 2, type(uint32).max - 1));
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
        uint160 fillQuantity = book.bestBidQuantity - 1;

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
        uint160 fillQuantity = book.bestAskQuantity - 1;

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
        bytes32 restingAsk = _fill(_order(type(int32).min, 65, 0), false);
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
        quote.mint(buyer, uint256(1) << 200);

        vm.prank(buyer);
        vm.resumeGasMetering();
        bytes32 restingBid = _fill(_order(type(int32).max, 65, 0), true);
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
        assertEq(quoteAmount, _quoteValue(type(int32).max, 1, true));
        assertEq(_ownerOfOrder(targetBid), address(0));
        vm.resumeGasMetering();
    }

    function testGas_CancelMaxValidDepthAskCombRightmost() public {
        vm.pauseGasMetering();
        bytes32 targetAsk = _buildMaxValidDepthAskNonceComb();
        _assertRightSpine(_askRoot(), targetAsk, 64);
        assertEq(_subtreeQuantity(_askRoot()), 65);

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
        assertEq(quoteAmount, _quoteValue(100, 5, true));
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
        assertEq(quoteAmount, _quoteValue(100, 3, true));
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
            int32 price = _largeBidPrice(i);
            uint160 quantity = _largeQuantity(i, 17);

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
            int32 price = _largeAskPrice(i);
            uint160 quantity = _largeQuantity(i, 97);

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

    function _largeBidPrice(uint256 index) internal pure returns (int32) {
        return LARGE_BID_BASE_PRICE + _largeOffset(index, 7919);
    }

    function _largeAskPrice(uint256 index) internal pure returns (int32) {
        return LARGE_ASK_BASE_PRICE + _largeOffset(index, 313);
    }

    function _largeOffset(uint256 index, uint256 salt) internal pure returns (int32) {
        // 4813 is odd, so multiplication by it permutes values modulo 2^13.
        // forge-lint: disable-next-line(unsafe-typecast)
        return int32(uint32((index * 4813 + salt) & 8191));
    }

    function _largeQuantity(uint256 index, uint256 salt) internal pure returns (uint160) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160(2 + ((index * 37 + salt) % 9));
    }

    function _buildFullDepthBidNonceComb() internal returns (bytes32 targetOrder) {
        uint64 targetKey = type(uint64).max;
        quote.mint(alice, uint256(1) << 200);

        vm.store(address(engine), _nextNonceSlot(), bytes32(_nonceAndFlags(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = _fill(_order(type(int32).max, 1, 0), true);

        for (uint256 depth; depth < 64; ++depth) {
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            int32 price = int32(uint32(siblingKey >> 32) ^ 0x80000000);
            // forge-lint: disable-next-line(unsafe-typecast)
            uint32 nonce = uint32(siblingKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(_nonceAndFlags(nonce)));
            vm.prank(alice);
            _fill(_order(price, 1, 0), true);
        }
    }

    function _buildMaxValidDepthAskNonceComb() internal returns (bytes32 targetOrder) {
        uint64 targetSortKey = type(uint64).max;

        vm.store(address(engine), _nextNonceSlot(), bytes32(_nonceAndFlags(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = _fill(_order(type(int32).min, 1, 0), false);

        for (uint256 depth; depth < 64; ++depth) {
            uint64 sortKey = targetSortKey ^ uint64(uint256(1) << (63 - depth));
            uint32 sortableTick = type(uint32).max - uint32(sortKey >> 32);
            int32 price = int32(sortableTick ^ 0x80000000);
            // forge-lint: disable-next-line(unsafe-typecast)
            uint32 nonce = uint32(sortKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(_nonceAndFlags(nonce)));
            vm.prank(alice);
            _fill(_order(price, 1, 0), false);
        }
    }

    function _buildSamePriceBidNonceComb(int32 price) internal returns (bytes32 targetOrder) {
        uint64 targetKey = (uint64(uint32(price) ^ 0x80000000) << 32) | uint64(MAX_ORDER_NONCE);
        quote.mint(alice, 2_000_000_000);

        vm.store(address(engine), _nextNonceSlot(), bytes32(_nonceAndFlags(MAX_ORDER_NONCE)));
        vm.prank(alice);
        targetOrder = _fill(_order(price, 1, 0), true);

        for (uint256 depth = 32; depth < 64; ++depth) {
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            uint32 nonce = uint32(siblingKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(_nonceAndFlags(nonce)));
            vm.prank(alice);
            _fill(_order(price, 1, 0), true);
        }
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) internal pure returns (uint256) {
        uint256 sqrtPriceX96 = TickMath32.getSqrtRatioAtTick(tick);
        uint256 priceX128 = FixedPointMathLib.fullMulDivN(sqrtPriceX96, sqrtPriceX96, 64);
        return roundUp
            ? FixedPointMathLib.fullMulDivUp(uint256(quantity), priceX128, uint256(1) << 128)
            : FixedPointMathLib.fullMulDiv(uint256(quantity), priceX128, uint256(1) << 128);
    }

    function _quantity(bytes32 order) internal pure returns (uint160) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160((uint256(order) >> QUANTITY_SHIFT) & QUANTITY_MASK);
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

    function _subtreeQuantity(bytes32 node) internal view returns (uint160 quantity) {
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

    function _nonceAndFlags(uint256 nonce) internal pure virtual returns (uint256) {
        return nonce;
    }
}

contract RadixMatchingEngineHookGasTest is RadixMatchingEngineGasTest {
    MockHook internal hook;

    function _afterSetUp() internal override {
        hook = new MockHook();
        engine.setPoolHookConfig(address(base), address(quote), address(hook), true, true);
    }

    function _nonceAndFlags(uint256 nonce) internal pure override returns (uint256) {
        return nonce | BOOK_HOOK_TOKEN0_ACTIVE | BOOK_HOOK_TOKEN1_ACTIVE;
    }
}

contract RadixMatchingEngineFeeGasTest is RadixMatchingEngineGasTest {
    function _afterSetUp() internal override {
        engine.setFeeConfig(address(0xFEE), 100);
    }
}
