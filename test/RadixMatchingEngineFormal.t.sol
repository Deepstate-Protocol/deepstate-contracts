// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";
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

/// @dev Test-only epoch control used to make nonce exhaustion reachable in a bounded proof.
/// Production rotation still performs the state transition being verified.
contract FormalEpochEngine is DeepstateV1 {
    function forceNextNonce(address token0, address token1, uint256 epoch, uint32 nonce) external {
        bytes32 id = bookId(token0, token1, epoch);
        uint256 nonceAndFlags = books[id].nonceAndFlags;
        books[id].nonceAndFlags = (nonceAndFlags & ~uint256(type(uint32).max)) | uint256(nonce);
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

    /// @dev Proves every underfill, exact-fill, and overfill relation for quantities in `[1, 8]`.
    /// The bounded symbolic domain is sufficient to cover every control-flow relation while the
    /// full-width arithmetic domain remains covered independently by fuzzing and boundary tests.
    function testFuzz_FormalBidAgainstAskConservesAndClaims(uint8 askQtyRaw, uint8 bidQtyRaw) public {
        vm.assume(askQtyRaw >= 1 && askQtyRaw <= 8);
        vm.assume(bidQtyRaw >= 1 && bidQtyRaw <= 8);
        int32 price = 60;
        uint160 askQty = uint160(askQtyRaw);
        uint160 bidQty = uint160(bidQtyRaw);
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

    /// @dev Mirrors `testFuzz_FormalBidAgainstAskConservesAndClaims` with a bid maker.
    function testFuzz_FormalAskAgainstBidConservesAndClaims(uint8 bidQtyRaw, uint8 askQtyRaw) public {
        vm.assume(bidQtyRaw >= 1 && bidQtyRaw <= 8);
        vm.assume(askQtyRaw >= 1 && askQtyRaw <= 8);
        int32 price = 60;
        uint160 bidQty = uint160(bidQtyRaw);
        uint160 askQty = uint160(askQtyRaw);
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

    /// @dev Proves same-tick ask aggregation, FIFO consumption, correction accounting, and claims
    /// across the four distinct aggregate outcomes: stop in the first maker, stop in the second,
    /// exact aggregate fill, and overfill with a resting taker remainder.
    function testFuzz_FormalSameTickAskAggregateConserves(bool stopInFirst, bool stopInSecond, bool overfill) public {
        int32 price = 60;
        uint160 firstQty = 4;
        uint160 secondQty = 5;
        uint160 takerQty = stopInFirst ? 3 : (stopInSecond ? 6 : (overfill ? 10 : 9));
        uint160 firstFilled = _min(firstQty, takerQty);
        uint160 secondFilled = _min(secondQty, takerQty - firstFilled);
        uint160 matched = firstFilled + secondFilled;
        uint160 firstRemaining = firstQty - firstFilled;
        uint160 secondRemaining = secondQty - secondFilled;
        uint160 takerRemaining = takerQty - matched;
        uint256 firstQuote = _quoteValue(price, firstQty, false) - _quoteValue(price, firstRemaining, false);
        uint256 secondQuote = _quoteValue(price, secondQty, false) - _quoteValue(price, secondRemaining, false);

        vm.prank(ALICE);
        bytes32 first = engine.fill(_order(price, firstQty, 0), false);
        vm.prank(BOB);
        bytes32 second = engine.fill(_order(price, secondQty, 0), false);
        vm.prank(CAROL);
        bytes32 taker = engine.fill(_order(price, takerQty, 0), true);

        vm.prank(ALICE);
        (uint256 firstBase, uint256 firstClaim) = engine.cancel(first);
        vm.prank(BOB);
        (uint256 secondBase, uint256 secondClaim) = engine.cancel(second);
        assert(firstBase == firstRemaining);
        assert(firstClaim == firstQuote);
        assert(secondBase == secondRemaining);
        assert(secondClaim == secondQuote);

        if (takerRemaining != 0) {
            assert(taker != bytes32(0));
            vm.prank(CAROL);
            (uint256 takerBase, uint256 takerQuote) = engine.cancel(taker);
            assert(takerBase == 0);
            assert(takerQuote == _quoteValue(price, takerRemaining, true));
        } else {
            assert(taker == bytes32(0));
        }

        _assertEmptyBook();
        assert(base.balanceOf(ALICE) == INITIAL_BALANCE - firstFilled);
        assert(quote.balanceOf(ALICE) == INITIAL_BALANCE + firstQuote);
        assert(base.balanceOf(BOB) == INITIAL_BALANCE - secondFilled);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE + secondQuote);
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + matched);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE - firstQuote - secondQuote);
    }

    /// @dev Bid-side mirror of `testFuzz_FormalSameTickAskAggregateConserves`.
    function testFuzz_FormalSameTickBidAggregateConserves(bool stopInFirst, bool stopInSecond, bool overfill) public {
        int32 price = 60;
        uint160 firstQty = 4;
        uint160 secondQty = 5;
        uint160 takerQty = stopInFirst ? 3 : (stopInSecond ? 6 : (overfill ? 10 : 9));
        uint160 firstFilled = _min(firstQty, takerQty);
        uint160 secondFilled = _min(secondQty, takerQty - firstFilled);
        uint160 matched = firstFilled + secondFilled;
        uint160 firstRemaining = firstQty - firstFilled;
        uint160 secondRemaining = secondQty - secondFilled;
        uint160 takerRemaining = takerQty - matched;
        uint256 firstQuote = _quoteValue(price, firstQty, true) - _quoteValue(price, firstRemaining, true);
        uint256 secondQuote = _quoteValue(price, secondQty, true) - _quoteValue(price, secondRemaining, true);

        vm.prank(ALICE);
        bytes32 first = engine.fill(_order(price, firstQty, 0), true);
        vm.prank(BOB);
        bytes32 second = engine.fill(_order(price, secondQty, 0), true);
        vm.prank(CAROL);
        bytes32 taker = engine.fill(_order(price, takerQty, 0), false);

        vm.prank(ALICE);
        (uint256 firstBase, uint256 firstCollateral) = engine.cancel(first);
        vm.prank(BOB);
        (uint256 secondBase, uint256 secondCollateral) = engine.cancel(second);
        assert(firstBase == firstFilled);
        assert(firstCollateral == _quoteValue(price, firstRemaining, true));
        assert(secondBase == secondFilled);
        assert(secondCollateral == _quoteValue(price, secondRemaining, true));

        if (takerRemaining != 0) {
            assert(taker != bytes32(0));
            vm.prank(CAROL);
            (uint256 takerBase, uint256 takerQuote) = engine.cancel(taker);
            assert(takerBase == takerRemaining);
            assert(takerQuote == 0);
        } else {
            assert(taker == bytes32(0));
        }

        _assertEmptyBook();
        assert(base.balanceOf(ALICE) == INITIAL_BALANCE + firstFilled);
        assert(quote.balanceOf(ALICE) == INITIAL_BALANCE - firstQuote);
        assert(base.balanceOf(BOB) == INITIAL_BALANCE + secondFilled);
        assert(quote.balanceOf(BOB) == INITIAL_BALANCE - secondQuote);
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE - matched);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE + firstQuote + secondQuote);
    }

    /// @dev Proves an incoming bid consumes the lower ask tick before a crossing higher ask,
    /// independent of insertion order and whether the best ask is partially or fully removed.
    function testFuzz_FormalBidConsumesBestAskFirst(bool fullBest) public {
        int32 bestPrice = 59;
        int32 worsePrice = 60;
        uint160 bestQty = 4;
        uint160 worseQty = 5;
        uint160 fillQty = fullBest ? bestQty : bestQty - 1;
        uint160 bestRemaining = bestQty - fillQty;
        uint256 matchedQuote = _quoteValue(bestPrice, bestQty, false) - _quoteValue(bestPrice, bestRemaining, false);

        vm.prank(BOB);
        bytes32 worse = engine.fill(_order(worsePrice, worseQty, 0), false);
        vm.prank(ALICE);
        bytes32 best = engine.fill(_order(bestPrice, bestQty, 0), false);
        vm.prank(CAROL);
        assert(engine.fill(_order(worsePrice, fillQty, 0), true) == bytes32(0));

        vm.prank(ALICE);
        (uint256 bestBase, uint256 bestQuote) = engine.cancel(best);
        vm.prank(BOB);
        (uint256 worseBase, uint256 worseQuote) = engine.cancel(worse);
        assert(bestBase == bestRemaining);
        assert(bestQuote == matchedQuote);
        assert(worseBase == worseQty);
        assert(worseQuote == 0);

        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE + fillQty);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE - matchedQuote);
    }

    /// @dev Proves an incoming ask consumes the higher bid tick before a crossing lower bid.
    function testFuzz_FormalAskConsumesBestBidFirst(bool fullBest) public {
        int32 worsePrice = 59;
        int32 bestPrice = 60;
        uint160 worseQty = 5;
        uint160 bestQty = 4;
        uint160 fillQty = fullBest ? bestQty : bestQty - 1;
        uint160 bestRemaining = bestQty - fillQty;
        uint256 matchedQuote = _quoteValue(bestPrice, bestQty, true) - _quoteValue(bestPrice, bestRemaining, true);

        vm.prank(BOB);
        bytes32 worse = engine.fill(_order(worsePrice, worseQty, 0), true);
        vm.prank(ALICE);
        bytes32 best = engine.fill(_order(bestPrice, bestQty, 0), true);
        vm.prank(CAROL);
        assert(engine.fill(_order(worsePrice, fillQty, 0), false) == bytes32(0));

        vm.prank(ALICE);
        (uint256 bestBase, uint256 bestCollateral) = engine.cancel(best);
        vm.prank(BOB);
        (uint256 worseBase, uint256 worseCollateral) = engine.cancel(worse);
        assert(bestBase == fillQty);
        assert(bestCollateral == _quoteValue(bestPrice, bestRemaining, true));
        assert(worseBase == 0);
        assert(worseCollateral == _quoteValue(worsePrice, worseQty, true));

        _assertEmptyBook();
        assert(base.balanceOf(CAROL) == INITIAL_BALANCE - fillQty);
        assert(quote.balanceOf(CAROL) == INITIAL_BALANCE + matchedQuote);
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
        // Reinterpreting the signed tick preserves its exact two's-complement field bits.
        // forge-lint: disable-next-line(unsafe-typecast)
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }
}

