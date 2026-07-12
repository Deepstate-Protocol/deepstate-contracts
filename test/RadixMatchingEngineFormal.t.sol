// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SinglePairEngineHarness as RadixMatchingEngine} from "./SinglePairEngineHarness.sol";
import {QuoteMath} from "./QuoteMath.sol";

/// @dev Minimal conventional ERC20 model for symbolic matching proofs. The integration suite
/// separately exercises Solady ERC20s, false-return tokens, and reentrant tokens.
contract FormalERC20 {
    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract RadixMatchingEngineFormalTest is Test {
    uint256 internal constant INITIAL_BALANCE = 1_000_000_000;
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;
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

    /// @dev Keeps price and maker size concrete, then symbolically partitions the incoming size
    /// into underfill, exact-fill, and overfill cases. Arbitrary quantities remain covered by
    /// Foundry fuzzing and the stateful invariant suite; TickMath32 has an independent oracle.
    function testFuzz_FormalBidAgainstAskConservesAndClaims(bool exactFill, bool overfill) public {
        int32 price = 60;
        uint160 askQty = 4;
        uint160 bidQty = exactFill ? 4 : (overfill ? 5 : 3);
        uint160 matched = _min(askQty, bidQty);
        uint160 askRemaining = askQty - matched;
        uint160 bidRemaining = bidQty - matched;
        uint256 matchedQuote = _quoteValue(price, askQty, false) - _quoteValue(price, askRemaining, false);

        vm.prank(ALICE);
        bytes32 ask = engine.fill(_order(price, askQty, 0), false);

        vm.prank(BOB);
        bytes32 bid = engine.fill(_order(price, bidQty, 0), true);

        assert(base.balanceOf(BOB) == INITIAL_BALANCE + matched);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE - matchedQuote - _quoteValue(price, bidRemaining, true));

        vm.prank(ALICE);
        (uint256 askBase, uint256 askQuote) = engine.cancel(ask);
        assert(askBase == askRemaining);
        assert(askQuote == matchedQuote);

        if (bidQty > askQty) {
            assert(bid == _order(price, bidRemaining, MAX_ORDER_NONCE - 1));
            vm.prank(BOB);
            (uint256 bidBase, uint256 bidQuote) = engine.cancel(bid);
            assert(bidBase == 0);
            assert(bidQuote == _quoteValue(price, bidRemaining, true));
        } else {
            assert(bid == bytes32(0));
        }

        _assertEmptyBook();
        assert(base.balanceOf(ALICE) == INITIAL_BALANCE - matched);
        assert(quote.balanceOf(ALICE) == INITIAL_BALANCE + matchedQuote);
        assert(base.balanceOf(BOB) == INITIAL_BALANCE + matched);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE - matchedQuote);
    }

    /// @dev Mirrors `testFuzz_FormalBidAgainstAskConservesAndClaims` with a concrete bid maker.
    function testFuzz_FormalAskAgainstBidConservesAndClaims(bool exactFill, bool overfill) public {
        int32 price = 60;
        uint160 bidQty = 4;
        uint160 askQty = exactFill ? 4 : (overfill ? 5 : 3);
        uint160 matched = _min(bidQty, askQty);
        uint160 bidRemaining = bidQty - matched;
        uint160 askRemaining = askQty - matched;
        uint256 matchedQuote = _quoteValue(price, bidQty, true) - _quoteValue(price, bidRemaining, true);

        vm.prank(ALICE);
        bytes32 bid = engine.fill(_order(price, bidQty, 0), true);

        vm.prank(BOB);
        bytes32 ask = engine.fill(_order(price, askQty, 0), false);

        assert(base.balanceOf(BOB) == INITIAL_BALANCE - askQty);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE + matchedQuote);

        vm.prank(ALICE);
        (uint256 bidBase, uint256 bidQuote) = engine.cancel(bid);
        assert(bidBase == matched);
        assert(bidQuote == _quoteValue(price, bidRemaining, true));

        if (askQty > bidQty) {
            assert(ask == _order(price, askRemaining, MAX_ORDER_NONCE - 1));
            vm.prank(BOB);
            (uint256 askBase, uint256 askQuote) = engine.cancel(ask);
            assert(askBase == askRemaining);
            assert(askQuote == 0);
        } else {
            assert(ask == bytes32(0));
        }

        _assertEmptyBook();
        assert(base.balanceOf(ALICE) == INITIAL_BALANCE + matched);
        assert(quote.balanceOf(ALICE) == INITIAL_BALANCE - matchedQuote);
        assert(base.balanceOf(BOB) == INITIAL_BALANCE - matched);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE + matchedQuote);
    }

    function testFuzz_DirtySamePriceAskRightSpineConserves(
        uint8 priceSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        int32 price = _price(priceSeed);
        uint160 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint160 secondQty = _qty(secondQtySeed);
        uint160 firstFill = _partialFill(firstFillSeed, firstQty);
        uint160 remaining = firstQty - firstFill;

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
        assert(firstQuote == _quoteValue(price, firstQty, false));
        assert(secondBase == 0);
        assert(secondQuote == _quoteValue(price, secondQty, false));
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + firstQty + secondQty);
        assert(
            quote.balanceOf(CAROL)
                == INITIAL_BALANCE - _quoteValue(price, firstQty, false) - _quoteValue(price, secondQty, false)
        );
    }

    function testFuzz_DirtySamePriceBidRightSpineConserves(
        uint8 priceSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        int32 price = _price(priceSeed);
        uint160 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint160 secondQty = _qty(secondQtySeed);
        uint160 firstFill = _partialFill(firstFillSeed, firstQty);
        uint160 remaining = firstQty - firstFill;

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
        assert(
            quote.balanceOf(CAROL)
                == INITIAL_BALANCE + _quoteValue(price, firstQty, true) + _quoteValue(price, secondQty, true)
        );
    }

    function testFuzz_DirtyMixedPriceAskRightSpineConserves(
        uint8 lowPriceSeed,
        uint8 highPriceOffsetSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        int32 lowPrice = _price(lowPriceSeed);
        int32 highPrice = lowPrice + _priceOffset(highPriceOffsetSeed);
        uint160 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint160 secondQty = _qty(secondQtySeed);
        uint160 firstFill = _partialFill(firstFillSeed, firstQty);
        uint160 remaining = firstQty - firstFill;

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
        assert(lowQuote == _quoteValue(lowPrice, firstQty, false));
        assert(highBase == 0);
        assert(highQuote == _quoteValue(highPrice, secondQty, false));
        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + firstQty + secondQty);
        assert(
            quote.balanceOf(CAROL)
                == INITIAL_BALANCE - _quoteValue(lowPrice, firstQty, false) - _quoteValue(highPrice, secondQty, false)
        );
    }

    function testFuzz_DirtyMixedPriceBidRightSpineConserves(
        uint8 lowPriceSeed,
        uint8 highPriceOffsetSeed,
        uint8 firstQtySeed,
        uint8 secondQtySeed,
        uint8 firstFillSeed
    ) public {
        int32 lowPrice = _price(lowPriceSeed);
        int32 highPrice = lowPrice + _priceOffset(highPriceOffsetSeed);
        uint160 firstQty = _qtyAtLeastTwo(firstQtySeed);
        uint160 secondQty = _qty(secondQtySeed);
        uint160 firstFill = _partialFill(firstFillSeed, firstQty);
        uint160 remaining = firstQty - firstFill;

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
                == INITIAL_BALANCE + _quoteValue(highPrice, firstQty, true) + _quoteValue(lowPrice, secondQty, true)
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

    function _price(uint8 seed) private pure returns (int32) {
        return int32(uint32(uint256(seed) + 1));
    }

    function _qty(uint8 seed) private pure returns (uint160) {
        return (uint160(seed) % 8) + 1;
    }

    function _qtyAtLeastTwo(uint8 seed) private pure returns (uint160) {
        return (uint160(seed) % 7) + 2;
    }

    function _partialFill(uint8 seed, uint160 quantity) private pure returns (uint160) {
        return (uint160(seed) % (quantity - 1)) + 1;
    }

    function _priceOffset(uint8 seed) private pure returns (int32) {
        return (int32(uint32(seed)) % 8) + 1;
    }

    function _min(uint160 a, uint160 b) private pure returns (uint160) {
        return a < b ? a : b;
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) private pure returns (uint256 quoteAmount) {
        quoteAmount = QuoteMath.quoteValue(tick, quantity, roundUp);
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) private pure returns (bytes32) {
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }
}
