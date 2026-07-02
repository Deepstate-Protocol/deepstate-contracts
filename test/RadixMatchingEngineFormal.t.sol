// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SinglePairEngineHarness as RadixMatchingEngine} from "./SinglePairEngineHarness.sol";

contract FormalERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Formal";
    }

    function symbol() public pure override returns (string memory) {
        return "FORMAL";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RadixMatchingEngineFormalTest is Test {
    uint256 internal constant INITIAL_BALANCE = 1_000_000_000;
    uint40 internal constant MAX_ORDER_NONCE = type(uint40).max;
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant CAROL = address(0xCA701);

    FormalERC20 internal base;
    FormalERC20 internal quote;
    RadixMatchingEngine internal engine;

    function setUp() public {
        base = new FormalERC20();
        quote = new FormalERC20();
        engine = new RadixMatchingEngine(address(base), address(quote));

        _fundAndApprove(ALICE);
        _fundAndApprove(BOB);
        _fundAndApprove(CAROL);
    }

    function testFuzz_FormalBidAgainstAskConservesAndClaims(uint8 priceSeed, uint8 askQtySeed, uint8 bidQtySeed)
        public
    {
        uint24 price = _price(priceSeed);
        uint192 askQty = _qty(askQtySeed);
        uint192 bidQty = _qty(bidQtySeed);
        uint192 matched = _min(askQty, bidQty);

        vm.prank(ALICE);
        bytes32 ask = engine.fill(_order(price, askQty, 0), false);

        vm.prank(BOB);
        bytes32 bid = engine.fill(_order(price, bidQty, 0), true);

        assert(base.balanceOf(BOB) == INITIAL_BALANCE + matched);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE - _quoteValue(price, bidQty));

        vm.prank(ALICE);
        (uint256 askBase, uint256 askQuote) = engine.cancel(ask);
        assert(askBase == askQty - matched);
        assert(askQuote == _quoteValue(price, matched));

        if (bidQty > askQty) {
            assert(bid == _order(price, bidQty - matched, MAX_ORDER_NONCE - 1));
            vm.prank(BOB);
            (uint256 bidBase, uint256 bidQuote) = engine.cancel(bid);
            assert(bidBase == 0);
            assert(bidQuote == _quoteValue(price, bidQty - matched));
        } else {
            assert(bid == bytes32(0));
        }

        _assertEmptyBook();
        assert(base.balanceOf(ALICE) == INITIAL_BALANCE - matched);
        assert(quote.balanceOf(ALICE) == INITIAL_BALANCE + _quoteValue(price, matched));
        assert(base.balanceOf(BOB) == INITIAL_BALANCE + matched);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE - _quoteValue(price, matched));
    }

    function testFuzz_FormalAskAgainstBidConservesAndClaims(uint8 priceSeed, uint8 bidQtySeed, uint8 askQtySeed)
        public
    {
        uint24 price = _price(priceSeed);
        uint192 bidQty = _qty(bidQtySeed);
        uint192 askQty = _qty(askQtySeed);
        uint192 matched = _min(bidQty, askQty);

        vm.prank(ALICE);
        bytes32 bid = engine.fill(_order(price, bidQty, 0), true);

        vm.prank(BOB);
        bytes32 ask = engine.fill(_order(price, askQty, 0), false);

        assert(base.balanceOf(BOB) == INITIAL_BALANCE - askQty);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE + _quoteValue(price, matched));

        vm.prank(ALICE);
        (uint256 bidBase, uint256 bidQuote) = engine.cancel(bid);
        assert(bidBase == matched);
        assert(bidQuote == _quoteValue(price, bidQty - matched));

        if (askQty > bidQty) {
            assert(ask == _order(price, askQty - matched, MAX_ORDER_NONCE - 1));
            vm.prank(BOB);
            (uint256 askBase, uint256 askQuote) = engine.cancel(ask);
            assert(askBase == askQty - matched);
            assert(askQuote == 0);
        } else {
            assert(ask == bytes32(0));
        }

        _assertEmptyBook();
        assert(base.balanceOf(ALICE) == INITIAL_BALANCE + matched);
        assert(quote.balanceOf(ALICE) == INITIAL_BALANCE - _quoteValue(price, matched));
        assert(base.balanceOf(BOB) == INITIAL_BALANCE - matched);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE + _quoteValue(price, matched));
    }

    function testFuzz_DirtySamePriceAskRightSpineConserves(
        uint8 priceSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        uint24 price = _price(priceSeed);
        uint192 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint192 secondQty = _qty(secondQtySeed);
        uint192 firstFill = _partialFill(firstFillSeed, firstQty);
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 firstAsk = engine.fill(_order(price, firstQty, 0), false);
        vm.prank(BOB);
        bytes32 secondAsk = engine.fill(_order(price, secondQty, 0), false);

        vm.prank(CAROL);
        assert(engine.fill(_order(price, firstFill, 0), true) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(price, remaining + secondQty, 0), true) == bytes32(0));

        vm.prank(ALICE);
        (uint256 firstBase, uint256 firstQuote) = engine.cancel(firstAsk);
        vm.prank(BOB);
        (uint256 secondBase, uint256 secondQuote) = engine.cancel(secondAsk);

        assert(firstBase == 0);
        assert(firstQuote == _quoteValue(price, firstQty));
        assert(secondBase == 0);
        assert(secondQuote == _quoteValue(price, secondQty));
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + firstQty + secondQty);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE - _quoteValue(price, firstQty + secondQty));
    }

    function testFuzz_DirtySamePriceBidRightSpineConserves(
        uint8 priceSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        uint24 price = _price(priceSeed);
        uint192 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint192 secondQty = _qty(secondQtySeed);
        uint192 firstFill = _partialFill(firstFillSeed, firstQty);
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 firstBid = engine.fill(_order(price, firstQty, 0), true);
        vm.prank(BOB);
        bytes32 secondBid = engine.fill(_order(price, secondQty, 0), true);

        vm.prank(CAROL);
        assert(engine.fill(_order(price, firstFill, 0), false) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(price, remaining + secondQty, 0), false) == bytes32(0));

        vm.prank(ALICE);
        (uint256 firstBase, uint256 firstQuote) = engine.cancel(firstBid);
        vm.prank(BOB);
        (uint256 secondBase, uint256 secondQuote) = engine.cancel(secondBid);

        assert(firstBase == firstQty);
        assert(firstQuote == 0);
        assert(secondBase == secondQty);
        assert(secondQuote == 0);
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE - firstQty - secondQty);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE + _quoteValue(price, firstQty + secondQty));
    }

    function testFuzz_DirtyMixedPriceAskRightSpineConserves(
        uint8 lowPriceSeed,
        uint8 highPriceOffsetSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        uint24 lowPrice = _price(lowPriceSeed);
        uint24 highPrice = lowPrice + _priceOffset(highPriceOffsetSeed);
        uint192 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint192 secondQty = _qty(secondQtySeed);
        uint192 firstFill = _partialFill(firstFillSeed, firstQty);
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 lowAsk = engine.fill(_order(lowPrice, firstQty, 0), false);
        vm.prank(BOB);
        bytes32 highAsk = engine.fill(_order(highPrice, secondQty, 0), false);

        vm.prank(CAROL);
        assert(engine.fill(_order(lowPrice, firstFill, 0), true) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(highPrice, remaining + secondQty, 0), true) == bytes32(0));

        vm.prank(ALICE);
        (uint256 lowBase, uint256 lowQuote) = engine.cancel(lowAsk);
        vm.prank(BOB);
        (uint256 highBase, uint256 highQuote) = engine.cancel(highAsk);

        assert(lowBase == 0);
        assert(lowQuote == _quoteValue(lowPrice, firstQty));
        assert(highBase == 0);
        assert(highQuote == _quoteValue(highPrice, secondQty));
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + firstQty + secondQty);
        assert(
            quote.balanceOf(CAROL)
                == INITIAL_BALANCE - _quoteValue(lowPrice, firstQty) - _quoteValue(highPrice, secondQty)
        );
    }

    function testFuzz_DirtyMixedPriceBidRightSpineConserves(
        uint8 lowPriceSeed,
        uint8 highPriceOffsetSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        uint24 lowPrice = _price(lowPriceSeed);
        uint24 highPrice = lowPrice + _priceOffset(highPriceOffsetSeed);
        uint192 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint192 secondQty = _qty(secondQtySeed);
        uint192 firstFill = _partialFill(firstFillSeed, firstQty);
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 highBid = engine.fill(_order(highPrice, firstQty, 0), true);
        vm.prank(BOB);
        bytes32 lowBid = engine.fill(_order(lowPrice, secondQty, 0), true);

        vm.prank(CAROL);
        assert(engine.fill(_order(highPrice, firstFill, 0), false) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(lowPrice, remaining + secondQty, 0), false) == bytes32(0));

        vm.prank(ALICE);
        (uint256 highBase, uint256 highQuote) = engine.cancel(highBid);
        vm.prank(BOB);
        (uint256 lowBase, uint256 lowQuote) = engine.cancel(lowBid);

        assert(highBase == firstQty);
        assert(highQuote == 0);
        assert(lowBase == secondQty);
        assert(lowQuote == 0);
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE - firstQty - secondQty);
        assert(
            quote.balanceOf(CAROL)
                == INITIAL_BALANCE + _quoteValue(highPrice, firstQty) + _quoteValue(lowPrice, secondQty)
        );
    }

    function testFuzz_FormalDirtySamePriceAskRightSpineConserves() public {
        uint24 price = 60;
        uint192 firstQty = 3;
        uint192 secondQty = 2;
        uint192 firstFill = 1;
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 firstAsk = engine.fill(_order(price, firstQty, 0), false);
        vm.prank(BOB);
        bytes32 secondAsk = engine.fill(_order(price, secondQty, 0), false);

        vm.prank(CAROL);
        assert(engine.fill(_order(price, firstFill, 0), true) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(price, remaining + secondQty, 0), true) == bytes32(0));

        vm.prank(ALICE);
        (uint256 firstBase, uint256 firstQuote) = engine.cancel(firstAsk);
        vm.prank(BOB);
        (uint256 secondBase, uint256 secondQuote) = engine.cancel(secondAsk);

        assert(firstBase == 0);
        assert(firstQuote == _quoteValue(price, firstQty));
        assert(secondBase == 0);
        assert(secondQuote == _quoteValue(price, secondQty));
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + firstQty + secondQty);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE - _quoteValue(price, firstQty + secondQty));
    }

    function testFuzz_FormalDirtySamePriceBidRightSpineConserves() public {
        uint24 price = 70;
        uint192 firstQty = 3;
        uint192 secondQty = 2;
        uint192 firstFill = 1;
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 firstBid = engine.fill(_order(price, firstQty, 0), true);
        vm.prank(BOB);
        bytes32 secondBid = engine.fill(_order(price, secondQty, 0), true);

        vm.prank(CAROL);
        assert(engine.fill(_order(price, firstFill, 0), false) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(price, remaining + secondQty, 0), false) == bytes32(0));

        vm.prank(ALICE);
        (uint256 firstBase, uint256 firstQuote) = engine.cancel(firstBid);
        vm.prank(BOB);
        (uint256 secondBase, uint256 secondQuote) = engine.cancel(secondBid);

        assert(firstBase == firstQty);
        assert(firstQuote == 0);
        assert(secondBase == secondQty);
        assert(secondQuote == 0);
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE - firstQty - secondQty);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE + _quoteValue(price, firstQty + secondQty));
    }

    function testFuzz_FormalDirtyMixedPriceAskRightSpineConserves() public {
        uint24 lowPrice = 60;
        uint24 highPrice = 61;
        uint192 firstQty = 3;
        uint192 secondQty = 2;
        uint192 firstFill = 1;
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 lowAsk = engine.fill(_order(lowPrice, firstQty, 0), false);
        vm.prank(BOB);
        bytes32 highAsk = engine.fill(_order(highPrice, secondQty, 0), false);

        vm.prank(CAROL);
        assert(engine.fill(_order(lowPrice, firstFill, 0), true) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(highPrice, remaining + secondQty, 0), true) == bytes32(0));

        vm.prank(ALICE);
        (uint256 lowBase, uint256 lowQuote) = engine.cancel(lowAsk);
        vm.prank(BOB);
        (uint256 highBase, uint256 highQuote) = engine.cancel(highAsk);

        assert(lowBase == 0);
        assert(lowQuote == _quoteValue(lowPrice, firstQty));
        assert(highBase == 0);
        assert(highQuote == _quoteValue(highPrice, secondQty));
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + firstQty + secondQty);
        assert(
            quote.balanceOf(CAROL)
                == INITIAL_BALANCE - _quoteValue(lowPrice, firstQty) - _quoteValue(highPrice, secondQty)
        );
    }

    function testFuzz_FormalDirtyMixedPriceBidRightSpineConserves() public {
        uint24 lowPrice = 69;
        uint24 highPrice = 70;
        uint192 firstQty = 3;
        uint192 secondQty = 2;
        uint192 firstFill = 1;
        uint192 remaining = firstQty - firstFill;

        vm.prank(ALICE);
        bytes32 highBid = engine.fill(_order(highPrice, firstQty, 0), true);
        vm.prank(BOB);
        bytes32 lowBid = engine.fill(_order(lowPrice, secondQty, 0), true);

        vm.prank(CAROL);
        assert(engine.fill(_order(highPrice, firstFill, 0), false) == bytes32(0));

        vm.prank(CAROL);
        assert(engine.fill(_order(lowPrice, remaining + secondQty, 0), false) == bytes32(0));

        vm.prank(ALICE);
        (uint256 highBase, uint256 highQuote) = engine.cancel(highBid);
        vm.prank(BOB);
        (uint256 lowBase, uint256 lowQuote) = engine.cancel(lowBid);

        assert(highBase == firstQty);
        assert(highQuote == 0);
        assert(lowBase == secondQty);
        assert(lowQuote == 0);
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE - firstQty - secondQty);
        assert(
            quote.balanceOf(CAROL)
                == INITIAL_BALANCE + _quoteValue(highPrice, firstQty) + _quoteValue(lowPrice, secondQty)
        );
    }

    function _fundAndApprove(address trader) private {
        base.mint(trader, INITIAL_BALANCE);
        quote.mint(trader, INITIAL_BALANCE);

        vm.startPrank(trader);
        base.approve(address(engine), type(uint256).max);
        quote.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _assertEmptyBook() private view {
        assert(engine.bidRoot() == bytes32(0));
        assert(engine.askRoot() == bytes32(0));
        assert(base.balanceOf(address(engine)) == 0);
        assert(quote.balanceOf(address(engine)) == 0);
    }

    function _price(uint8 seed) private pure returns (uint24) {
        return uint24(uint256(seed) + 1);
    }

    function _qty(uint8 seed) private pure returns (uint192) {
        return (uint192(seed) % 8) + 1;
    }

    function _qtyAtLeastTwo(uint8 seed) private pure returns (uint192) {
        return (uint192(seed) % 7) + 2;
    }

    function _partialFill(uint8 seed, uint192 quantity) private pure returns (uint192) {
        return (uint192(seed) % (quantity - 1)) + 1;
    }

    function _priceOffset(uint8 seed) private pure returns (uint24) {
        return (uint24(seed) % 8) + 1;
    }

    function _min(uint192 a, uint192 b) private pure returns (uint192) {
        return a < b ? a : b;
    }

    function _quoteValue(uint24 price, uint192 quantity) private pure returns (uint256) {
        return uint256(price) * uint256(quantity);
    }

    function _order(uint24 price, uint192 quantity, uint40 nonce) private pure returns (bytes32) {
        return bytes32((uint256(price) << 232) | (uint256(quantity) << 40) | uint256(nonce));
    }
}