/// @dev Bounded symbolic proof of the epoch-exhaustion policy. Nonce exhaustion is accelerated by
/// the test-only harness; matching, rotation, settlement, cancellation, and book routing all execute
/// the production implementation.
contract DeepstateV1EpochFormalTest is Test {
    uint256 private constant INITIAL_BALANCE = 1_000_000_000;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);

    FormalERC20 private token0;
    FormalERC20 private token1;
    FormalEpochEngine private engine;

    function setUp() public {
        FormalERC20 first = new FormalERC20();
        FormalERC20 second = new FormalERC20();
        (token0, token1) = address(first) < address(second) ? (first, second) : (second, first);
        engine = new FormalEpochEngine();
        _fundAndApprove(ALICE);
        _fundAndApprove(BOB);
    }

    /// @dev Proves underfill, exact-fill, and overfill against an exhausted ask book. Any overfill
    /// remains with the taker; it cannot rest in either the historical or active successor book.
    function testFuzz_FormalHistoricalAskNeverRestsRemainder(bool exactFill, bool overfill) public {
        int32 price = 60;
        uint160 makerQty = 4;
        uint160 takerQty = exactFill ? 4 : (overfill ? 5 : 3);
        uint160 matched = _min(makerQty, takerQty);
        uint160 makerRemaining = makerQty - matched;
        uint256 matchedQuote = _quoteValue(price, makerQty, false) - _quoteValue(price, makerRemaining, false);

        engine.forceNextNonce(address(token0), address(token1), 0, 2);
        vm.prank(ALICE);
        bytes32 maker = engine.fill(_params(0, _order(price, makerQty, 0), false));
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 1);

        vm.prank(BOB);
        bytes32 taker = engine.fill(_params(0, _order(price, takerQty, 0), true));
        assertEq(taker, bytes32(0));
        _assertActiveBookEmpty();

        vm.prank(ALICE);
        (uint256 makerBase, uint256 makerQuote) = engine.cancel(address(token0), address(token1), 0, maker);
        assertEq(makerBase, makerRemaining);
        assertEq(makerQuote, matchedQuote);
        _assertAllBooksEmpty();

        assertEq(token0.balanceOf(ALICE), INITIAL_BALANCE - matched);
        assertEq(token1.balanceOf(ALICE), INITIAL_BALANCE + matchedQuote);
        assertEq(token0.balanceOf(BOB), INITIAL_BALANCE + matched);
        assertEq(token1.balanceOf(BOB), INITIAL_BALANCE - matchedQuote);
    }

    /// @dev Bid-side mirror of `testFuzz_FormalHistoricalAskNeverRestsRemainder`.
    function testFuzz_FormalHistoricalBidNeverRestsRemainder(bool exactFill, bool overfill) public {
        int32 price = 60;
        uint160 makerQty = 4;
        uint160 takerQty = exactFill ? 4 : (overfill ? 5 : 3);
        uint160 matched = _min(makerQty, takerQty);
        uint160 makerRemaining = makerQty - matched;
        uint256 matchedQuote = _quoteValue(price, makerQty, true) - _quoteValue(price, makerRemaining, true);

        engine.forceNextNonce(address(token0), address(token1), 0, 2);
        vm.prank(ALICE);
        bytes32 maker = engine.fill(_params(0, _order(price, makerQty, 0), true));
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 1);

        vm.prank(BOB);
        bytes32 taker = engine.fill(_params(0, _order(price, takerQty, 0), false));
        assertEq(taker, bytes32(0));
        _assertActiveBookEmpty();

        vm.prank(ALICE);
        (uint256 makerBase, uint256 makerQuote) = engine.cancel(address(token0), address(token1), 0, maker);
        assertEq(makerBase, matched);
        assertEq(makerQuote, _quoteValue(price, makerRemaining, true));
        _assertAllBooksEmpty();

        assertEq(token0.balanceOf(ALICE), INITIAL_BALANCE + matched);
        assertEq(token1.balanceOf(ALICE), INITIAL_BALANCE - matchedQuote);
        assertEq(token0.balanceOf(BOB), INITIAL_BALANCE - matched);
        assertEq(token1.balanceOf(BOB), INITIAL_BALANCE + matchedQuote);
    }

    function _fundAndApprove(address trader) private {
        token0.mint(trader, INITIAL_BALANCE);
        token1.mint(trader, INITIAL_BALANCE);
        vm.startPrank(trader);
        token0.approve(address(engine), type(uint256).max);
        token1.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _assertActiveBookEmpty() private view {
        (bytes32 askRoot, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 1);
        assertEq(askRoot, bytes32(0));
        assertEq(bidRoot, bytes32(0));
    }

    function _assertAllBooksEmpty() private view {
        (bytes32 oldAsk, bytes32 oldBid) = engine.roots(address(token0), address(token1), 0);
        assertEq(oldAsk, bytes32(0));
        assertEq(oldBid, bytes32(0));
        _assertActiveBookEmpty();
        assertEq(token0.balanceOf(address(engine)), 0);
        assertEq(token1.balanceOf(address(engine)), 0);
    }

    function _params(uint256 epoch, bytes32 order, bool isBid)
        private
        view
        returns (DeepstateV1.FillParams memory params)
    {
        params = DeepstateV1.FillParams({
            token0: address(token0),
            token1: address(token1),
            epoch: epoch,
            order: order,
            isBid: isBid,
            noRest: false,
            fillOrKill: false
        });
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) private pure returns (uint256) {
        return QuoteMath.quoteValue(tick, quantity, roundUp);
    }

    function _min(uint160 a, uint160 b) private pure returns (uint160) {
        return a < b ? a : b;
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) private pure returns (bytes32) {
        // Reinterpreting the signed tick preserves its exact two's-complement field bits.
        // forge-lint: disable-next-line(unsafe-typecast)
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }
}

/// @dev Differential symbolic proof between production's optimized quote assembly and the test
/// oracle that always reconstructs the complete 512-bit quantity-factor product.
contract QuoteArithmeticFormalTest is DeepstateV1 {
    function testFuzz_FormalQuoteAtMinTick(uint160 quantity, bool roundUp) public pure {
        _assertQuote(type(int32).min, quantity, roundUp);
    }

    function testFuzz_FormalQuoteAboveMinTick(uint160 quantity, bool roundUp) public pure {
        _assertQuote(type(int32).min + 1, quantity, roundUp);
    }

    function testFuzz_FormalQuoteAtLargeNegativeTick(uint160 quantity, bool roundUp) public pure {
        _assertQuote(-1_000_000_000, quantity, roundUp);
    }

    /// @dev This fixed factor is exercised as a full-width differential fuzz target. Nonlinear
    /// SMT multiplication at this constant is intentionally kept outside the deterministic gate.
    function testFuzz_DifferentialQuoteBelowZeroDown(uint160 quantity) public pure {
        _assertQuote(-1, quantity, false);
    }

    function testFuzz_DifferentialQuoteBelowZeroUp(uint160 quantity) public pure {
        _assertQuote(-1, quantity, true);
    }

    function testFuzz_FormalQuoteAtZero(uint160 quantity, bool roundUp) public pure {
        _assertQuote(0, quantity, roundUp);
    }

    function testFuzz_FormalQuoteAboveZero(uint160 quantity, bool roundUp) public pure {
        _assertQuote(1, quantity, roundUp);
    }

    /// @dev Full-width differential fuzz mirror for a dense positive-exponent factor.
    function testFuzz_DifferentialQuoteAtLargePositiveTickDown(uint160 quantity) public pure {
        _assertQuote(1_000_000_000, quantity, false);
    }

    function testFuzz_DifferentialQuoteAtLargePositiveTickUp(uint160 quantity) public pure {
        _assertQuote(1_000_000_000, quantity, true);
    }

    function testFuzz_FormalQuoteBelowMaxTick(uint160 quantity, bool roundUp) public pure {
        _assertQuote(type(int32).max - 1, quantity, roundUp);
    }

    function testFuzz_FormalQuoteAtMaxTickDown(uint160 quantity) public pure {
        _assertQuote(type(int32).max, quantity, false);
    }

    function testFuzz_FormalQuoteAtMaxTickUp(uint160 quantity) public pure {
        _assertQuote(type(int32).max, quantity, true);
    }

    function _assertQuote(int32 tick, uint160 quantity, bool roundUp) private pure {
        assert(_quoteValue(tick, quantity, roundUp) == QuoteMath.quoteValue(tick, quantity, roundUp));
    }
}

/// @dev Solver-level proofs for the arithmetic invariants on which tick settlement and uniform
/// branch correction rely. These tests deliberately avoid concrete prices and order sequences.
contract AccountingAlgebraFormalTest is Test {
    uint256 private constant FRACTION_MODULUS = 1 << 26;
    uint256 private constant HALF_FRACTION = 1 << 25;
    uint256 private constant MAX_RESTING_LEAVES = uint256(type(uint32).max) - 1;

    /// @dev Proves the complete int32 tick domain decomposes into the documented exponent, fraction,
    /// and divisor ranges. TickMath32's independent Decimal oracle separately validates the factor
    /// tables against the real-valued exponential function.
    function testFuzz_FormalTickDecompositionBounds(int32 tick) public pure {
        int256 scaledTick = int256(tick) * 3;
        int256 integerExponent = scaledTick >> 26;
        int256 signedFraction = scaledTick - (integerExponent << 26);

        assert(signedFraction >= 0);
        // The floor decomposition above proves the signed value is nonnegative before conversion.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 fraction = uint256(signedFraction);
        assert(fraction < FRACTION_MODULUS);
        if (fraction > HALF_FRACTION) ++integerExponent;

        assert(integerExponent >= -96);
        assert(integerExponent <= 96);
        // The preceding bounds prove `128 - integerExponent` is in `[32, 224]`.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 shift = uint256(128 - integerExponent);
        assert(shift >= 32);
        assert(shift <= 224);
    }

    /// @dev Proves one binary uniform-ask merge can always recover the sum of the child floors with
    /// a correction in `{0, 1}` for every binary divisor used by production quote arithmetic.
    function testFuzz_FormalAskCorrectionIsExact(uint256 leftProduct, uint256 rightProduct, uint8 shiftOffset)
        public
        pure
    {
        vm.assume(shiftOffset <= 192);
        uint256 shift = uint256(shiftOffset) + 32;
        uint256 mask = (uint256(1) << shift) - 1;
        uint256 leftRemainder = leftProduct & mask;
        uint256 rightRemainder = rightProduct & mask;
        uint256 remainderSum = leftRemainder + rightRemainder;
        uint256 correction = remainderSum >> shift;

        assert(correction <= 1);
        assert(remainderSum == (correction << shift) + (remainderSum & mask));
    }

    /// @dev Bid-side ceiling mirror of `testFuzz_FormalAskCorrectionIsExact`.
    function testFuzz_FormalBidCorrectionIsExact(uint256 leftProduct, uint256 rightProduct, uint8 shiftOffset)
        public
        pure
    {
        vm.assume(shiftOffset <= 192);
        uint256 shift = uint256(shiftOffset) + 32;
        uint256 mask = (uint256(1) << shift) - 1;
        uint256 leftRemainder = leftProduct & mask;
        uint256 rightRemainder = rightProduct & mask;
        uint256 remainderSum = leftRemainder + rightRemainder;
        uint256 childCeil = (leftRemainder == 0 ? 0 : 1) + (rightRemainder == 0 ? 0 : 1);
        uint256 aggregateCeil = remainderSum >> shift;
        if ((remainderSum & mask) != 0) ++aggregateCeil;
        uint256 correction = childCeil - aggregateCeil;

        assert(correction <= 1);
        assert(aggregateCeil + correction == childCeil);
    }

    /// @dev Proves recursive binary correction remains representable in 32 bits for every reachable
    /// leaf count. Each merge adds at most one local rounding unit to its children's corrections.
    function testFuzz_FormalCorrectionCodeCapacity(
        uint32 leftLeaves,
        uint32 rightLeaves,
        uint32 leftCorrection,
        uint32 rightCorrection,
        bool localCorrection
    ) public pure {
        vm.assume(leftLeaves != 0 && rightLeaves != 0);
        uint256 leafCount = uint256(leftLeaves) + uint256(rightLeaves);
        vm.assume(leafCount <= MAX_RESTING_LEAVES);
        vm.assume(leftCorrection < leftLeaves);
        vm.assume(rightCorrection < rightLeaves);

        uint256 correction =
            uint256(leftCorrection) + uint256(rightCorrection) + (localCorrection ? uint256(1) : uint256(0));
        assert(correction < leafCount);
        assert(correction + 1 <= type(uint32).max);
    }

    /// @dev Full-width differential fuzz check for the dynamic two-limb shift. Halmos proves the
    /// same identities symbolically at the minimum, midpoint, and maximum production shifts below.
    function testFuzz_DifferentialQuoteLimbReconstruction(uint256 productHigh, uint256 productLow, uint8 shiftOffset)
        public
        pure
    {
        vm.assume(shiftOffset <= 192);
        _assertQuoteLimbReconstruction(productHigh, productLow, uint256(shiftOffset) + 32);
    }

    function testFuzz_FormalQuoteLimbReconstructionAtMinShift(uint256 productHigh, uint256 productLow) public pure {
        _assertQuoteLimbReconstruction(productHigh, productLow, 32);
    }

    function testFuzz_FormalQuoteLimbReconstructionAtMidShift(uint256 productHigh, uint256 productLow) public pure {
        _assertQuoteLimbReconstruction(productHigh, productLow, 128);
    }

    function testFuzz_FormalQuoteLimbReconstructionAtMaxShift(uint256 productHigh, uint256 productLow) public pure {
        _assertQuoteLimbReconstruction(productHigh, productLow, 224);
    }

    /// @dev Proves the masked low limb is a valid remainder for every production divisor.
    function testFuzz_FormalQuoteRemainderBound(uint256 productLow, uint8 shiftOffset) public pure {
        vm.assume(shiftOffset <= 192);
        uint256 shift = uint256(shiftOffset) + 32;
        uint256 remainder = productLow & ((uint256(1) << shift) - 1);
        assert(remainder < (uint256(1) << shift));
    }

    function _assertQuoteLimbReconstruction(uint256 productHigh, uint256 productLow, uint256 shift) private pure {
        uint256 mask = (uint256(1) << shift) - 1;
        vm.assume(productHigh <= mask);

        uint256 quotient = (productHigh << (256 - shift)) | (productLow >> shift);
        uint256 remainder = productLow & mask;
        assert(quotient >> (256 - shift) == productHigh);
        assert((quotient << shift) | remainder == productLow);
    }
}
