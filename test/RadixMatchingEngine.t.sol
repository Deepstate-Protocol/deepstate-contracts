// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SinglePairEngineHarness as RadixMatchingEngine} from "./SinglePairEngineHarness.sol";
import {QuoteMath} from "./QuoteMath.sol";

contract TestERC20 is ERC20 {
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FalseReturnERC20 is TestERC20 {
    bool public failTransfer;
    bool public failTransferFrom;

    constructor() TestERC20("FalseReturn", "FALSE") {}

    function setFailTransfer(bool failTransfer_) external {
        failTransfer = failTransfer_;
    }

    function setFailTransferFrom(bool failTransferFrom_) external {
        failTransferFrom = failTransferFrom_;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (failTransfer) return false;
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (failTransferFrom) return false;
        return super.transferFrom(from, to, amount);
    }
}

contract ReentrantERC20 is TestERC20 {
    RadixMatchingEngine internal target;
    bytes internal reentryCall;
    bool internal armed;
    bool public reentrySucceeded;
    bytes4 public reentrySelector;

    constructor() TestERC20("Reentrant", "REENTRANT") {}

    function arm(RadixMatchingEngine target_, bytes32 targetOrder_) external {
        target = target_;
        reentryCall = abi.encodeCall(RadixMatchingEngine.cancel, (targetOrder_));
        armed = true;
    }

    function armFill(RadixMatchingEngine target_, bytes32 order, bool isBid) external {
        target = target_;
        reentryCall = abi.encodeCall(RadixMatchingEngine.fill, (order, isBid));
        armed = true;
    }

    function approveAsSelf(address spender, uint256 amount) external {
        _approve(address(this), spender, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (armed) {
            armed = false;
            bytes memory data;
            (reentrySucceeded, data) = address(target).call(reentryCall);
            // forge-lint: disable-next-line(unsafe-typecast)
            if (data.length >= 4) reentrySelector = bytes4(data);
        }
        return super.transfer(to, amount);
    }
}

contract ReentrantTransferFromERC20 is TestERC20 {
    RadixMatchingEngine internal target;
    bytes internal reentryCall;
    bool internal armed;
    bool public reentrySucceeded;
    bytes4 public reentrySelector;

    constructor() TestERC20("ReentrantTransferFrom", "REENTRANT_FROM") {}

    function arm(RadixMatchingEngine target_, bytes32 targetOrder_) external {
        target = target_;
        reentryCall = abi.encodeCall(RadixMatchingEngine.cancel, (targetOrder_));
        armed = true;
    }

    function armFill(RadixMatchingEngine target_, bytes32 order, bool isBid) external {
        target = target_;
        reentryCall = abi.encodeCall(RadixMatchingEngine.fill, (order, isBid));
        armed = true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (armed) {
            armed = false;
            bytes memory data;
            (reentrySucceeded, data) = address(target).call(reentryCall);
            // forge-lint: disable-next-line(unsafe-typecast)
            if (data.length >= 4) reentrySelector = bytes4(data);
        }
        return super.transferFrom(from, to, amount);
    }
}

contract RadixMatchingEngineTest is Test {
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;
    uint256 internal constant BID_RIGHT_SPINE_DIRTY = uint256(1) << 32;
    uint256 internal constant ASK_RIGHT_SPINE_DIRTY = uint256(1) << 33;

    event OrderRested(bytes32 bookId, bytes32 order, address owner, bool isBid);
    event AskMatched(bytes32 bookId, bytes32 restingOrder);
    event AsksMatched(bytes32 bookId, bytes32[] restingOrders);
    event BidMatched(bytes32 bookId, bytes32 restingOrder);
    event BidsMatched(bytes32 bookId, bytes32[] restingOrders);
    event AskSubtreeMatched(bytes32 bookId, bytes32 subtreeRoot, uint160 quantity, uint256 quoteAmount);
    event BidSubtreeMatched(bytes32 bookId, bytes32 subtreeRoot, uint160 quantity, uint256 quoteAmount);
    event OrderCancelled(bytes32 bookId, bytes32 order, address owner, uint256 baseAmount, uint256 quoteAmount);

    TestERC20 internal base;
    TestERC20 internal quote;
    RadixMatchingEngine internal engine;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);
    address internal dave = address(0xD00D);

    function setUp() public {
        base = new TestERC20("Base", "BASE");
        quote = new TestERC20("Quote", "QUOTE");
        engine = new RadixMatchingEngine(address(base), address(quote));

        _fundAndApprove(alice);
        _fundAndApprove(bob);
        _fundAndApprove(carol);
    }

    function test_BidRestsAndCancels() public {
        bytes32 bid = _order(100, 5, 0);
        uint256 expectedQuote = _quoteValue(100, 5, true);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(bid, true);

        assertEq(restingBid, _order(100, 5, MAX_ORDER_NONCE));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(quote.balanceOf(address(engine)), expectedQuote);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, expectedQuote);
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingBid), address(0));
        assertEq(quote.balanceOf(alice), 1_000_000);
    }

    function test_StandardTokenBidRestAndCancelTransfersQuote() public {
        uint256 quoteAmount = _quoteValue(25, 4, true);
        uint256 aliceBaseBefore = base.balanceOf(alice);
        uint256 aliceQuoteBefore = quote.balanceOf(alice);
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(25, 4, 0), true);

        assertEq(base.balanceOf(alice), aliceBaseBefore);
        assertEq(quote.balanceOf(alice), aliceQuoteBefore - quoteAmount);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore + quoteAmount);

        vm.prank(alice);
        (uint256 baseAmount, uint256 returnedQuote) = engine.cancel(restingBid);

        assertEq(baseAmount, 0);
        assertEq(returnedQuote, quoteAmount);
        assertEq(base.balanceOf(alice), aliceBaseBefore);
        assertEq(quote.balanceOf(alice), aliceQuoteBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
    }

    function test_StandardTokenAskRestAndCancelTransfersBase() public {
        uint256 quantity = 4;
        uint256 bobBaseBefore = base.balanceOf(bob);
        uint256 bobQuoteBefore = quote.balanceOf(bob);
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(25, 4, 0), false);

        assertEq(base.balanceOf(bob), bobBaseBefore - quantity);
        assertEq(quote.balanceOf(bob), bobQuoteBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore + quantity);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);

        vm.prank(bob);
        (uint256 returnedBase, uint256 quoteAmount) = engine.cancel(restingAsk);

        assertEq(returnedBase, quantity);
        assertEq(quoteAmount, 0);
        assertEq(base.balanceOf(bob), bobBaseBefore);
        assertEq(quote.balanceOf(bob), bobQuoteBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
    }

    function test_StandardTokenFullMatchPaysTakerAndMakerClaim() public {
        uint256 matchedQuote = _quoteValue(90, 2, false);
        uint256 aliceBaseBefore = base.balanceOf(alice);
        uint256 aliceQuoteBefore = quote.balanceOf(alice);
        uint256 bobBaseBefore = base.balanceOf(bob);
        uint256 bobQuoteBefore = quote.balanceOf(bob);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(base.balanceOf(bob), bobBaseBefore - 2);
        assertEq(base.balanceOf(address(engine)), 2);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(base.balanceOf(alice), aliceBaseBefore + 2);
        assertEq(quote.balanceOf(alice), aliceQuoteBefore - matchedQuote);
        assertEq(base.balanceOf(bob), bobBaseBefore - 2);
        assertEq(quote.balanceOf(bob), bobQuoteBefore);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), matchedQuote);

        vm.prank(bob);
        (uint256 bobBaseAmount, uint256 bobQuoteAmount) = engine.cancel(restingAsk);

        assertEq(bobBaseAmount, 0);
        assertEq(bobQuoteAmount, matchedQuote);
        assertEq(base.balanceOf(bob), bobBaseBefore - 2);
        assertEq(quote.balanceOf(bob), bobQuoteBefore + matchedQuote);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_RestMatchClaimAndCancelEvents() public {
        bytes32 expectedAsk = _order(90, 2, MAX_ORDER_NONCE);

        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderRested(_bookId(), expectedAsk, bob, false);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(restingAsk, expectedAsk);

        bytes32 expectedBid = _order(100, 1, MAX_ORDER_NONCE - 1);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(restingAsk, 2, _quoteValue(90, 2, false), false));
        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderRested(_bookId(), expectedBid, alice, true);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 3, 0), true);

        assertEq(restingBid, expectedBid);

        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderCancelled(_bookId(), restingAsk, bob, 0, _quoteValue(90, 2, false));

        vm.prank(bob);
        (uint256 bobBaseAmount, uint256 bobQuoteAmount) = engine.cancel(restingAsk);

        assertEq(bobBaseAmount, 0);
        assertEq(bobQuoteAmount, _quoteValue(90, 2, false));

        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderCancelled(_bookId(), restingBid, alice, 0, _quoteValue(100, 1, true));

        vm.prank(alice);
        (uint256 aliceBaseAmount, uint256 aliceQuoteAmount) = engine.cancel(restingBid);

        assertEq(aliceBaseAmount, 0);
        assertEq(aliceQuoteAmount, _quoteValue(100, 1, true));
    }

    function test_BidRestMatchClaimAndCancelEvents() public {
        bytes32 expectedBid = _order(100, 2, MAX_ORDER_NONCE);

        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderRested(_bookId(), expectedBid, alice, true);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, expectedBid);

        bytes32 expectedAsk = _order(90, 1, MAX_ORDER_NONCE - 1);

        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(restingBid, 2, _quoteValue(100, 2, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderRested(_bookId(), expectedAsk, bob, false);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 3, 0), false);

        assertEq(restingAsk, expectedAsk);
        assertTrue(engine.isBidOrder(restingBid));

        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderCancelled(_bookId(), restingBid, alice, 2, 0);

        vm.prank(alice);
        (uint256 aliceBaseAmount, uint256 aliceQuoteAmount) = engine.cancel(restingBid);

        assertEq(aliceBaseAmount, 2);
        assertEq(aliceQuoteAmount, 0);
        assertEq(engine.ownerOfOrder(_order(100, 0, MAX_ORDER_NONCE)), address(0));

        vm.expectEmit(false, false, false, true, address(engine));
        emit OrderCancelled(_bookId(), restingAsk, bob, 1, 0);

        vm.prank(bob);
        (uint256 bobBaseAmount, uint256 bobQuoteAmount) = engine.cancel(restingAsk);

        assertEq(bobBaseAmount, 1);
        assertEq(bobQuoteAmount, 0);
    }

    function test_BidMatchEventsFollowAskPricePriority() public {
        vm.prank(alice);
        bytes32 lowAsk = engine.fill(_order(80, 1, 0), false);

        vm.prank(bob);
        bytes32 highAsk = engine.fill(_order(90, 1, 0), false);

        _expectAskMatches(
            _matchEventNode(lowAsk, 1, _quoteValue(80, 1, false), false),
            _matchEventNode(highAsk, 1, _quoteValue(90, 1, false), false)
        );

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_AskMatchEventsFollowBidPricePriority() public {
        vm.prank(alice);
        bytes32 highBid = engine.fill(_order(100, 1, 0), true);

        vm.prank(bob);
        bytes32 lowBid = engine.fill(_order(90, 1, 0), true);

        _expectBidMatches(
            _matchEventNode(highBid, 1, _quoteValue(100, 1, true), true),
            _matchEventNode(lowBid, 1, _quoteValue(90, 1, true), true)
        );

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(80, 2, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_StorageLayoutMatchesStrictDesign() public {
        assertEq(vm.load(address(engine), _bidRootSlot()), bytes32(0), "bidRoot slot");
        assertEq(vm.load(address(engine), _askRootSlot()), bytes32(0), "askRoot slot");
        assertEq(vm.load(address(engine), _nextNonceSlot()), bytes32(0), "nextNonce slot before init");

        {
            vm.prank(alice);
            bytes32 firstBid = engine.fill(_order(100, 1, 0), true);
            vm.prank(bob);
            bytes32 secondBid = engine.fill(_order(99, 1, 0), true);
            bytes32 bidBranch = _branchFor(firstBid, secondBid, true);
            (bytes32 leftNode, bytes32 rightNode) = _expectedBranchChildren(firstBid, secondBid, true);

            assertEq(vm.load(address(engine), _bidRootSlot()), bidBranch, "bidRoot slot after insert");
            assertEq(
                vm.load(address(engine), _ownerOfOrderSlot(firstBid)), _orderStateSlotValue(alice, true), "owner slot"
            );
            assertTrue(engine.isBidOrder(firstBid), "bid side");
            _assertTreeBranchStorage(bidBranch, leftNode, rightNode, "bid");
        }

        {
            vm.prank(alice);
            bytes32 firstAsk = engine.fill(_order(200, 1, 0), false);
            vm.prank(bob);
            bytes32 secondAsk = engine.fill(_order(201, 1, 0), false);
            bytes32 askBranch = _branchFor(firstAsk, secondAsk, false);
            (bytes32 leftNode, bytes32 rightNode) = _expectedBranchChildren(firstAsk, secondAsk, false);

            assertEq(vm.load(address(engine), _askRootSlot()), askBranch, "askRoot slot after insert");
            assertEq(
                vm.load(address(engine), _ownerOfOrderSlot(firstAsk)),
                _orderStateSlotValue(alice, false),
                "ask owner slot"
            );
            assertFalse(engine.isBidOrder(firstAsk), "ask side");
            _assertTreeBranchStorage(askBranch, leftNode, rightNode, "ask");
        }
    }

    function test_InvalidOrdersRevert() public {
        vm.startPrank(alice);

        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(bytes32(uint256(_order(0, 1, 0)) | (uint256(1) << 32)), true);

        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(_order(1, 0, 0), true);

        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(_order(1, 1, 1), true);

        vm.stopPrank();
    }

    function test_ReentrancyGuardClearsAfterFillRevert() public {
        vm.startPrank(alice);

        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(bytes32(uint256(_order(0, 1, 0)) | (uint256(1) << 32)), true);

        bytes32 restingBid = engine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        assertEq(restingBid, _order(10, 1, MAX_ORDER_NONCE));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
    }

    function test_ReentrancyGuardClearsAfterCancelRevert() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(10, 1, 0), true);

        vm.startPrank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.cancel(_order(10, 0, _nonce(restingBid)));

        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);
        vm.stopPrank();

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, _quoteValue(10, 1, true));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingBid), address(0));
    }

    function testFuzz_InvalidFillDoesNotMutate(bytes32 order, bool isBid) public {
        vm.assume(_quantity(order) == 0 || uint64(uint256(order)) != 0);

        bytes32 bidRootBefore = engine.bidRoot();
        bytes32 askRootBefore = engine.askRoot();
        uint32 nextNonceBefore = engine.nextNonce();
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));
        uint256 aliceBaseBefore = base.balanceOf(alice);
        uint256 aliceQuoteBefore = quote.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(order, isBid);

        assertEq(engine.bidRoot(), bidRootBefore);
        assertEq(engine.askRoot(), askRootBefore);
        assertEq(engine.nextNonce(), nextNonceBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
        assertEq(base.balanceOf(alice), aliceBaseBefore);
        assertEq(quote.balanceOf(alice), aliceQuoteBefore);
    }

    function testFuzz_CancelZeroQuantityDoesNotMutate(int32 price, uint32 nonce, address caller) public {
        vm.assume(caller != address(0));
        bytes32 order = _order(price, 0, nonce);

        bytes32 bidRootBefore = engine.bidRoot();
        bytes32 askRootBefore = engine.askRoot();
        uint32 nextNonceBefore = engine.nextNonce();
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(caller);
        vm.expectRevert(bytes4(keccak256("InvalidBook()")));
        engine.cancel(order);

        assertEq(engine.bidRoot(), bidRootBefore);
        assertEq(engine.askRoot(), askRootBefore);
        assertEq(engine.nextNonce(), nextNonceBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
        assertEq(engine.ownerOfOrder(order), address(0));
    }

    function test_CancelOwnedZeroQuantityOrderRevertsInvalidOrder() public {
        bytes32 order = _order(777, 0, 123);
        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.store(address(engine), _ownerOfOrderSlot(order), _orderStateSlotValue(alice, true));

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.cancel(order);

        assertEq(vm.load(address(engine), _ownerOfOrderSlot(order)), _orderStateSlotValue(alice, true));
    }

    function testFuzz_CancelUnknownOrderDoesNotMutate(int32 price, uint160 quantity, uint32 nonce, address caller)
        public
    {
        vm.assume(quantity != 0);
        vm.assume(caller != address(0));

        bytes32 order = _order(price, quantity, nonce);
        bytes32 bidRootBefore = engine.bidRoot();
        bytes32 askRootBefore = engine.askRoot();
        uint32 nextNonceBefore = engine.nextNonce();
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(caller);
        vm.expectRevert(bytes4(keccak256("InvalidBook()")));
        engine.cancel(order);

        assertEq(engine.bidRoot(), bidRootBefore);
        assertEq(engine.askRoot(), askRootBefore);
        assertEq(engine.nextNonce(), nextNonceBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
        assertEq(engine.ownerOfOrder(order), address(0));
    }

    function test_CancelOrphanedOrderStateWithoutCollateralRevertsAndPreservesState() public {
        bytes32 order = _order(777, 3, 123);
        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.store(address(engine), _ownerOfOrderSlot(order), _orderStateSlotValue(alice, true));

        uint256 aliceBaseBefore = base.balanceOf(alice);
        uint256 aliceQuoteBefore = quote.balanceOf(alice);
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(alice);
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        engine.cancel(order);

        assertEq(vm.load(address(engine), _ownerOfOrderSlot(order)), _orderStateSlotValue(alice, true));
        assertEq(base.balanceOf(alice), aliceBaseBefore);
        assertEq(quote.balanceOf(alice), aliceQuoteBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
    }

    function test_CancelCorruptedRemainingAboveOriginalRevertsInvalidOrder() public {
        vm.prank(alice);
        bytes32 order = engine.fill(_order(777, 1, 0), true);

        bytes32 corruptedLeaf = _order(777, 2, _nonce(order));
        vm.store(address(engine), _bidRootSlot(), corruptedLeaf);

        uint256 aliceBaseBefore = base.balanceOf(alice);
        uint256 aliceQuoteBefore = quote.balanceOf(alice);
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.cancel(order);

        assertEq(engine.bidRoot(), corruptedLeaf);
        assertEq(engine.ownerOfOrder(order), alice);
        assertEq(base.balanceOf(alice), aliceBaseBefore);
        assertEq(quote.balanceOf(alice), aliceQuoteBefore);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
    }

    function test_OnlyOwnerCanCancel() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(restingBid);

        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.bidRoot(), restingBid);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(100, 2, true));
    }

    function test_FilledOrderClaimCanOnlyHappenOnce() public {
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        vm.prank(alice);
        engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingAsk);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, _quoteValue(90, 2, false));
        assertEq(engine.ownerOfOrder(restingAsk), address(0));

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(restingAsk);
    }

    function test_OrdersStartAtMaxNonceAndDecrement() public {
        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(100, 1, 0), true);

        assertEq(_nonce(firstBid), MAX_ORDER_NONCE);
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE - 1);

        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(99, 1, 0), true);

        bytes32 root = engine.bidRoot();
        assertEq(_nonce(secondBid), MAX_ORDER_NONCE - 1);
        assertEq(engine.ownerOfOrder(root), address(0));
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(root);
        assertTrue(leftNode != bytes32(0));
        assertTrue(rightNode != bytes32(0));
    }

    function test_DuplicateBidNonceCorruptionRevertsWithoutOverwritingOwner() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(10, 1, 0), true);

        assertEq(restingBid, _order(10, 1, MAX_ORDER_NONCE));

        bytes32 nextNonceSlot = _nextNonceSlot();
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(MAX_ORDER_NONCE)));

        uint256 engineQuoteBefore = quote.balanceOf(address(engine));
        uint256 bobQuoteBefore = quote.balanceOf(bob);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("DuplicateOrder()")));
        engine.fill(_order(10, 1, 0), true);

        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);
        assertEq(quote.balanceOf(bob), bobQuoteBefore);
    }

    function test_DuplicateAskNonceCorruptionRevertsWithoutOverwritingOwner() public {
        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_order(10, 1, 0), false);

        assertEq(restingAsk, _order(10, 1, MAX_ORDER_NONCE));

        bytes32 nextNonceSlot = _nextNonceSlot();
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(MAX_ORDER_NONCE)));

        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 bobBaseBefore = base.balanceOf(bob);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("DuplicateOrder()")));
        engine.fill(_order(10, 1, 0), false);

        assertEq(engine.askRoot(), restingAsk);
        assertEq(engine.ownerOfOrder(restingAsk), alice);
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE);
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(base.balanceOf(bob), bobBaseBefore);
    }

    function test_ExhaustedBookRestsNewSameSideOrderInActiveEpoch() public {
        bytes32 nextNonceSlot = _nextNonceSlot();
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(2)));

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(10, 1, 0), true);

        assertEq(restingBid, _order(10, 1, 2));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.nextNonce(), 1);
        assertEq(engine.poolEpoch(engine.poolId(address(base), address(quote))), 1);

        vm.prank(bob);
        bytes32 nextBid = engine.fill(_order(11, 1, 0), true);

        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.nextNonce(), 1);

        (, bytes32 epochOneBidRoot) = engine.roots(address(base), address(quote), 1);
        assertEq(nextBid, _order(11, 1, MAX_ORDER_NONCE));
        assertEq(epochOneBidRoot, nextBid);
        assertEq(engine.ownerOfOrder(nextBid), bob);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(10, 1, true) + _quoteValue(11, 1, true));
    }

    function test_BidRemainderFromExhaustedBookRestsInActiveEpoch() public {
        bytes32 nextNonceSlot = _nextNonceSlot();
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(2)));

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 1, 0), false);

        assertEq(restingAsk, _order(90, 1, 2));
        assertEq(engine.askRoot(), restingAsk);
        assertEq(engine.nextNonce(), 1);
        assertEq(engine.poolEpoch(engine.poolId(address(base), address(quote))), 1);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, _order(100, 1, MAX_ORDER_NONCE));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        assertFalse(engine.isBidOrder(restingAsk));
        assertEq(engine.nextNonce(), 1);

        (, bytes32 epochOneBidRoot) = engine.roots(address(base), address(quote), 1);
        assertEq(epochOneBidRoot, restingBid);
        assertEq(base.balanceOf(alice), 1_000_001);
        assertEq(quote.balanceOf(alice), 1_000_000 - _quoteValue(90, 1, false) - _quoteValue(100, 1, true));
        assertEq(base.balanceOf(bob), 1_000_000 - 1);
        assertEq(quote.balanceOf(bob), 1_000_000);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(90, 1, false) + _quoteValue(100, 1, true));
    }

    function test_AskRemainderFromExhaustedBookRestsInActiveEpoch() public {
        bytes32 nextNonceSlot = _nextNonceSlot();
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(2)));

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 1, 0), true);

        assertEq(restingBid, _order(100, 1, 2));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.nextNonce(), 1);
        assertEq(engine.poolEpoch(engine.poolId(address(base), address(quote))), 1);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(restingAsk, _order(90, 1, MAX_ORDER_NONCE));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.nextNonce(), 1);

        (bytes32 epochOneAskRoot,) = engine.roots(address(base), address(quote), 1);
        assertEq(epochOneAskRoot, restingAsk);
        assertEq(base.balanceOf(alice), 1_000_000);
        assertEq(quote.balanceOf(alice), 1_000_000 - _quoteValue(100, 1, true));
        assertEq(base.balanceOf(bob), 1_000_000 - 2);
        assertEq(quote.balanceOf(bob), 1_000_000 + _quoteValue(100, 1, true));
        assertEq(base.balanceOf(address(engine)), 2);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_BidFullMatchSucceedsWhenNonceExhausted() public {
        bytes32 nextNonceSlot = _nextNonceSlot();
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(2)));

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(restingAsk, _order(90, 2, 2));
        assertEq(engine.askRoot(), restingAsk);
        assertEq(engine.nextNonce(), 1);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.nextNonce(), 1);
        assertEq(base.balanceOf(alice), 1_000_002);
        assertEq(quote.balanceOf(alice), 1_000_000 - _quoteValue(90, 2, false));
        assertEq(engine.ownerOfOrder(restingAsk), bob);

        vm.prank(bob);
        (uint256 bobBase, uint256 bobQuote) = engine.cancel(restingAsk);

        assertEq(bobBase, 0);
        assertEq(bobQuote, _quoteValue(90, 2, false));
        assertEq(engine.ownerOfOrder(restingAsk), address(0));
        assertEq(engine.ownerOfOrder(_order(90, 0, 2)), address(0));
    }

    function test_AskFullMatchSucceedsWhenNonceExhausted() public {
        bytes32 nextNonceSlot = _nextNonceSlot();
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(2)));

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, _order(100, 2, 2));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.nextNonce(), 1);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.nextNonce(), 1);
        assertEq(base.balanceOf(bob), 1_000_000 - 2);
        assertEq(quote.balanceOf(bob), 1_000_000 + _quoteValue(100, 2, true));
        assertEq(engine.ownerOfOrder(restingBid), alice);

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(restingBid);

        assertEq(aliceBase, 2);
        assertEq(aliceQuote, 0);
        assertEq(engine.ownerOfOrder(restingBid), address(0));
        assertEq(engine.ownerOfOrder(_order(100, 0, 2)), address(0));
    }

    function test_MaxPriceAndQuantityBidCancels() public {
        int32 price = 0;
        uint160 quantity = type(uint160).max;
        uint256 quoteAmount = _quoteValue(price, quantity, true);

        quote.mint(alice, type(uint216).max);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(price, quantity, 0), true);

        assertEq(restingBid, _order(price, quantity, MAX_ORDER_NONCE));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(quote.balanceOf(address(engine)), quoteAmount);

        vm.prank(alice);
        (uint256 baseAmount, uint256 returnedQuote) = engine.cancel(restingBid);

        assertEq(baseAmount, 0);
        assertEq(returnedQuote, quoteAmount);
        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_MaxBidPartialMatchAndRestDoesNotOverflowCollateral() public {
        int32 price = 0;
        uint160 quantity = type(uint160).max;
        uint160 restingQuantity = quantity - 1;
        uint256 totalQuote = _quoteValue(price, quantity, true);

        quote.mint(alice, type(uint216).max);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(price, 1, 0), false);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(price, quantity, 0), true);

        assertEq(restingBid, _order(price, restingQuantity, MAX_ORDER_NONCE - 1));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(base.balanceOf(alice), 1_000_001);
        assertEq(quote.balanceOf(address(engine)), totalQuote);

        vm.prank(bob);
        (uint256 bobBaseAmount, uint256 bobQuoteAmount) = engine.cancel(restingAsk);

        assertEq(bobBaseAmount, 0);
        assertEq(bobQuoteAmount, _quoteValue(price, 1, false));
        assertEq(quote.balanceOf(address(engine)), _quoteValue(price, restingQuantity, true));

        vm.prank(alice);
        (uint256 aliceBaseAmount, uint256 aliceQuoteAmount) = engine.cancel(restingBid);

        assertEq(aliceBaseAmount, 0);
        assertEq(aliceQuoteAmount, _quoteValue(price, restingQuantity, true));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_MaxPriceAndQuantityAskCancels() public {
        int32 price = 0;
        uint160 quantity = type(uint160).max;

        base.mint(alice, quantity);

        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_order(price, quantity, 0), false);

        assertEq(restingAsk, _order(price, quantity, MAX_ORDER_NONCE));
        assertEq(engine.askRoot(), restingAsk);
        assertEq(base.balanceOf(address(engine)), quantity);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingAsk);

        assertEq(baseAmount, quantity);
        assertEq(quoteAmount, 0);
        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_MaxAskConsumesBidBranchAtQuantityLimit() public {
        int32 price = 0;
        uint160 quantity = type(uint160).max;
        uint160 secondBidQuantity = quantity - 1;
        uint256 totalQuote = _quoteValue(price, 1, true) + _quoteValue(price, secondBidQuantity, true);

        quote.mint(alice, type(uint216).max);
        quote.mint(bob, type(uint216).max);
        base.mint(carol, quantity);

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(price, 1, 0), true);

        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(price, secondBidQuantity, 0), true);

        assertEq(engine.bidRoot(), _branchFor(firstBid, secondBid, true));
        assertEq(quote.balanceOf(address(engine)), totalQuote);

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(price, quantity, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(quote.balanceOf(carol), 1_000_000 + totalQuote);
        assertEq(base.balanceOf(address(engine)), quantity);

        vm.prank(alice);
        (uint256 aliceBaseAmount, uint256 aliceQuoteAmount) = engine.cancel(firstBid);

        assertEq(aliceBaseAmount, 1);
        assertEq(aliceQuoteAmount, 0);

        vm.prank(bob);
        (uint256 bobBaseAmount, uint256 bobQuoteAmount) = engine.cancel(secondBid);

        assertEq(bobBaseAmount, secondBidQuantity);
        assertEq(bobQuoteAmount, 0);
        assertEq(base.balanceOf(address(engine)), 0);
    }

    function test_MaxBidConsumesAskBranchAtQuantityLimit() public {
        int32 price = 0;
        uint160 quantity = type(uint160).max;
        uint160 secondAskQuantity = quantity - 1;
        uint256 totalQuote = _quoteValue(price, 1, false) + _quoteValue(price, secondAskQuantity, false);

        base.mint(bob, quantity);
        quote.mint(carol, type(uint216).max);

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(price, 1, 0), false);

        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(price, secondAskQuantity, 0), false);

        assertEq(engine.askRoot(), _branchFor(firstAsk, secondAsk, false));
        assertEq(base.balanceOf(address(engine)), quantity);

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(price, quantity, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(base.balanceOf(carol), 1_000_000 + uint256(quantity));
        assertEq(quote.balanceOf(address(engine)), totalQuote);

        vm.prank(alice);
        (uint256 aliceBaseAmount, uint256 aliceQuoteAmount) = engine.cancel(firstAsk);

        assertEq(aliceBaseAmount, 0);
        assertEq(aliceQuoteAmount, _quoteValue(price, 1, false));

        vm.prank(bob);
        (uint256 bobBaseAmount, uint256 bobQuoteAmount) = engine.cancel(secondAsk);

        assertEq(bobBaseAmount, 0);
        assertEq(bobQuoteAmount, _quoteValue(price, secondAskQuantity, false));
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_BranchQuantityOverflowRevertsWithoutMutatingBook() public {
        quote.mint(alice, type(uint216).max);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(1, type(uint160).max, 0), true);

        bytes32 overflowingBid = _order(2, 1, MAX_ORDER_NONCE - 1);

        vm.prank(bob);
        vm.expectRevert(stdError.arithmeticError);
        engine.fill(_order(2, 1, 0), true);

        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.ownerOfOrder(overflowingBid), address(0));
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE - 1);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(1, type(uint160).max, true));
    }

    function test_AskBranchQuantityOverflowRevertsWithoutMutatingBook() public {
        base.mint(alice, type(uint160).max);

        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_order(1, type(uint160).max, 0), false);

        bytes32 overflowingAsk = _order(2, 1, MAX_ORDER_NONCE - 1);

        vm.prank(bob);
        vm.expectRevert(stdError.arithmeticError);
        engine.fill(_order(2, 1, 0), false);

        assertEq(engine.askRoot(), restingAsk);
        assertEq(engine.ownerOfOrder(restingAsk), alice);
        assertEq(engine.ownerOfOrder(overflowingAsk), address(0));
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE - 1);
        assertEq(base.balanceOf(address(engine)), type(uint160).max);
    }

    function test_RestingOrderSideUsesPackedOrderState() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        bytes32 bidSideKey = _order(100, 0, _nonce(restingBid));
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(bob);
        engine.fill(_order(100, 5, 0), false);

        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(101, 7, 0), false);

        bytes32 askSideKey = _order(101, 0, _nonce(restingAsk));
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        assertFalse(engine.isBidOrder(restingAsk));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));

        vm.prank(alice);
        engine.fill(_order(101, 7, 0), true);

        assertFalse(engine.isBidOrder(restingAsk));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));

        vm.prank(alice);
        engine.cancel(restingBid);
        vm.prank(bob);
        engine.cancel(restingAsk);

        assertEq(engine.ownerOfOrder(bidSideKey), address(0));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));
    }

    function test_CancelRejectsZeroQuantitySideKey() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 1, 0), true);

        vm.prank(bob);
        engine.fill(_order(100, 1, 0), false);

        bytes32 bidSideKey = _order(100, 0, _nonce(restingBid));
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(address(1));
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.cancel(bidSideKey);

        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(engine.ownerOfOrder(restingBid), address(0));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));
    }

    function test_AddressOneAndTwoCannotClaimForOriginalOwner() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 1, 0), true);

        vm.prank(bob);
        engine.fill(_order(90, 1, 0), false);

        bytes32 bidSideKey = _order(100, 0, _nonce(restingBid));
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(address(1));
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(restingBid);

        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(alice);
        engine.cancel(restingBid);

        assertEq(engine.ownerOfOrder(restingBid), address(0));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 1, 0), false);

        vm.prank(alice);
        engine.fill(_order(100, 1, 0), true);

        bytes32 askSideKey = _order(90, 0, _nonce(restingAsk));
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        assertFalse(engine.isBidOrder(restingAsk));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));

        vm.prank(address(2));
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(restingAsk);

        assertEq(engine.ownerOfOrder(restingAsk), bob);
        assertFalse(engine.isBidOrder(restingAsk));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));

        vm.prank(bob);
        engine.cancel(restingAsk);

        assertEq(engine.ownerOfOrder(restingAsk), address(0));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));
    }

    function test_AddressOneAndTwoOwnersCanCancelUnfilledOrders() public {
        address bidOwner = address(1);
        address askOwner = address(2);
        _fundAndApprove(bidOwner);
        _fundAndApprove(askOwner);

        vm.prank(bidOwner);
        bytes32 restingBid = engine.fill(_order(100, 3, 0), true);

        bytes32 bidSideKey = _order(100, 0, _nonce(restingBid));
        assertEq(engine.ownerOfOrder(restingBid), bidOwner);
        assertTrue(engine.isBidOrder(restingBid));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(askOwner);
        bytes32 restingAsk = engine.fill(_order(101, 4, 0), false);

        bytes32 askSideKey = _order(101, 0, _nonce(restingAsk));
        assertEq(engine.ownerOfOrder(restingAsk), askOwner);
        assertFalse(engine.isBidOrder(restingAsk));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));

        vm.prank(bidOwner);
        (uint256 bidBaseAmount, uint256 bidQuoteAmount) = engine.cancel(restingBid);

        assertEq(bidBaseAmount, 0);
        assertEq(bidQuoteAmount, _quoteValue(100, 3, true));
        assertEq(engine.ownerOfOrder(restingBid), address(0));
        assertEq(engine.ownerOfOrder(bidSideKey), address(0));

        vm.prank(askOwner);
        (uint256 askBaseAmount, uint256 askQuoteAmount) = engine.cancel(restingAsk);

        assertEq(askBaseAmount, 4);
        assertEq(askQuoteAmount, 0);
        assertEq(engine.ownerOfOrder(restingAsk), address(0));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));
    }

    function test_AddressOneAndTwoOwnersCanClaimFilledOrders() public {
        address bidOwner = address(1);
        address askOwner = address(2);
        _fundAndApprove(bidOwner);
        _fundAndApprove(askOwner);

        vm.prank(bidOwner);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        bytes32 crossingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(crossingAsk, bytes32(0));

        vm.prank(bidOwner);
        (uint256 bidBaseAmount, uint256 bidQuoteAmount) = engine.cancel(restingBid);

        assertEq(bidBaseAmount, 2);
        assertEq(bidQuoteAmount, 0);
        assertEq(engine.ownerOfOrder(restingBid), address(0));
        assertEq(engine.ownerOfOrder(_order(100, 0, _nonce(restingBid))), address(0));

        vm.prank(askOwner);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        vm.prank(alice);
        bytes32 crossingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(crossingBid, bytes32(0));

        vm.prank(askOwner);
        (uint256 askBaseAmount, uint256 askQuoteAmount) = engine.cancel(restingAsk);

        assertEq(askBaseAmount, 0);
        assertEq(askQuoteAmount, _quoteValue(90, 2, false));
        assertEq(engine.ownerOfOrder(restingAsk), address(0));
        assertEq(engine.ownerOfOrder(_order(90, 0, _nonce(restingAsk))), address(0));
    }

    function test_BidAndAskBranchesCoexistInSingleMapping() public {
        vm.prank(alice);
        engine.fill(_order(100, 1, 0), true);
        vm.prank(bob);
        engine.fill(_order(99, 1, 0), true);

        int32 maxPrice = type(int32).max;
        vm.prank(alice);
        engine.fill(_order(maxPrice - 100, 1, 0), false);
        vm.prank(bob);
        engine.fill(_order(maxPrice - 99, 1, 0), false);

        bytes32 bidRoot = engine.bidRoot();
        bytes32 askRoot = engine.askRoot();

        assertTrue(bidRoot != bytes32(0));
        assertTrue(askRoot != bytes32(0));
        assertTrue(bidRoot != askRoot);
        (bytes32 bidLeft, bytes32 bidRight) = engine.tree(bidRoot);
        (bytes32 askLeft, bytes32 askRight) = engine.tree(askRoot);
        assertTrue(bidLeft != bytes32(0) && bidRight != bytes32(0));
        assertTrue(askLeft != bytes32(0) && askRight != bytes32(0));
    }

    function test_MultipleSamePriceBranchesDoNotAlias() public {
        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(100, 1, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(100, 1, 0), false);
        vm.prank(carol);
        bytes32 thirdAsk = engine.fill(_order(100, 1, 0), false);
        vm.prank(address(0xD00D));
        base.mint(address(0xD00D), 1_000_000);
        vm.prank(address(0xD00D));
        base.approve(address(engine), type(uint256).max);
        vm.prank(address(0xD00D));
        bytes32 fourthAsk = engine.fill(_order(100, 1, 0), false);

        assertEq(engine.ownerOfOrder(firstAsk), alice);
        assertEq(engine.ownerOfOrder(secondAsk), bob);
        assertEq(engine.ownerOfOrder(thirdAsk), carol);
        assertEq(engine.ownerOfOrder(fourthAsk), address(0xD00D));
    }

    function test_FullPrefixBranchAddressesHandleAliasSequence() public {
        int32[40] memory prices = [
            int32(549),
            int32(308),
            int32(394),
            int32(742),
            int32(69),
            int32(591),
            int32(261),
            int32(806),
            int32(179),
            int32(494),
            int32(247),
            int32(605),
            int32(906),
            int32(801),
            int32(69),
            int32(626),
            int32(781),
            int32(992),
            int32(666),
            int32(731),
            int32(256),
            int32(716),
            int32(853),
            int32(822),
            int32(339),
            int32(658),
            int32(10),
            int32(746),
            int32(244),
            int32(938),
            int32(216),
            int32(77),
            int32(417),
            int32(851),
            int32(990),
            int32(166),
            int32(573),
            int32(717),
            int32(634),
            int32(179)
        ];

        bytes32[] memory orders = new bytes32[](prices.length);
        uint256 quoteSpent;

        for (uint256 i; i < prices.length; ++i) {
            vm.prank(alice);
            orders[i] = engine.fill(_order(prices[i], 1, 0), true);

            assertEq(engine.ownerOfOrder(orders[i]), alice);
            quoteSpent += _quoteValue(prices[i], 1, true);
        }

        assertEq(quote.balanceOf(address(engine)), quoteSpent);

        for (uint256 i; i < orders.length; ++i) {
            vm.prank(alice);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[i]);

            assertEq(baseAmount, 0);
            assertEq(quoteAmount, _quoteValue(prices[i], 1, true));
        }

        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(quote.balanceOf(alice), 1_000_000);
    }

    function test_PartialFillOriginalOrderCanAliasBranchAndStillCancel() public {
        address d00d = address(0xD00D);
        _fundAndApprove(d00d);

        vm.prank(bob);
        engine.fill(_order(1, 57, 0), true);

        vm.prank(d00d);
        engine.fill(_order(99, 56, 0), false);

        vm.prank(d00d);
        engine.fill(_order(1, 75, 0), false);

        vm.prank(d00d);
        engine.fill(_order(1060, 42, 0), true);

        vm.prank(bob);
        bytes32 bobAsk = engine.fill(_order(1, 83, 0), false);

        vm.prank(carol);
        engine.fill(_order(87, 19, 0), true);

        vm.prank(d00d);
        engine.fill(_order(13769, 49, 0), true);

        vm.prank(bob);
        engine.fill(_order(1, 68, 0), false);

        vm.prank(bob);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(bobAsk);

        assertEq(baseAmount, 15);
        assertEq(quoteAmount, _quoteValue(1, 83, false) - _quoteValue(1, 15, false));
    }

    function test_PartialAskOriginalCanAliasRootBranchAndStillCancel() public {
        int32 price = 10;

        vm.prank(alice);
        bytes32 originalAsk = engine.fill(_order(price, 3, 0), false);

        vm.prank(bob);
        bytes32 fullyMatchedBid = engine.fill(_order(price, 1, 0), true);

        assertEq(fullyMatchedBid, bytes32(0));

        bytes32 reducedAsk = _order(price, 2, _nonce(originalAsk));
        assertEq(engine.askRoot(), reducedAsk);

        vm.prank(carol);
        bytes32 laterAsk = engine.fill(_order(price, 1, 0), false);

        bytes32 rootAlias = _branchFor(reducedAsk, laterAsk, false);
        (bytes32 expectedLeft, bytes32 expectedRight) = _expectedBranchChildren(reducedAsk, laterAsk, false);

        assertTrue(rootAlias != originalAsk);
        assertEq(engine.askRoot(), rootAlias);
        _assertTreeBranchStorage(rootAlias, expectedLeft, expectedRight, "ask root");
        assertEq(engine.ownerOfOrder(originalAsk), alice);
        assertEq(engine.ownerOfOrder(reducedAsk), address(0));
        assertEq(engine.ownerOfOrder(laterAsk), carol);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(originalAsk);

        assertEq(baseAmount, 2);
        assertEq(quoteAmount, _quoteValue(price, 3, false) - _quoteValue(price, 2, false));
        assertEq(engine.askRoot(), laterAsk);
        assertEq(engine.ownerOfOrder(originalAsk), address(0));
        assertEq(engine.ownerOfOrder(_order(price, 0, _nonce(originalAsk))), address(0));
        assertEq(engine.ownerOfOrder(laterAsk), carol);

        vm.prank(carol);
        (baseAmount, quoteAmount) = engine.cancel(laterAsk);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_PartialBidOriginalCanAliasRootBranchAndStillCancel() public {
        int32 price = 10;

        vm.prank(alice);
        bytes32 originalBid = engine.fill(_order(price, 3, 0), true);

        vm.prank(bob);
        bytes32 fullyMatchedAsk = engine.fill(_order(price, 1, 0), false);

        assertEq(fullyMatchedAsk, bytes32(0));

        bytes32 reducedBid = _order(price, 2, _nonce(originalBid));
        assertEq(engine.bidRoot(), reducedBid);

        vm.prank(carol);
        bytes32 laterBid = engine.fill(_order(price, 1, 0), true);

        bytes32 rootAlias = _branchFor(reducedBid, laterBid, true);
        (bytes32 expectedLeft, bytes32 expectedRight) = _expectedBranchChildren(reducedBid, laterBid, true);

        assertTrue(rootAlias != originalBid);
        assertEq(engine.bidRoot(), rootAlias);
        _assertTreeBranchStorage(rootAlias, expectedLeft, expectedRight, "bid root");
        assertEq(engine.ownerOfOrder(originalBid), alice);
        assertEq(engine.ownerOfOrder(reducedBid), address(0));
        assertEq(engine.ownerOfOrder(laterBid), carol);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(originalBid);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, _quoteValue(price, 2, true));
        assertEq(engine.bidRoot(), laterBid);
        assertEq(engine.ownerOfOrder(originalBid), address(0));
        assertEq(engine.ownerOfOrder(_order(price, 0, _nonce(originalBid))), address(0));
        assertEq(engine.ownerOfOrder(laterBid), carol);

        vm.prank(carol);
        (baseAmount, quoteAmount) = engine.cancel(laterBid);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, _quoteValue(price, 1, true));
        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_PartialAskCorrectionSeparatesBranchAndStillClaimsAfterFullFill() public {
        address d00d = address(0xD00D);
        _fundAndApprove(d00d);

        vm.prank(bob);
        engine.fill(_order(1, 57, 0), true);

        vm.prank(d00d);
        engine.fill(_order(99, 56, 0), false);

        vm.prank(d00d);
        engine.fill(_order(1, 75, 0), false);

        vm.prank(d00d);
        engine.fill(_order(1060, 42, 0), true);

        vm.prank(bob);
        bytes32 bobAsk = engine.fill(_order(1, 83, 0), false);

        vm.prank(carol);
        engine.fill(_order(87, 19, 0), true);

        vm.prank(d00d);
        engine.fill(_order(13769, 49, 0), true);

        vm.prank(bob);
        engine.fill(_order(1, 68, 0), false);

        (bytes32 aliasLeft, bytes32 aliasRight) = engine.tree(bobAsk);
        assertEq(aliasLeft, bytes32(0));
        assertEq(aliasRight, bytes32(0));

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(1, 15, 0), true);

        assertEq(restingBid, bytes32(0));

        vm.prank(bob);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(bobAsk);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, _quoteValue(1, 83, false));
        assertEq(engine.ownerOfOrder(bobAsk), address(0));
    }

    function test_PartialBidCorrectionSeparatesBranchAndStillClaimsAfterFullFill() public {
        address d00d = address(0xD00D);
        _fundAndApprove(d00d);

        int32 mirrorBase = 20_000;
        quote.mint(bob, 5_000_000);
        quote.mint(d00d, 5_000_000);

        vm.prank(bob);
        engine.fill(_order(mirrorBase - 1, 57, 0), false);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 99, 56, 0), true);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 1, 75, 0), true);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 1060, 42, 0), false);

        vm.prank(bob);
        bytes32 bobBid = engine.fill(_order(mirrorBase - 1, 83, 0), true);

        vm.prank(carol);
        engine.fill(_order(mirrorBase - 87, 19, 0), false);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 13769, 49, 0), false);

        vm.prank(bob);
        engine.fill(_order(mirrorBase - 1, 68, 0), true);

        (bytes32 aliasLeft, bytes32 aliasRight) = engine.tree(bobBid);
        assertEq(aliasLeft, bytes32(0));
        assertEq(aliasRight, bytes32(0));

        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_order(mirrorBase - 1, 15, 0), false);

        assertEq(restingAsk, bytes32(0));

        vm.prank(bob);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(bobBid);

        assertEq(baseAmount, 83);
        assertEq(quoteAmount, 0);
        assertEq(engine.ownerOfOrder(bobBid), address(0));
    }

    function test_PartialBidCorrectionSeparatesBranchAndStillCancels() public {
        address d00d = address(0xD00D);
        _fundAndApprove(d00d);

        int32 mirrorBase = 20_000;
        quote.mint(bob, 5_000_000);
        quote.mint(d00d, 5_000_000);

        vm.prank(bob);
        engine.fill(_order(mirrorBase - 1, 57, 0), false);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 99, 56, 0), true);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 1, 75, 0), true);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 1060, 42, 0), false);

        vm.prank(bob);
        bytes32 bobBid = engine.fill(_order(mirrorBase - 1, 83, 0), true);

        vm.prank(carol);
        engine.fill(_order(mirrorBase - 87, 19, 0), false);

        vm.prank(d00d);
        engine.fill(_order(mirrorBase - 13769, 49, 0), false);

        vm.prank(bob);
        engine.fill(_order(mirrorBase - 1, 68, 0), true);

        (bytes32 aliasLeft, bytes32 aliasRight) = engine.tree(bobBid);
        assertEq(aliasLeft, bytes32(0));
        assertEq(aliasRight, bytes32(0));

        vm.prank(bob);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(bobBid);

        assertEq(baseAmount, 68);
        assertEq(quoteAmount, _quoteValue(mirrorBase - 1, 15, true));
        assertEq(engine.ownerOfOrder(bobBid), address(0));
    }

    function test_SamePriceBranchSplitsAtFinalNonceBit() public {
        int32 price = 321;

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(price, 1, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(price, 1, 0), true);
        vm.prank(carol);
        bytes32 thirdBid = engine.fill(_order(price, 1, 0), true);

        assertEq(_nonce(firstBid), MAX_ORDER_NONCE);
        assertEq(_nonce(secondBid), MAX_ORDER_NONCE - 1);
        assertEq(_nonce(thirdBid), MAX_ORDER_NONCE - 2);
        assertEq(_commonPrefix(_pathKey(firstBid), _pathKey(secondBid)), 63);

        bytes32 finalSplit = _branchFor(firstBid, secondBid, true);
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(finalSplit);

        assertEq(_pathKey(finalSplit), _pathKey(firstBid));
        assertEq(_quantity(finalSplit), _quantity(firstBid) + _quantity(secondBid));
        assertEq(leftNode, secondBid);
        assertEq(rightNode, firstBid);
    }

    function test_SamePriceAskBranchSplitsAtFinalNonceBit() public {
        int32 price = 321;

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(price, 1, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(price, 1, 0), false);
        vm.prank(carol);
        bytes32 thirdAsk = engine.fill(_order(price, 1, 0), false);

        assertEq(_nonce(firstAsk), MAX_ORDER_NONCE);
        assertEq(_nonce(secondAsk), MAX_ORDER_NONCE - 1);
        assertEq(_nonce(thirdAsk), MAX_ORDER_NONCE - 2);
        assertEq(_commonPrefix(_askSortKey(firstAsk), _askSortKey(secondAsk)), 63);

        bytes32 finalSplit = _branchFor(firstAsk, secondAsk, false);
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(finalSplit);

        assertEq(_pathKey(finalSplit), _pathKey(firstAsk));
        assertEq(_quantity(finalSplit), _quantity(firstAsk) + _quantity(secondAsk));
        assertEq(leftNode, secondAsk);
        assertEq(rightNode, firstAsk);
    }

    function test_InsertPreservesChildBranchWhenItReusesParentAddress() public {
        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(108, 77, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(14, 19, 0), true);

        bytes32 oldRoot = _branchFor(firstBid, secondBid, true);
        assertEq(engine.bidRoot(), oldRoot);

        vm.prank(carol);
        bytes32 thirdBid = engine.fill(_order(80, 19, 0), true);

        bytes32 reusedChild = _branchFor(firstBid, thirdBid, true);
        bytes32 newRoot = _branchFor(secondBid, reusedChild, true);

        assertEq(reusedChild, oldRoot);
        assertEq(engine.bidRoot(), newRoot);

        (bytes32 rootLeft, bytes32 rootRight) = engine.tree(newRoot);
        assertEq(rootLeft, secondBid);
        assertEq(rootRight, reusedChild);

        (bytes32 childLeft, bytes32 childRight) = engine.tree(reusedChild);
        assertEq(childLeft, thirdBid);
        assertEq(childRight, firstBid);
    }

    function test_AskInsertPreservesChildBranchWhenItReusesParentAddress() public {
        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(108, 77, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(14, 19, 0), false);

        bytes32 oldRoot = _branchFor(firstAsk, secondAsk, false);
        assertEq(engine.askRoot(), oldRoot);

        vm.prank(carol);
        bytes32 thirdAsk = engine.fill(_order(80, 19, 0), false);

        bytes32 reusedChild = _branchFor(firstAsk, thirdAsk, false);
        bytes32 newRoot = _branchFor(secondAsk, reusedChild, false);
        (bytes32 expectedRootLeft, bytes32 expectedRootRight) = _expectedBranchChildren(secondAsk, reusedChild, false);
        (bytes32 expectedChildLeft, bytes32 expectedChildRight) = _expectedBranchChildren(firstAsk, thirdAsk, false);

        assertEq(reusedChild, oldRoot);
        assertEq(engine.askRoot(), newRoot);

        (bytes32 rootLeft, bytes32 rootRight) = engine.tree(newRoot);
        assertEq(rootLeft, expectedRootLeft);
        assertEq(rootRight, expectedRootRight);

        (bytes32 childLeft, bytes32 childRight) = engine.tree(reusedChild);
        assertEq(childLeft, expectedChildLeft);
        assertEq(childRight, expectedChildRight);
    }

    function test_PricePrefixCombFullyMatchesAndClaims() public {
        uint256 orderCount = 34;
        uint160 matchQuantity = 34;
        int32 maxPrice = type(int32).max;
        bytes32[] memory orders = new bytes32[](orderCount);
        int32[] memory prices = new int32[](orderCount);
        uint256 quoteTotal;

        quote.mint(alice, uint256(1) << 200);
        quote.mint(bob, uint256(1) << 200);
        quote.mint(carol, uint256(1) << 200);

        prices[0] = maxPrice;
        prices[1] = maxPrice;
        for (uint256 i; i < 32; ++i) {
            prices[i + 2] = _pricePrefixCombPrice(i);
        }

        for (uint256 i; i < orderCount; ++i) {
            address owner = _actorFor(i);
            vm.prank(owner);
            orders[i] = engine.fill(_order(prices[i], 1, 0), true);

            assertEq(uint256(_nonce(orders[i])), uint256(MAX_ORDER_NONCE) - i);
            assertEq(engine.ownerOfOrder(orders[i]), owner);
            quoteTotal += _quoteValue(prices[i], 1, true);
        }

        _assertBidPricePrefixCombShape();

        address seller = address(0x5E11E2);
        _fundAndApprove(seller);

        vm.prank(seller);
        bytes32 restingAsk = engine.fill(_order(type(int32).min, matchQuantity, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(base.balanceOf(address(engine)), orderCount);
        assertEq(quote.balanceOf(address(engine)), 0);
        assertEq(base.balanceOf(seller), 1_000_000 - orderCount);
        assertEq(quote.balanceOf(seller), 1_000_000 + quoteTotal);

        for (uint256 i; i < orderCount; ++i) {
            vm.prank(_actorFor(i));
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[i]);

            assertEq(baseAmount, 1);
            assertEq(quoteAmount, 0);
            assertEq(engine.ownerOfOrder(orders[i]), address(0));
        }

        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_FullDepthBidNonceCombFullyMatchesAndClaims() public {
        uint256 orderCount = 65;
        uint160 matchQuantity = 65;
        uint64 targetKey = type(uint64).max;
        (bytes32[] memory orders, uint256 quoteTotal) = _buildFullDepthBidNonceComb();

        bytes32 node = engine.bidRoot();
        for (uint256 depth; depth < 64; ++depth) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));

            assertTrue(leftNode != bytes32(0));
            assertTrue(rightNode != bytes32(0));
            assertEq(_commonPrefix(_pathKey(leftNode), _pathKey(rightNode)), depth);
            assertEq(_pathKey(leftNode), siblingKey);
            assertEq(_pathKey(rightNode), targetKey);
            // casting to uint160 is safe because the synthetic comb has 65 orders.
            // forge-lint: disable-next-line(unsafe-typecast)
            assertEq(_quantity(rightNode), uint160(orderCount - depth - 1));

            node = rightNode;
        }
        assertEq(node, orders[0]);

        address seller = address(0x5E11E2);
        _fundAndApprove(seller);

        vm.prank(seller);
        bytes32 restingAsk = engine.fill(_order(type(int32).min, matchQuantity, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(base.balanceOf(address(engine)), orderCount);
        assertEq(quote.balanceOf(address(engine)), 0);
        assertEq(base.balanceOf(seller), 1_000_000 - orderCount);
        assertEq(quote.balanceOf(seller), 1_000_000 + quoteTotal);

        for (uint256 i; i < orderCount; ++i) {
            vm.prank(alice);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[i]);

            assertEq(baseAmount, 1);
            assertEq(quoteAmount, 0);
            assertEq(engine.ownerOfOrder(orders[i]), address(0));
        }

        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_FullDepthBidNonceCombCancelsRightmostOrder() public {
        uint256 orderCount = 65;
        uint64 targetKey = type(uint64).max;
        (bytes32[] memory orders,) = _buildFullDepthBidNonceComb();

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[0]);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, _quoteValue(type(int32).max, 1, true));
        assertEq(engine.ownerOfOrder(orders[0]), address(0));
        assertEq(_pathKey(_rightmostLeaf(engine.bidRoot())), targetKey - 1);
        // casting to uint160 is safe because the synthetic comb has 65 orders.
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(_subtreeQuantity(engine.bidRoot()), uint160(orderCount - 1));
    }

    function test_MaxValidDepthAskNonceCombFullyMatchesAndClaims() public {
        uint256 orderCount = 65;
        uint160 matchQuantity = 65;
        (bytes32[] memory orders, uint256 quoteTotal) = _buildMaxValidDepthAskNonceComb();

        bytes32 node = engine.askRoot();
        for (uint256 depth; depth < 64; ++depth) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);

            assertTrue(leftNode != bytes32(0));
            assertTrue(rightNode != bytes32(0));
            assertEq(_commonPrefix(_askSortKey(leftNode), _askSortKey(rightNode)), depth);

            node = rightNode;
        }
        assertEq(node, orders[0]);

        address buyer = address(0xB0DE6A);
        _fundAndApprove(buyer);
        quote.mint(buyer, quoteTotal);

        vm.prank(buyer);
        bytes32 restingBid = engine.fill(_order(type(int32).max, matchQuantity, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), quoteTotal);
        assertEq(base.balanceOf(buyer), 1_000_000 + orderCount);
        assertEq(quote.balanceOf(buyer), 1_000_000);

        for (uint256 i; i < orderCount; ++i) {
            vm.prank(alice);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[i]);

            assertEq(baseAmount, 0);
            assertEq(quoteAmount, _quoteValue(_price(orders[i]), 1, false));
            assertEq(engine.ownerOfOrder(orders[i]), address(0));
        }

        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_MaxValidDepthAskNonceCombCancelsRightmostOrder() public {
        uint256 orderCount = 65;
        (bytes32[] memory orders,) = _buildMaxValidDepthAskNonceComb();

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[0]);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(engine.ownerOfOrder(orders[0]), address(0));
        assertTrue(engine.askRoot() != bytes32(0));
        // casting to uint160 is safe because the synthetic comb has 64 orders.
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(_subtreeQuantity(engine.askRoot()), uint160(orderCount - 1));
    }

    function test_AskPricePrefixCombFullyMatchesAndClaims() public {
        uint256 orderCount = 34;
        uint160 matchQuantity = 34;
        int32 maxPrice = type(int32).max;
        bytes32[] memory orders = new bytes32[](orderCount);
        int32[] memory prices = new int32[](orderCount);
        uint256 quoteTotal;

        prices[0] = type(int32).min;
        prices[1] = type(int32).min;
        for (uint256 i; i < 32; ++i) {
            prices[i + 2] = _askPricePrefixCombPrice(i);
        }

        for (uint256 i; i < orderCount; ++i) {
            address owner = _actorFor(i);
            vm.prank(owner);
            orders[i] = engine.fill(_order(prices[i], 1, 0), false);

            assertEq(uint256(_nonce(orders[i])), uint256(MAX_ORDER_NONCE) - i);
            assertEq(engine.ownerOfOrder(orders[i]), owner);
            quoteTotal += _quoteValue(prices[i], 1, false);
        }

        _assertAskPricePrefixCombShape();

        address buyer = address(0xB0DE6A);
        _fundAndApprove(buyer);
        quote.mint(buyer, quoteTotal);

        vm.prank(buyer);
        bytes32 restingBid = engine.fill(_order(maxPrice, matchQuantity, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), quoteTotal);
        assertEq(base.balanceOf(buyer), 1_000_000 + orderCount);
        assertEq(quote.balanceOf(buyer), 1_000_000);

        for (uint256 i; i < orderCount; ++i) {
            vm.prank(_actorFor(i));
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[i]);

            assertEq(baseAmount, 0);
            assertEq(quoteAmount, _quoteValue(prices[i], 1, false));
            assertEq(engine.ownerOfOrder(orders[i]), address(0));
        }

        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_CancelCollapsesBranchFromRoot() public {
        int32 price = 222;

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(price, 1, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(price, 1, 0), true);

        bytes32 branch = _branchFor(firstBid, secondBid, true);
        assertEq(engine.bidRoot(), branch);

        vm.prank(bob);
        engine.cancel(secondBid);

        assertEq(engine.bidRoot(), firstBid);
        assertTrue(engine.bidRoot() != branch);
    }

    function test_MatchCollapsesBranchFromRoot() public {
        int32 price = 333;

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(price, 1, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(price, 1, 0), false);

        bytes32 branch = _branchFor(firstAsk, secondAsk, false);
        assertEq(engine.askRoot(), branch);

        vm.prank(carol);
        engine.fill(_order(price, 1, 0), true);

        assertEq(engine.askRoot(), secondAsk);
        assertTrue(engine.askRoot() != branch);
    }

    function test_BidConsumesBestAskThenExactSamePriceOffSpineSubtree() public {
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(20, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(20, 3, 0), false);
        vm.prank(dave);
        bytes32 bestAsk = engine.fill(_order(10, 1, 0), false);

        bytes32 aggregate = _branchFor(firstAsk, secondAsk, false);
        assertEq(_subtreeQuantity(aggregate), 5);

        _expectAskMatches(
            _matchEventNode(bestAsk, 1, _quoteValue(10, 1, false), false),
            _matchEventNode(aggregate, 5, _uniformQuote(aggregate, false), false)
        );

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(20, 6, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(base.balanceOf(carol), 1_000_006);
        assertEq(
            quote.balanceOf(address(engine)),
            _quoteValue(10, 1, false) + _quoteValue(20, 2, false) + _quoteValue(20, 3, false)
        );

        vm.prank(alice);
        (, uint256 firstQuote) = engine.cancel(firstAsk);
        vm.prank(bob);
        (, uint256 secondQuote) = engine.cancel(secondAsk);
        vm.prank(dave);
        (, uint256 bestQuote) = engine.cancel(bestAsk);

        assertEq(firstQuote, _quoteValue(20, 2, false));
        assertEq(secondQuote, _quoteValue(20, 3, false));
        assertEq(bestQuote, _quoteValue(10, 1, false));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_BidConsumesBestAskThenExactMixedPriceOffSpineSubtree() public {
        _fundAndApprove(address(0xD00D));

        bytes32[3] memory asks;
        vm.prank(alice);
        asks[0] = engine.fill(_order(20, 2, 0), false);
        vm.prank(bob);
        asks[1] = engine.fill(_order(21, 3, 0), false);
        vm.prank(address(0xD00D));
        asks[2] = engine.fill(_order(10, 1, 0), false);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(asks[2], 1, _quoteValue(10, 1, false), false));
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskSubtreeMatched(
            _bookId(), _branchFor(asks[0], asks[1], false), 5, _quoteValue(20, 2, false) + _quoteValue(21, 3, false)
        );

        vm.prank(carol);
        assertEq(engine.fill(_order(21, 6, 0), true), bytes32(0));

        assertEq(engine.askRoot(), bytes32(0));
        assertEq(base.balanceOf(carol), 1_000_006);
        assertEq(
            quote.balanceOf(address(engine)),
            _quoteValue(10, 1, false) + _quoteValue(20, 2, false) + _quoteValue(21, 3, false)
        );

        {
            vm.prank(alice);
            (, uint256 lowerQuote) = engine.cancel(asks[0]);
            assertEq(lowerQuote, _quoteValue(20, 2, false));
        }
        {
            vm.prank(bob);
            (, uint256 higherQuote) = engine.cancel(asks[1]);
            assertEq(higherQuote, _quoteValue(21, 3, false));
        }
        {
            vm.prank(address(0xD00D));
            (, uint256 bestQuote) = engine.cancel(asks[2]);
            assertEq(bestQuote, _quoteValue(10, 1, false));
        }
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_AskConsumesBestBidThenExactSamePriceOffSpineSubtree() public {
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(70, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(70, 3, 0), true);
        vm.prank(dave);
        bytes32 bestBid = engine.fill(_order(80, 1, 0), true);

        bytes32 aggregate = _branchFor(firstBid, secondBid, true);
        assertEq(_subtreeQuantity(aggregate), 5);

        _expectBidMatches(
            _matchEventNode(bestBid, 1, _quoteValue(80, 1, true), true),
            _matchEventNode(aggregate, 5, _uniformQuote(aggregate, true), true)
        );

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(70, 6, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(base.balanceOf(carol), 999_994);
        assertEq(
            quote.balanceOf(carol),
            1_000_000 + _quoteValue(80, 1, true) + _quoteValue(70, 2, true) + _quoteValue(70, 3, true)
        );
        assertEq(base.balanceOf(address(engine)), 6);

        vm.prank(alice);
        (uint256 firstBase,) = engine.cancel(firstBid);
        vm.prank(bob);
        (uint256 secondBase,) = engine.cancel(secondBid);
        vm.prank(dave);
        (uint256 bestBase,) = engine.cancel(bestBid);

        assertEq(firstBase, 2);
        assertEq(secondBase, 3);
        assertEq(bestBase, 1);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_AskConsumesBestBidThenExactMixedPriceOffSpineSubtree() public {
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 higherBid = engine.fill(_order(70, 2, 0), true);
        vm.prank(bob);
        bytes32 lowerBid = engine.fill(_order(69, 3, 0), true);
        vm.prank(dave);
        bytes32 bestBid = engine.fill(_order(80, 1, 0), true);

        bytes32 subtreeRoot = _branchFor(higherBid, lowerBid, true);

        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(bestBid, 1, _quoteValue(80, 1, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidSubtreeMatched(_bookId(), subtreeRoot, 5, _quoteValue(70, 2, true) + _quoteValue(69, 3, true));

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(69, 6, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(base.balanceOf(carol), 999_994);
        assertEq(
            quote.balanceOf(carol),
            1_000_000 + _quoteValue(80, 1, true) + _quoteValue(70, 2, true) + _quoteValue(69, 3, true)
        );
        assertEq(base.balanceOf(address(engine)), 6);

        vm.prank(alice);
        (uint256 higherBase,) = engine.cancel(higherBid);
        vm.prank(bob);
        (uint256 lowerBase,) = engine.cancel(lowerBid);
        vm.prank(dave);
        (uint256 bestBase,) = engine.cancel(bestBid);

        assertEq(higherBase, 2);
        assertEq(lowerBase, 3);
        assertEq(bestBase, 1);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_BidPartiallyConsumesOffSpineAskSubtreeRecursively() public {
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 lowerAsk = engine.fill(_order(20, 2, 0), false);
        vm.prank(bob);
        bytes32 higherAsk = engine.fill(_order(21, 3, 0), false);
        vm.prank(dave);
        bytes32 bestAsk = engine.fill(_order(10, 1, 0), false);

        _expectAskMatches(
            _matchEventNode(bestAsk, 1, _quoteValue(10, 1, false), false),
            _matchEventNode(lowerAsk, 2, _quoteValue(20, 2, false), false),
            _matchEventNode(higherAsk, 1, _quoteValue(21, 3, false) - _quoteValue(21, 2, false), false)
        );

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(21, 4, 0), true);

        bytes32 reducedHigherAsk = _order(21, 2, _nonce(higherAsk));
        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), reducedHigherAsk);
        assertEq(base.balanceOf(carol), 1_000_004);
        assertEq(
            quote.balanceOf(address(engine)),
            _quoteValue(10, 1, false) + _quoteValue(20, 2, false)
                + (_quoteValue(21, 3, false) - _quoteValue(21, 2, false))
        );
        assertEq(base.balanceOf(address(engine)), 2);

        vm.prank(alice);
        (, uint256 lowerQuote) = engine.cancel(lowerAsk);
        vm.prank(bob);
        (uint256 higherBase, uint256 higherQuote) = engine.cancel(higherAsk);
        vm.prank(dave);
        (, uint256 bestQuote) = engine.cancel(bestAsk);

        assertEq(lowerQuote, _quoteValue(20, 2, false));
        assertEq(higherBase, 2);
        assertEq(higherQuote, _quoteValue(21, 3, false) - _quoteValue(21, 2, false));
        assertEq(bestQuote, _quoteValue(10, 1, false));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_BidStopsInsideOffSpineAskSubtreeWhenNextAskDoesNotCross() public {
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 lowerAsk = engine.fill(_order(30, 2, 0), false);
        vm.prank(bob);
        bytes32 higherAsk = engine.fill(_order(31, 3, 0), false);
        vm.prank(dave);
        bytes32 bestAsk = engine.fill(_order(10, 1, 0), false);

        bytes32 offSpineAggregate = _branchFor(lowerAsk, higherAsk, false);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(bestAsk, 1, _quoteValue(10, 1, false), false));

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(20, 4, 0), true);

        assertEq(restingBid, _order(20, 3, MAX_ORDER_NONCE - 3));
        assertEq(engine.askRoot(), offSpineAggregate);
        assertEq(engine.bidRoot(), restingBid);
        assertEq(base.balanceOf(carol), 1_000_001);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(10, 1, false) + _quoteValue(20, 3, true));

        vm.prank(alice);
        (uint256 lowerBase,) = engine.cancel(lowerAsk);
        vm.prank(bob);
        (uint256 higherBase,) = engine.cancel(higherAsk);
        vm.prank(dave);
        (, uint256 bestQuote) = engine.cancel(bestAsk);
        vm.prank(carol);
        (, uint256 bidQuote) = engine.cancel(restingBid);

        assertEq(lowerBase, 2);
        assertEq(higherBase, 3);
        assertEq(bestQuote, _quoteValue(10, 1, false));
        assertEq(bidQuote, _quoteValue(20, 3, true));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_AskPartiallyConsumesOffSpineBidSubtreeRecursively() public {
        _fundAndApprove(address(0xD00D));

        bytes32[3] memory bids;
        vm.prank(alice);
        bids[0] = engine.fill(_order(70, 2, 0), true);
        vm.prank(bob);
        bids[1] = engine.fill(_order(69, 3, 0), true);
        vm.prank(address(0xD00D));
        bids[2] = engine.fill(_order(80, 1, 0), true);

        _expectBidMatches(
            _matchEventNode(bids[2], 1, _quoteValue(80, 1, true), true),
            _matchEventNode(bids[0], 2, _quoteValue(70, 2, true), true),
            _matchEventNode(bids[1], 1, _quoteValue(69, 3, true) - _quoteValue(69, 2, true), true)
        );

        vm.prank(carol);
        assertEq(engine.fill(_order(69, 4, 0), false), bytes32(0));

        assertEq(engine.bidRoot(), _order(69, 2, _nonce(bids[1])));
        assertEq(base.balanceOf(address(engine)), 4);
        assertEq(
            quote.balanceOf(carol),
            1_000_000 + _quoteValue(80, 1, true) + _quoteValue(70, 2, true)
                + (_quoteValue(69, 3, true) - _quoteValue(69, 2, true))
        );

        {
            vm.prank(alice);
            (uint256 higherBase,) = engine.cancel(bids[0]);
            assertEq(higherBase, 2);
        }
        {
            vm.prank(bob);
            (uint256 lowerBase, uint256 lowerQuote) = engine.cancel(bids[1]);
            assertEq(lowerBase, 1);
            assertEq(lowerQuote, _quoteValue(69, 2, true));
        }
        {
            vm.prank(address(0xD00D));
            (uint256 bestBase,) = engine.cancel(bids[2]);
            assertEq(bestBase, 1);
        }
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_AskStopsInsideOffSpineBidSubtreeWhenNextBidDoesNotCross() public {
        bytes32[4] memory orders = _seedNonCrossingBidSubtree();

        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(orders[2], 1, _quoteValue(80, 1, true), true));

        vm.prank(carol);
        orders[3] = engine.fill(_order(70, 4, 0), false);

        assertEq(orders[3], _order(70, 3, MAX_ORDER_NONCE - 3));
        assertEq(engine.bidRoot(), _branchFor(orders[0], orders[1], true));
        assertEq(engine.askRoot(), orders[3]);
        assertEq(base.balanceOf(address(engine)), 4);
        assertEq(quote.balanceOf(carol), 1_000_000 + _quoteValue(80, 1, true));

        _cancelNonCrossingBidSubtreeOrders(orders);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function _seedNonCrossingBidSubtree() private returns (bytes32[4] memory orders) {
        _fundAndApprove(dave);
        vm.prank(alice);
        orders[0] = engine.fill(_order(60, 2, 0), true);
        vm.prank(bob);
        orders[1] = engine.fill(_order(59, 3, 0), true);
        vm.prank(dave);
        orders[2] = engine.fill(_order(80, 1, 0), true);
    }

    function _cancelNonCrossingBidSubtreeOrders(bytes32[4] memory orders) private {
        vm.prank(alice);
        (, uint256 higherQuote) = engine.cancel(orders[0]);
        assertEq(higherQuote, _quoteValue(60, 2, true));

        vm.prank(bob);
        (, uint256 lowerQuote) = engine.cancel(orders[1]);
        assertEq(lowerQuote, _quoteValue(59, 3, true));

        vm.prank(dave);
        (uint256 bestBase,) = engine.cancel(orders[2]);
        assertEq(bestBase, 1);

        vm.prank(carol);
        (uint256 askBase,) = engine.cancel(orders[3]);
        assertEq(askBase, 3);
    }

    function test_CancelAskFromLeftBranchRewritesParent() public {
        vm.prank(alice);
        bytes32 worseAsk = engine.fill(_order(20, 1, 0), false);
        vm.prank(bob);
        bytes32 betterAsk = engine.fill(_order(10, 1, 0), false);

        assertTrue(engine.askRoot() != worseAsk);
        assertTrue(engine.askRoot() != betterAsk);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(worseAsk);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(engine.askRoot(), betterAsk);

        vm.prank(bob);
        (baseAmount, quoteAmount) = engine.cancel(betterAsk);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_SamePriceAskAggregateMatchStillLetsEachMakerClaim() public {
        int32 price = 50;

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(price, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(price, 3, 0), false);

        bytes32 aggregate = _branchFor(firstAsk, secondAsk, false);
        assertEq(engine.askRoot(), aggregate);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(aggregate, 5, _uniformQuote(aggregate, false), false));

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(price, 5, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(base.balanceOf(carol), 1_000_005);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(price, 2, false) + _quoteValue(price, 3, false));
        assertEq(engine.ownerOfOrder(firstAsk), alice);
        assertEq(engine.ownerOfOrder(secondAsk), bob);
        assertFalse(engine.isBidOrder(firstAsk));
        assertFalse(engine.isBidOrder(secondAsk));

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstAsk);

        assertEq(firstBaseAmount, 0);
        assertEq(firstQuoteAmount, _quoteValue(price, 2, false));
        assertEq(engine.ownerOfOrder(firstAsk), address(0));
        assertEq(engine.ownerOfOrder(_order(price, 0, _nonce(firstAsk))), address(0));

        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondAsk);

        assertEq(secondBaseAmount, 0);
        assertEq(secondQuoteAmount, _quoteValue(price, 3, false));
        assertEq(engine.ownerOfOrder(secondAsk), address(0));
        assertEq(engine.ownerOfOrder(_order(price, 0, _nonce(secondAsk))), address(0));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_SamePriceBidAggregateMatchStillLetsEachMakerClaim() public {
        int32 price = 70;

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(price, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(price, 3, 0), true);

        bytes32 aggregate = _branchFor(firstBid, secondBid, true);
        assertEq(engine.bidRoot(), aggregate);

        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(aggregate, 5, _uniformQuote(aggregate, true), true));

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(price, 5, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(base.balanceOf(carol), 999_995);
        assertEq(quote.balanceOf(carol), 1_000_000 + _quoteValue(price, 2, true) + _quoteValue(price, 3, true));
        assertEq(base.balanceOf(address(engine)), 5);
        assertEq(engine.ownerOfOrder(firstBid), alice);
        assertEq(engine.ownerOfOrder(secondBid), bob);
        assertTrue(engine.isBidOrder(firstBid));
        assertTrue(engine.isBidOrder(secondBid));

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstBid);

        assertEq(firstBaseAmount, 2);
        assertEq(firstQuoteAmount, 0);
        assertEq(engine.ownerOfOrder(firstBid), address(0));
        assertEq(engine.ownerOfOrder(_order(price, 0, _nonce(firstBid))), address(0));

        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondBid);

        assertEq(secondBaseAmount, 3);
        assertEq(secondQuoteAmount, 0);
        assertEq(engine.ownerOfOrder(secondBid), address(0));
        assertEq(engine.ownerOfOrder(_order(price, 0, _nonce(secondBid))), address(0));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_DirtySamePriceAskRightSpineAggregatesAndClaims() public {
        int32 price = 60;

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(price, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(price, 3, 0), false);

        bytes32 aggregate = _branchFor(firstAsk, secondAsk, false);
        assertEq(engine.askRoot(), aggregate);

        vm.prank(carol);
        engine.fill(_order(price, 1, 0), true);

        assertEq(engine.askRoot(), aggregate);
        assertEq(_subtreeQuantity(engine.askRoot()), 4);

        bytes32 dirtyAggregate =
            bytes32(uint256(_order(price, 4, _nonce(firstAsk))) | (uint256(_correctionCode(aggregate)) << 32));
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(
            _bookId(),
            _matchEventNode(dirtyAggregate, 4, _quoteValue(price, 1, false) + _quoteValue(price, 3, false), false)
        );

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(price, 4, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstAsk);
        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondAsk);

        assertEq(firstBaseAmount, 0);
        assertEq(firstQuoteAmount, _quoteValue(price, 2, false));
        assertEq(secondBaseAmount, 0);
        assertEq(secondQuoteAmount, _quoteValue(price, 3, false));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_DirtySamePriceBidRightSpineAggregatesAndClaims() public {
        int32 price = 80;

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(price, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(price, 3, 0), true);

        bytes32 aggregate = _branchFor(firstBid, secondBid, true);
        assertEq(engine.bidRoot(), aggregate);

        vm.prank(carol);
        engine.fill(_order(price, 1, 0), false);

        assertEq(engine.bidRoot(), aggregate);
        assertEq(_subtreeQuantity(engine.bidRoot()), 4);

        bytes32 dirtyAggregate =
            bytes32(uint256(_order(price, 4, _nonce(firstBid))) | (uint256(_correctionCode(aggregate)) << 32));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(
            _bookId(),
            _matchEventNode(dirtyAggregate, 4, _quoteValue(price, 1, true) + _quoteValue(price, 3, true), true)
        );

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(price, 4, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstBid);
        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondBid);

        assertEq(firstBaseAmount, 2);
        assertEq(firstQuoteAmount, 0);
        assertEq(secondBaseAmount, 3);
        assertEq(secondQuoteAmount, 0);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_DirtyAskRightSpineUsesContractRoutingForMixedPrices() public {
        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(60, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(61, 3, 0), false);

        bytes32 dirtyAnchor = _branchFor(firstAsk, secondAsk, false);
        assertEq(engine.askRoot(), dirtyAnchor);

        vm.prank(carol);
        engine.fill(_order(60, 1, 0), true);

        bytes32 reducedFirstAsk = _order(60, 1, _nonce(firstAsk));
        assertEq(engine.askRoot(), dirtyAnchor);
        assertEq(_quantity(engine.askRoot()), 5);
        assertEq(_subtreeQuantity(engine.askRoot()), 4);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 2) | ASK_RIGHT_SPINE_DIRTY
        );

        _expectAskMatches(
            _matchEventNode(reducedFirstAsk, 1, _quoteValue(60, 1, false), false),
            _matchEventNode(secondAsk, 3, _quoteValue(61, 3, false), false)
        );

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(61, 4, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstAsk);
        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondAsk);

        assertEq(firstBaseAmount, 0);
        assertEq(firstQuoteAmount, _quoteValue(60, 2, false));
        assertEq(secondBaseAmount, 0);
        assertEq(secondQuoteAmount, _quoteValue(61, 3, false));
        assertEq(base.balanceOf(carol), 1_000_005);
        assertEq(quote.balanceOf(carol), 1_000_000 - _quoteValue(60, 2, false) - _quoteValue(61, 3, false));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_DirtyBidRightSpineUsesContractRoutingForMixedPrices() public {
        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(80, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(79, 3, 0), true);

        bytes32 dirtyAnchor = _branchFor(firstBid, secondBid, true);
        assertEq(engine.bidRoot(), dirtyAnchor);

        vm.prank(carol);
        engine.fill(_order(80, 1, 0), false);

        bytes32 reducedFirstBid = _order(80, 1, _nonce(firstBid));
        assertEq(engine.bidRoot(), dirtyAnchor);
        assertEq(_quantity(engine.bidRoot()), 5);
        assertEq(_subtreeQuantity(engine.bidRoot()), 4);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 2) | BID_RIGHT_SPINE_DIRTY
        );

        _expectBidMatches(
            _matchEventNode(reducedFirstBid, 1, _quoteValue(80, 1, true), true),
            _matchEventNode(secondBid, 3, _quoteValue(79, 3, true), true)
        );

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(79, 4, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), bytes32(0));

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstBid);
        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondBid);

        assertEq(firstBaseAmount, 2);
        assertEq(firstQuoteAmount, 0);
        assertEq(secondBaseAmount, 3);
        assertEq(secondQuoteAmount, 0);
        assertEq(base.balanceOf(carol), 1_000_000 - 1 - 4);
        assertEq(quote.balanceOf(carol), 1_000_000 + _quoteValue(80, 2, true) + _quoteValue(79, 3, true));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_CorruptedEqualPackedAskBranchDoesNotAggregateMixedPriceLeaves() public {
        bytes32 leftAsk = _order(10, 1, MAX_ORDER_NONCE);
        bytes32 rightLeftAsk = _order(10, 1, MAX_ORDER_NONCE - 1);
        bytes32 rightRightAsk = _order(11, 1, MAX_ORDER_NONCE - 2);
        bytes32 rightBranch = _order(10, 2, MAX_ORDER_NONCE - 1);
        bytes32 root = _order(10, 3, MAX_ORDER_NONCE);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        _storeTreeBranch(root, leftAsk, rightBranch);
        _storeTreeBranch(rightBranch, rightLeftAsk, rightRightAsk);
        vm.store(address(engine), _askRootSlot(), root);

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(9, 1, 0), true);

        assertEq(restingBid, _order(9, 1, MAX_ORDER_NONCE));
        assertEq(engine.askRoot(), root);
        assertEq(engine.bidRoot(), restingBid);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(9, 1, true));
        assertEq(base.balanceOf(address(engine)), 0);
    }

    function test_CorruptedRightSpineBranchNodeAliasRecomputesBranch() public {
        int32 price = 50;
        bytes32 leftAsk = _order(price, 2, MAX_ORDER_NONCE - 1);
        bytes32 rightAsk = _order(price, 5, MAX_ORDER_NONCE);
        bytes32 root = _order(price, 4, MAX_ORDER_NONCE);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        _storeTreeBranch(root, leftAsk, rightAsk);
        vm.store(address(engine), _askRootSlot(), root);
        base.mint(address(engine), 1);

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(price, 1, 0), true);

        bytes32 expectedRoot = _branchFor(leftAsk, root, false);
        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), expectedRoot);
        _assertTreeBranchStorage(expectedRoot, leftAsk, root, "alias-recomputed");
        assertEq(base.balanceOf(carol), 1_000_001);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(price, 1, false));
    }

    function test_CorruptedRightSpineDuplicateChildAliasRecomputesBranch() public {
        int32 price = 51;
        bytes32 leftAsk = _order(price, 4, MAX_ORDER_NONCE - 1);
        bytes32 rightAsk = _order(price, 5, MAX_ORDER_NONCE - 1);
        bytes32 root = _order(price, 6, MAX_ORDER_NONCE);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        _storeTreeBranch(root, leftAsk, rightAsk);
        vm.store(address(engine), _askRootSlot(), root);
        base.mint(address(engine), 1);

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(price, 1, 0), true);

        bytes32 expectedRoot = _branchFor(leftAsk, leftAsk, false);
        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), expectedRoot);
        _assertTreeBranchStorage(expectedRoot, leftAsk, leftAsk, "duplicate-child-recomputed");
        assertEq(base.balanceOf(carol), 1_000_001);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(price, 1, false));
    }

    function test_AskDirtyRightSpineSurvivesBidRestAndMaterializesBeforeAskInsert() public {
        int32 price = 60;

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(price, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(price, 3, 0), false);

        bytes32 dirtyAnchor = _branchFor(firstAsk, secondAsk, false);
        assertEq(engine.askRoot(), dirtyAnchor);

        vm.prank(carol);
        engine.fill(_order(price, 1, 0), true);

        assertEq(engine.askRoot(), dirtyAnchor);
        assertEq(_quantity(engine.askRoot()), 5);
        assertEq(_subtreeQuantity(engine.askRoot()), 4);
        assertEq(uint256(engine.nextNonce()), uint256(MAX_ORDER_NONCE) - 2);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 2) | ASK_RIGHT_SPINE_DIRTY
        );

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(price - 1, 1, 0), true);

        assertEq(restingBid, _order(price - 1, 1, MAX_ORDER_NONCE - 2));
        assertEq(engine.askRoot(), dirtyAnchor);
        assertEq(_quantity(engine.askRoot()), 5);
        assertEq(_subtreeQuantity(engine.askRoot()), 4);
        assertEq(uint256(engine.nextNonce()), uint256(MAX_ORDER_NONCE) - 3);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 3) | ASK_RIGHT_SPINE_DIRTY
        );

        vm.prank(carol);
        bytes32 thirdAsk = engine.fill(_order(price + 1, 1, 0), false);

        assertEq(thirdAsk, _order(price + 1, 1, MAX_ORDER_NONCE - 3));
        assertEq(_quantity(engine.askRoot()), 5);
        assertEq(_subtreeQuantity(engine.askRoot()), 5);
        assertEq(uint256(engine.nextNonce()), uint256(MAX_ORDER_NONCE) - 4);
        assertEq(uint256(vm.load(address(engine), _nextNonceSlot())), uint256(MAX_ORDER_NONCE) - 4);

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstAsk);
        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondAsk);
        vm.prank(carol);
        (uint256 thirdBaseAmount, uint256 thirdQuoteAmount) = engine.cancel(thirdAsk);
        vm.prank(alice);
        (uint256 bidBaseAmount, uint256 bidQuoteAmount) = engine.cancel(restingBid);

        assertEq(firstBaseAmount, 1);
        assertEq(firstQuoteAmount, _quoteValue(price, 2, false) - _quoteValue(price, 1, false));
        assertEq(secondBaseAmount, 3);
        assertEq(secondQuoteAmount, 0);
        assertEq(thirdBaseAmount, 1);
        assertEq(thirdQuoteAmount, 0);
        assertEq(bidBaseAmount, 0);
        assertEq(bidQuoteAmount, _quoteValue(price - 1, 1, true));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_BidDirtyRightSpineSurvivesAskRestAndMaterializesBeforeBidInsert() public {
        int32 price = 70;

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(price, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(price, 3, 0), true);

        bytes32 dirtyAnchor = _branchFor(firstBid, secondBid, true);
        assertEq(engine.bidRoot(), dirtyAnchor);

        vm.prank(carol);
        engine.fill(_order(price, 1, 0), false);

        assertEq(engine.bidRoot(), dirtyAnchor);
        assertEq(_quantity(engine.bidRoot()), 5);
        assertEq(_subtreeQuantity(engine.bidRoot()), 4);
        assertEq(uint256(engine.nextNonce()), uint256(MAX_ORDER_NONCE) - 2);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 2) | BID_RIGHT_SPINE_DIRTY
        );

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(price + 1, 1, 0), false);

        assertEq(restingAsk, _order(price + 1, 1, MAX_ORDER_NONCE - 2));
        assertEq(engine.bidRoot(), dirtyAnchor);
        assertEq(_quantity(engine.bidRoot()), 5);
        assertEq(_subtreeQuantity(engine.bidRoot()), 4);
        assertEq(uint256(engine.nextNonce()), uint256(MAX_ORDER_NONCE) - 3);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 3) | BID_RIGHT_SPINE_DIRTY
        );

        vm.prank(alice);
        bytes32 thirdBid = engine.fill(_order(price - 1, 1, 0), true);

        assertEq(thirdBid, _order(price - 1, 1, MAX_ORDER_NONCE - 3));
        assertEq(_quantity(engine.bidRoot()), 5);
        assertEq(_subtreeQuantity(engine.bidRoot()), 5);
        assertEq(uint256(engine.nextNonce()), uint256(MAX_ORDER_NONCE) - 4);
        assertEq(uint256(vm.load(address(engine), _nextNonceSlot())), uint256(MAX_ORDER_NONCE) - 4);

        vm.prank(alice);
        (uint256 firstBaseAmount, uint256 firstQuoteAmount) = engine.cancel(firstBid);
        vm.prank(bob);
        (uint256 secondBaseAmount, uint256 secondQuoteAmount) = engine.cancel(secondBid);
        vm.prank(alice);
        (uint256 thirdBaseAmount, uint256 thirdQuoteAmount) = engine.cancel(thirdBid);
        vm.prank(carol);
        (uint256 askBaseAmount, uint256 askQuoteAmount) = engine.cancel(restingAsk);

        assertEq(firstBaseAmount, 1);
        assertEq(firstQuoteAmount, _quoteValue(price, 1, true));
        assertEq(secondBaseAmount, 0);
        assertEq(secondQuoteAmount, _quoteValue(price, 3, true));
        assertEq(thirdBaseAmount, 0);
        assertEq(thirdQuoteAmount, _quoteValue(price - 1, 1, true));
        assertEq(askBaseAmount, 1);
        assertEq(askQuoteAmount, 0);
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), 0);
    }

    function test_BidMatchRevertsAtomicallyWhenQuotePullFails() public {
        address poorTaker = address(0xBAD);

        vm.prank(bob);
        bytes32 firstAsk = engine.fill(_order(80, 1, 0), false);
        vm.prank(carol);
        bytes32 secondAsk = engine.fill(_order(90, 1, 0), false);

        bytes32 askRootBefore = engine.askRoot();
        assertTrue(askRootBefore != firstAsk && askRootBefore != secondAsk);

        vm.prank(poorTaker);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        engine.fill(_order(100, 2, 0), true);

        assertEq(engine.askRoot(), askRootBefore);
        assertEq(engine.ownerOfOrder(firstAsk), bob);
        assertEq(engine.ownerOfOrder(secondAsk), carol);
        assertFalse(engine.isBidOrder(firstAsk));
        assertFalse(engine.isBidOrder(secondAsk));
        assertEq(base.balanceOf(address(engine)), 2);
        assertEq(quote.balanceOf(address(engine)), 0);
        assertEq(base.balanceOf(poorTaker), 0);
        assertEq(quote.balanceOf(poorTaker), 0);
    }

    function test_AskMatchRevertsAtomicallyWhenBasePullFails() public {
        address poorTaker = address(0xBAD);

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(100, 1, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(90, 1, 0), true);

        bytes32 bidRootBefore = engine.bidRoot();
        assertTrue(bidRootBefore != firstBid && bidRootBefore != secondBid);

        vm.prank(poorTaker);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        engine.fill(_order(80, 2, 0), false);

        assertEq(engine.bidRoot(), bidRootBefore);
        assertEq(engine.ownerOfOrder(firstBid), alice);
        assertEq(engine.ownerOfOrder(secondBid), bob);
        assertTrue(engine.isBidOrder(firstBid));
        assertTrue(engine.isBidOrder(secondBid));
        assertEq(base.balanceOf(address(engine)), 0);
        assertEq(quote.balanceOf(address(engine)), _quoteValue(100, 1, true) + _quoteValue(90, 1, true));
        assertEq(base.balanceOf(poorTaker), 0);
        assertEq(quote.balanceOf(poorTaker), 0);
    }

    function test_FalseReturnCollateralPullRevertsBeforeRestingBid() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FalseReturnERC20 falseQuote = new FalseReturnERC20();
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(plainBase), address(falseQuote));

        falseQuote.mint(alice, 1_000);
        falseQuote.setFailTransferFrom(true);

        bytes32 expectedBid = _order(10, 2, MAX_ORDER_NONCE);

        vm.startPrank(alice);
        falseQuote.approve(address(falseEngine), type(uint256).max);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        falseEngine.fill(_order(10, 2, 0), true);
        vm.stopPrank();

        assertEq(falseEngine.bidRoot(), bytes32(0));
        assertEq(falseEngine.ownerOfOrder(expectedBid), address(0));
        assertEq(falseEngine.ownerOfOrder(_order(10, 0, _nonce(expectedBid))), address(0));
        assertEq(falseEngine.nextNonce(), 0);
        assertEq(falseQuote.balanceOf(address(falseEngine)), 0);
        assertEq(falseQuote.balanceOf(alice), 1_000);
    }

    function test_FalseReturnCollateralPullRevertsBeforeRestingAsk() public {
        FalseReturnERC20 falseBase = new FalseReturnERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(falseBase), address(plainQuote));

        falseBase.mint(alice, 1_000);
        falseBase.setFailTransferFrom(true);

        bytes32 expectedAsk = _order(10, 2, MAX_ORDER_NONCE);

        vm.startPrank(alice);
        falseBase.approve(address(falseEngine), type(uint256).max);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        falseEngine.fill(_order(10, 2, 0), false);
        vm.stopPrank();

        assertEq(falseEngine.askRoot(), bytes32(0));
        assertEq(falseEngine.ownerOfOrder(expectedAsk), address(0));
        assertEq(falseEngine.ownerOfOrder(_order(10, 0, _nonce(expectedAsk))), address(0));
        assertEq(falseEngine.nextNonce(), 0);
        assertEq(falseBase.balanceOf(address(falseEngine)), 0);
        assertEq(falseBase.balanceOf(alice), 1_000);
    }

    function test_FalseReturnBidPartialRestQuotePullRevertsAtomically() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FalseReturnERC20 falseQuote = new FalseReturnERC20();
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(plainBase), address(falseQuote));

        plainBase.mint(bob, 1_000);
        falseQuote.mint(alice, 1_000);

        vm.startPrank(bob);
        plainBase.approve(address(falseEngine), type(uint256).max);
        bytes32 restingAsk = falseEngine.fill(_order(10, 1, 0), false);
        vm.stopPrank();

        falseQuote.setFailTransferFrom(true);

        bytes32 expectedBid = _order(10, 1, MAX_ORDER_NONCE - 1);

        vm.startPrank(alice);
        falseQuote.approve(address(falseEngine), type(uint256).max);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        falseEngine.fill(_order(10, 2, 0), true);
        vm.stopPrank();

        assertEq(falseEngine.askRoot(), restingAsk);
        assertEq(falseEngine.bidRoot(), bytes32(0));
        assertEq(falseEngine.ownerOfOrder(restingAsk), bob);
        assertFalse(falseEngine.isBidOrder(restingAsk));
        assertEq(falseEngine.ownerOfOrder(expectedBid), address(0));
        assertEq(falseEngine.ownerOfOrder(_order(10, 0, _nonce(expectedBid))), address(0));
        assertEq(falseEngine.nextNonce(), MAX_ORDER_NONCE - 1);
        assertEq(plainBase.balanceOf(address(falseEngine)), 1);
        assertEq(falseQuote.balanceOf(address(falseEngine)), 0);
    }

    function test_FalseReturnAskPartialRestBasePullRevertsAtomically() public {
        FalseReturnERC20 falseBase = new FalseReturnERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(falseBase), address(plainQuote));

        falseBase.mint(alice, 1_000);
        plainQuote.mint(bob, 1_000);

        vm.startPrank(bob);
        plainQuote.approve(address(falseEngine), type(uint256).max);
        bytes32 restingBid = falseEngine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        falseBase.setFailTransferFrom(true);

        bytes32 expectedAsk = _order(10, 1, MAX_ORDER_NONCE - 1);

        vm.startPrank(alice);
        falseBase.approve(address(falseEngine), type(uint256).max);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        falseEngine.fill(_order(10, 2, 0), false);
        vm.stopPrank();

        assertEq(falseEngine.bidRoot(), restingBid);
        assertEq(falseEngine.askRoot(), bytes32(0));
        assertEq(falseEngine.ownerOfOrder(restingBid), bob);
        assertTrue(falseEngine.isBidOrder(restingBid));
        assertEq(falseEngine.ownerOfOrder(expectedAsk), address(0));
        assertEq(falseEngine.ownerOfOrder(_order(10, 0, _nonce(expectedAsk))), address(0));
        assertEq(falseEngine.nextNonce(), MAX_ORDER_NONCE - 1);
        assertEq(falseBase.balanceOf(address(falseEngine)), 0);
        assertEq(plainQuote.balanceOf(address(falseEngine)), _quoteValue(10, 1, true));
    }

    function test_FalseReturnFilledBidClaimRevertsAndPreservesClaim() public {
        FalseReturnERC20 falseBase = new FalseReturnERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(falseBase), address(plainQuote));

        plainQuote.mint(alice, 1_000);
        falseBase.mint(bob, 1_000);

        vm.startPrank(alice);
        plainQuote.approve(address(falseEngine), type(uint256).max);
        bytes32 restingBid = falseEngine.fill(_order(10, 2, 0), true);
        vm.stopPrank();

        vm.startPrank(bob);
        falseBase.approve(address(falseEngine), type(uint256).max);
        falseEngine.fill(_order(10, 2, 0), false);
        vm.stopPrank();

        assertEq(falseEngine.bidRoot(), bytes32(0));
        assertEq(falseBase.balanceOf(address(falseEngine)), 2);

        falseBase.setFailTransfer(true);

        vm.prank(alice);
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        falseEngine.cancel(restingBid);

        assertEq(falseEngine.ownerOfOrder(restingBid), alice);
        assertTrue(falseEngine.isBidOrder(restingBid));
        assertEq(falseBase.balanceOf(address(falseEngine)), 2);
        assertEq(falseBase.balanceOf(alice), 0);
    }

    function test_FalseReturnFilledAskClaimRevertsAndPreservesClaim() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FalseReturnERC20 falseQuote = new FalseReturnERC20();
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(plainBase), address(falseQuote));

        plainBase.mint(alice, 1_000);
        falseQuote.mint(bob, 1_000);

        vm.startPrank(alice);
        plainBase.approve(address(falseEngine), type(uint256).max);
        bytes32 restingAsk = falseEngine.fill(_order(10, 2, 0), false);
        vm.stopPrank();

        vm.startPrank(bob);
        falseQuote.approve(address(falseEngine), type(uint256).max);
        falseEngine.fill(_order(10, 2, 0), true);
        vm.stopPrank();

        assertEq(falseEngine.askRoot(), bytes32(0));
        assertEq(falseQuote.balanceOf(address(falseEngine)), _quoteValue(10, 2, false));

        falseQuote.setFailTransfer(true);

        vm.prank(alice);
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        falseEngine.cancel(restingAsk);

        assertEq(falseEngine.ownerOfOrder(restingAsk), alice);
        assertFalse(falseEngine.isBidOrder(restingAsk));
        assertEq(falseQuote.balanceOf(address(falseEngine)), _quoteValue(10, 2, false));
        assertEq(falseQuote.balanceOf(alice), 0);
    }

    function test_FalseReturnPartialBidCancelRevertsAfterBasePayoutAndPreservesClaim() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FalseReturnERC20 falseQuote = new FalseReturnERC20();
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(plainBase), address(falseQuote));

        plainBase.mint(alice, 1_000);
        plainBase.mint(bob, 1_000);
        falseQuote.mint(alice, 1_000);
        falseQuote.mint(bob, 1_000);

        vm.startPrank(alice);
        plainBase.approve(address(falseEngine), type(uint256).max);
        falseQuote.approve(address(falseEngine), type(uint256).max);
        bytes32 restingBid = falseEngine.fill(_order(10, 5, 0), true);
        vm.stopPrank();

        vm.startPrank(bob);
        plainBase.approve(address(falseEngine), type(uint256).max);
        falseQuote.approve(address(falseEngine), type(uint256).max);
        falseEngine.fill(_order(10, 2, 0), false);
        vm.stopPrank();

        bytes32 bidRootBefore = falseEngine.bidRoot();
        uint256 engineBaseBefore = plainBase.balanceOf(address(falseEngine));
        uint256 engineQuoteBefore = falseQuote.balanceOf(address(falseEngine));
        uint256 aliceBaseBefore = plainBase.balanceOf(alice);
        uint256 aliceQuoteBefore = falseQuote.balanceOf(alice);

        assertEq(bidRootBefore, _order(10, 3, MAX_ORDER_NONCE));
        assertEq(engineBaseBefore, 2);
        assertEq(engineQuoteBefore, _quoteValue(10, 3, true));

        falseQuote.setFailTransfer(true);

        vm.prank(alice);
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        falseEngine.cancel(restingBid);

        assertEq(falseEngine.bidRoot(), bidRootBefore);
        assertEq(falseEngine.ownerOfOrder(restingBid), alice);
        assertTrue(falseEngine.isBidOrder(restingBid));
        assertEq(plainBase.balanceOf(address(falseEngine)), engineBaseBefore);
        assertEq(falseQuote.balanceOf(address(falseEngine)), engineQuoteBefore);
        assertEq(plainBase.balanceOf(alice), aliceBaseBefore);
        assertEq(falseQuote.balanceOf(alice), aliceQuoteBefore);
    }

    function test_FalseReturnPartialAskCancelRevertsAfterBasePayoutAndPreservesClaim() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FalseReturnERC20 falseQuote = new FalseReturnERC20();
        RadixMatchingEngine falseEngine = new RadixMatchingEngine(address(plainBase), address(falseQuote));

        plainBase.mint(alice, 1_000);
        plainBase.mint(bob, 1_000);
        falseQuote.mint(alice, 1_000);
        falseQuote.mint(bob, 1_000);

        vm.startPrank(alice);
        plainBase.approve(address(falseEngine), type(uint256).max);
        falseQuote.approve(address(falseEngine), type(uint256).max);
        bytes32 restingAsk = falseEngine.fill(_order(10, 5, 0), false);
        vm.stopPrank();

        vm.startPrank(bob);
        plainBase.approve(address(falseEngine), type(uint256).max);
        falseQuote.approve(address(falseEngine), type(uint256).max);
        falseEngine.fill(_order(10, 2, 0), true);
        vm.stopPrank();

        bytes32 askRootBefore = falseEngine.askRoot();
        uint256 engineBaseBefore = plainBase.balanceOf(address(falseEngine));
        uint256 engineQuoteBefore = falseQuote.balanceOf(address(falseEngine));
        uint256 aliceBaseBefore = plainBase.balanceOf(alice);
        uint256 aliceQuoteBefore = falseQuote.balanceOf(alice);

        assertEq(askRootBefore, _order(10, 3, MAX_ORDER_NONCE));
        assertEq(engineBaseBefore, 3);
        assertEq(engineQuoteBefore, _quoteValue(10, 5, false) - _quoteValue(10, 3, false));

        falseQuote.setFailTransfer(true);

        vm.prank(alice);
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        falseEngine.cancel(restingAsk);

        assertEq(falseEngine.askRoot(), askRootBefore);
        assertEq(falseEngine.ownerOfOrder(restingAsk), alice);
        assertFalse(falseEngine.isBidOrder(restingAsk));
        assertEq(plainBase.balanceOf(address(falseEngine)), engineBaseBefore);
        assertEq(falseQuote.balanceOf(address(falseEngine)), engineQuoteBefore);
        assertEq(plainBase.balanceOf(alice), aliceBaseBefore);
        assertEq(falseQuote.balanceOf(alice), aliceQuoteBefore);
    }

    function test_ReentrantTokenPayoutReverts() public {
        ReentrantERC20 reentrantBase = new ReentrantERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(reentrantBase), address(plainQuote));

        reentrantBase.mint(alice, 1_000);
        reentrantBase.mint(bob, 1_000);
        plainQuote.mint(alice, 1_000);
        plainQuote.mint(bob, 1_000);

        vm.startPrank(alice);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        plainQuote.approve(address(reentrantEngine), type(uint256).max);
        bytes32 restingAsk = reentrantEngine.fill(_order(10, 1, 0), false);
        vm.stopPrank();

        vm.startPrank(bob);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        plainQuote.approve(address(reentrantEngine), type(uint256).max);
        vm.stopPrank();

        reentrantBase.arm(reentrantEngine, restingAsk);

        vm.prank(bob);
        reentrantEngine.fill(_order(10, 1, 0), true);

        assertFalse(reentrantBase.reentrySucceeded());
        assertEq(reentrantBase.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantBase.balanceOf(bob), 1_001);
    }

    function test_ReentrantQuotePayoutReverts() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        ReentrantERC20 reentrantQuote = new ReentrantERC20();
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(plainBase), address(reentrantQuote));

        plainBase.mint(alice, 1_000);
        plainBase.mint(bob, 1_000);
        reentrantQuote.mint(alice, 1_000);
        reentrantQuote.mint(bob, 1_000);

        vm.startPrank(alice);
        plainBase.approve(address(reentrantEngine), type(uint256).max);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        bytes32 restingBid = reentrantEngine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        vm.startPrank(bob);
        plainBase.approve(address(reentrantEngine), type(uint256).max);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        vm.stopPrank();

        reentrantQuote.arm(reentrantEngine, restingBid);

        vm.prank(bob);
        reentrantEngine.fill(_order(10, 1, 0), false);

        assertFalse(reentrantQuote.reentrySucceeded());
        assertEq(reentrantQuote.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantQuote.balanceOf(bob), 1_000 + _quoteValue(10, 1, true));
    }

    function test_ReentrantBasePayoutCannotFill() public {
        ReentrantERC20 reentrantBase = new ReentrantERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(reentrantBase), address(plainQuote));

        reentrantBase.mint(alice, 1_000);
        reentrantBase.mint(bob, 1_000);
        plainQuote.mint(alice, 1_000);
        plainQuote.mint(bob, 1_000);

        vm.startPrank(alice);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        plainQuote.approve(address(reentrantEngine), type(uint256).max);
        reentrantEngine.fill(_order(10, 1, 0), false);
        vm.stopPrank();

        vm.startPrank(bob);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        plainQuote.approve(address(reentrantEngine), type(uint256).max);
        vm.stopPrank();

        reentrantBase.armFill(reentrantEngine, _order(11, 1, 0), false);

        vm.prank(bob);
        reentrantEngine.fill(_order(10, 1, 0), true);

        assertFalse(reentrantBase.reentrySucceeded());
        assertEq(reentrantBase.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantBase.balanceOf(bob), 1_001);
    }

    function test_ReentrantQuotePayoutCannotFill() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        ReentrantERC20 reentrantQuote = new ReentrantERC20();
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(plainBase), address(reentrantQuote));

        plainBase.mint(alice, 1_000);
        plainBase.mint(bob, 1_000);
        reentrantQuote.mint(alice, 1_000);
        reentrantQuote.mint(bob, 1_000);

        vm.startPrank(alice);
        plainBase.approve(address(reentrantEngine), type(uint256).max);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        reentrantEngine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        vm.startPrank(bob);
        plainBase.approve(address(reentrantEngine), type(uint256).max);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        vm.stopPrank();

        reentrantQuote.armFill(reentrantEngine, _order(11, 1, 0), true);

        vm.prank(bob);
        reentrantEngine.fill(_order(10, 1, 0), false);

        assertFalse(reentrantQuote.reentrySucceeded());
        assertEq(reentrantQuote.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantQuote.balanceOf(bob), 1_000 + _quoteValue(10, 1, true));
    }

    function test_ReentrantBaseCancelPayoutCannotCancelTokenOwnedAsk() public {
        ReentrantERC20 reentrantBase = new ReentrantERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(reentrantBase), address(plainQuote));

        reentrantBase.mint(alice, 1_000);
        reentrantBase.mint(address(reentrantBase), 1_000);

        vm.startPrank(alice);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        bytes32 aliceAsk = reentrantEngine.fill(_order(10, 1, 0), false);
        vm.stopPrank();

        reentrantBase.approveAsSelf(address(reentrantEngine), type(uint256).max);

        vm.prank(address(reentrantBase));
        bytes32 tokenAsk = reentrantEngine.fill(_order(11, 1, 0), false);

        reentrantBase.arm(reentrantEngine, tokenAsk);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = reentrantEngine.cancel(aliceAsk);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertFalse(reentrantBase.reentrySucceeded());
        assertEq(reentrantBase.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.ownerOfOrder(aliceAsk), address(0));
        assertEq(reentrantEngine.ownerOfOrder(tokenAsk), address(reentrantBase));
        assertEq(reentrantEngine.askRoot(), tokenAsk);

        vm.prank(address(reentrantBase));
        (baseAmount, quoteAmount) = reentrantEngine.cancel(tokenAsk);

        assertEq(baseAmount, 1);
        assertEq(quoteAmount, 0);
        assertEq(reentrantEngine.askRoot(), bytes32(0));
    }

    function test_ReentrantQuoteCancelPayoutCannotCancelTokenOwnedBid() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        ReentrantERC20 reentrantQuote = new ReentrantERC20();
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(plainBase), address(reentrantQuote));

        reentrantQuote.mint(alice, 1_000);
        reentrantQuote.mint(address(reentrantQuote), 1_000);

        vm.startPrank(alice);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        bytes32 aliceBid = reentrantEngine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        reentrantQuote.approveAsSelf(address(reentrantEngine), type(uint256).max);

        vm.prank(address(reentrantQuote));
        bytes32 tokenBid = reentrantEngine.fill(_order(11, 1, 0), true);

        reentrantQuote.arm(reentrantEngine, tokenBid);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = reentrantEngine.cancel(aliceBid);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, _quoteValue(10, 1, true));
        assertFalse(reentrantQuote.reentrySucceeded());
        assertEq(reentrantQuote.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.ownerOfOrder(aliceBid), address(0));
        assertEq(reentrantEngine.ownerOfOrder(tokenBid), address(reentrantQuote));
        assertEq(reentrantEngine.bidRoot(), tokenBid);

        vm.prank(address(reentrantQuote));
        (baseAmount, quoteAmount) = reentrantEngine.cancel(tokenBid);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, _quoteValue(11, 1, true));
        assertEq(reentrantEngine.bidRoot(), bytes32(0));
    }

    function test_ReentrantQuoteCollateralPullReverts() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        ReentrantTransferFromERC20 reentrantQuote = new ReentrantTransferFromERC20();
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(plainBase), address(reentrantQuote));

        reentrantQuote.mint(alice, 1_000);

        vm.startPrank(alice);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        bytes32 expectedBid = _order(10, 1, MAX_ORDER_NONCE);
        reentrantQuote.arm(reentrantEngine, expectedBid);
        bytes32 restingBid = reentrantEngine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        assertEq(restingBid, expectedBid);
        assertFalse(reentrantQuote.reentrySucceeded());
        assertEq(reentrantQuote.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.bidRoot(), restingBid);
        assertEq(reentrantEngine.ownerOfOrder(restingBid), alice);
        assertEq(reentrantQuote.balanceOf(address(reentrantEngine)), _quoteValue(10, 1, true));
    }

    function test_ReentrantQuoteCollateralPullCannotFill() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        ReentrantTransferFromERC20 reentrantQuote = new ReentrantTransferFromERC20();
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(plainBase), address(reentrantQuote));

        reentrantQuote.mint(alice, 1_000);

        vm.startPrank(alice);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        bytes32 expectedBid = _order(10, 1, MAX_ORDER_NONCE);
        reentrantQuote.armFill(reentrantEngine, _order(11, 1, 0), true);
        bytes32 restingBid = reentrantEngine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        assertEq(restingBid, expectedBid);
        assertFalse(reentrantQuote.reentrySucceeded());
        assertEq(reentrantQuote.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.bidRoot(), restingBid);
        assertEq(reentrantEngine.ownerOfOrder(restingBid), alice);
        assertEq(reentrantQuote.balanceOf(address(reentrantEngine)), _quoteValue(10, 1, true));
    }

    function test_ReentrantQuoteCollateralPullDuringBidPartialRestCannotCancelRemainder() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        ReentrantTransferFromERC20 reentrantQuote = new ReentrantTransferFromERC20();
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(plainBase), address(reentrantQuote));

        plainBase.mint(bob, 1_000);
        reentrantQuote.mint(alice, 1_000);

        vm.prank(bob);
        plainBase.approve(address(reentrantEngine), type(uint256).max);
        vm.prank(bob);
        bytes32 restingAsk = reentrantEngine.fill(_order(10, 1, 0), false);

        bytes32 expectedBid = _order(10, 1, MAX_ORDER_NONCE - 1);

        vm.prank(alice);
        reentrantQuote.approve(address(reentrantEngine), type(uint256).max);
        reentrantQuote.arm(reentrantEngine, expectedBid);
        vm.prank(alice);
        assertEq(reentrantEngine.fill(_order(10, 2, 0), true), expectedBid);

        assertFalse(reentrantQuote.reentrySucceeded());
        assertEq(reentrantQuote.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.askRoot(), bytes32(0));
        assertEq(reentrantEngine.bidRoot(), expectedBid);
        assertEq(reentrantEngine.ownerOfOrder(restingAsk), bob);
        assertEq(reentrantEngine.ownerOfOrder(expectedBid), alice);
        assertEq(plainBase.balanceOf(alice), 1);
        assertEq(
            reentrantQuote.balanceOf(address(reentrantEngine)), _quoteValue(10, 1, false) + _quoteValue(10, 1, true)
        );

        {
            vm.prank(bob);
            (uint256 bobBaseAmount, uint256 bobQuoteAmount) = reentrantEngine.cancel(restingAsk);
            assertEq(bobBaseAmount, 0);
            assertEq(bobQuoteAmount, _quoteValue(10, 1, false));
        }
        {
            vm.prank(alice);
            (uint256 aliceBaseAmount, uint256 aliceQuoteAmount) = reentrantEngine.cancel(expectedBid);
            assertEq(aliceBaseAmount, 0);
            assertEq(aliceQuoteAmount, _quoteValue(10, 1, true));
        }
        assertEq(reentrantEngine.bidRoot(), bytes32(0));
    }

    function test_ReentrantBaseCollateralPullReverts() public {
        ReentrantTransferFromERC20 reentrantBase = new ReentrantTransferFromERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(reentrantBase), address(plainQuote));

        reentrantBase.mint(alice, 1_000);

        vm.startPrank(alice);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        bytes32 expectedAsk = _order(10, 1, MAX_ORDER_NONCE);
        reentrantBase.arm(reentrantEngine, expectedAsk);
        bytes32 restingAsk = reentrantEngine.fill(_order(10, 1, 0), false);
        vm.stopPrank();

        assertEq(restingAsk, expectedAsk);
        assertFalse(reentrantBase.reentrySucceeded());
        assertEq(reentrantBase.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.askRoot(), restingAsk);
        assertEq(reentrantEngine.ownerOfOrder(restingAsk), alice);
        assertEq(reentrantBase.balanceOf(address(reentrantEngine)), 1);
    }

    function test_ReentrantBaseCollateralPullDuringAskPartialRestCannotCancelRemainder() public {
        ReentrantTransferFromERC20 reentrantBase = new ReentrantTransferFromERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(reentrantBase), address(plainQuote));

        plainQuote.mint(alice, 1_000);
        reentrantBase.mint(bob, 1_000);

        vm.prank(alice);
        plainQuote.approve(address(reentrantEngine), type(uint256).max);
        vm.prank(alice);
        bytes32 restingBid = reentrantEngine.fill(_order(10, 1, 0), true);

        bytes32 expectedAsk = _order(10, 1, MAX_ORDER_NONCE - 1);

        vm.prank(bob);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        reentrantBase.arm(reentrantEngine, expectedAsk);
        vm.prank(bob);
        assertEq(reentrantEngine.fill(_order(10, 2, 0), false), expectedAsk);

        assertFalse(reentrantBase.reentrySucceeded());
        assertEq(reentrantBase.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.bidRoot(), bytes32(0));
        assertEq(reentrantEngine.askRoot(), expectedAsk);
        assertEq(reentrantEngine.ownerOfOrder(restingBid), alice);
        assertEq(reentrantEngine.ownerOfOrder(expectedAsk), bob);
        assertEq(plainQuote.balanceOf(bob), _quoteValue(10, 1, true));
        assertEq(reentrantBase.balanceOf(address(reentrantEngine)), 2);

        {
            vm.prank(alice);
            (uint256 aliceBaseAmount, uint256 aliceQuoteAmount) = reentrantEngine.cancel(restingBid);
            assertEq(aliceBaseAmount, 1);
            assertEq(aliceQuoteAmount, 0);
        }
        {
            vm.prank(bob);
            (uint256 bobBaseAmount, uint256 bobQuoteAmount) = reentrantEngine.cancel(expectedAsk);
            assertEq(bobBaseAmount, 1);
            assertEq(bobQuoteAmount, 0);
        }
        assertEq(reentrantEngine.askRoot(), bytes32(0));
    }

    function test_ReentrantBaseCollateralPullCannotFill() public {
        ReentrantTransferFromERC20 reentrantBase = new ReentrantTransferFromERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine reentrantEngine = new RadixMatchingEngine(address(reentrantBase), address(plainQuote));

        reentrantBase.mint(alice, 1_000);

        vm.startPrank(alice);
        reentrantBase.approve(address(reentrantEngine), type(uint256).max);
        bytes32 expectedAsk = _order(10, 1, MAX_ORDER_NONCE);
        reentrantBase.armFill(reentrantEngine, _order(11, 1, 0), false);
        bytes32 restingAsk = reentrantEngine.fill(_order(10, 1, 0), false);
        vm.stopPrank();

        assertEq(restingAsk, expectedAsk);
        assertFalse(reentrantBase.reentrySucceeded());
        assertEq(reentrantBase.reentrySelector(), bytes4(keccak256("ReentrantCall()")));
        assertEq(reentrantEngine.askRoot(), restingAsk);
        assertEq(reentrantEngine.ownerOfOrder(restingAsk), alice);
        assertEq(reentrantBase.balanceOf(address(reentrantEngine)), 1);
    }

    function test_BidConsumesAskAndRestsRemainder() public {
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 3, 0), false);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        assertEq(base.balanceOf(alice), 1_000_003);
        assertEq(quote.balanceOf(alice), 1_000_000 - _quoteValue(90, 3, false) - _quoteValue(100, 2, true));
        assertEq(restingBid, _order(100, 2, MAX_ORDER_NONCE - 1));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.bidRoot(), restingBid);

        vm.prank(bob);
        (uint256 bobBase, uint256 bobQuote) = engine.cancel(restingAsk);

        assertEq(bobBase, 0);
        assertEq(bobQuote, _quoteValue(90, 3, false));
        assertEq(quote.balanceOf(bob), 1_000_000 + _quoteValue(90, 3, false));

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(restingBid);

        assertEq(aliceBase, 0);
        assertEq(aliceQuote, _quoteValue(100, 2, true));
        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_BidPartiallyFillsBestAsk() public {
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(80, 5, 0), false);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(base.balanceOf(alice), 1_000_002);
        assertEq(quote.balanceOf(alice), 1_000_000 - (_quoteValue(80, 5, false) - _quoteValue(80, 3, false)));
        assertEq(engine.askRoot(), _order(80, 3, MAX_ORDER_NONCE));

        vm.prank(bob);
        (uint256 bobBase, uint256 bobQuote) = engine.cancel(restingAsk);

        assertEq(bobBase, 3);
        assertEq(bobQuote, _quoteValue(80, 5, false) - _quoteValue(80, 3, false));
        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_CancelRejectsReducedLiveAskLeafKey() public {
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(80, 5, 0), false);

        vm.prank(alice);
        bytes32 crossingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(crossingBid, bytes32(0));

        bytes32 reducedAsk = _order(80, 3, _nonce(restingAsk));
        assertEq(engine.askRoot(), reducedAsk);
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        assertEq(engine.ownerOfOrder(reducedAsk), address(0));

        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(reducedAsk);

        assertEq(engine.askRoot(), reducedAsk);
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        assertEq(engine.ownerOfOrder(reducedAsk), address(0));
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);

        vm.prank(bob);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingAsk);

        assertEq(baseAmount, 3);
        assertEq(quoteAmount, _quoteValue(80, 5, false) - _quoteValue(80, 3, false));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingAsk), address(0));
    }

    function test_FullyFilledBidClaimPaysBase() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(base.balanceOf(bob), 1_000_000 - 2);
        assertEq(quote.balanceOf(bob), 1_000_000 + _quoteValue(100, 2, true));

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(restingBid);

        assertEq(aliceBase, 2);
        assertEq(aliceQuote, 0);
        assertEq(base.balanceOf(alice), 1_000_002);
        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_AskPartiallyFillsBestBid() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(quote.balanceOf(bob), 1_000_000 + (_quoteValue(100, 5, true) - _quoteValue(100, 3, true)));
        assertEq(base.balanceOf(bob), 1_000_000 - 2);
        assertEq(engine.bidRoot(), _order(100, 3, MAX_ORDER_NONCE));

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(restingBid);

        assertEq(aliceBase, 2);
        assertEq(aliceQuote, _quoteValue(100, 3, true));
        assertEq(base.balanceOf(alice), 1_000_002);
        assertEq(quote.balanceOf(alice), 1_000_000 - _quoteValue(100, 5, true) + _quoteValue(100, 3, true));
    }

    function test_CancelRejectsReducedLiveBidLeafKey() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        vm.prank(bob);
        bytes32 crossingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(crossingAsk, bytes32(0));

        bytes32 reducedBid = _order(100, 3, _nonce(restingBid));
        assertEq(engine.bidRoot(), reducedBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.ownerOfOrder(reducedBid), address(0));

        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(reducedBid);

        assertEq(engine.bidRoot(), reducedBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.ownerOfOrder(reducedBid), address(0));
        assertEq(base.balanceOf(address(engine)), engineBaseBefore);
        assertEq(quote.balanceOf(address(engine)), engineQuoteBefore);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);

        assertEq(baseAmount, 2);
        assertEq(quoteAmount, _quoteValue(100, 3, true));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingBid), address(0));
    }

    function test_SamePriceUsesEarlierNonceFirst() public {
        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(50, 1, 0), false);

        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(50, 1, 0), false);

        vm.prank(carol);
        engine.fill(_order(50, 1, 0), true);

        vm.prank(alice);
        (uint256 firstBase, uint256 firstQuote) = engine.cancel(firstAsk);

        assertEq(firstBase, 0);
        assertEq(firstQuote, _quoteValue(50, 1, false));

        vm.prank(bob);
        (uint256 secondBase, uint256 secondQuote) = engine.cancel(secondAsk);

        assertEq(secondBase, 1);
        assertEq(secondQuote, 0);
        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_SamePriceBidsUseEarlierNonceFirst() public {
        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(50, 1, 0), true);

        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(50, 1, 0), true);

        vm.prank(carol);
        engine.fill(_order(50, 1, 0), false);

        vm.prank(alice);
        (uint256 firstBase, uint256 firstQuote) = engine.cancel(firstBid);

        assertEq(firstBase, 1);
        assertEq(firstQuote, 0);

        vm.prank(bob);
        (uint256 secondBase, uint256 secondQuote) = engine.cancel(secondBid);

        assertEq(secondBase, 0);
        assertEq(secondQuote, _quoteValue(50, 1, true));
        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_ManySamePriceOrdersPreserveTimePriority() public {
        uint256 orderCount = 32;
        uint160 fillQuantity = 16;
        uint256 fillCount = fillQuantity;
        int32 price = 77;

        bytes32[] memory asks = new bytes32[](orderCount);
        address[] memory makers = new address[](orderCount);

        for (uint256 i; i < orderCount; ++i) {
            // forge-lint: disable-next-line(unsafe-typecast)
            makers[i] = address(uint160(0x1000 + i));
            _fundAndApprove(makers[i]);

            vm.prank(makers[i]);
            asks[i] = engine.fill(_order(price, 1, 0), false);

            assertEq(uint256(_nonce(asks[i])), uint256(MAX_ORDER_NONCE) - i);
            assertEq(engine.ownerOfOrder(asks[i]), makers[i]);
        }

        address taker = address(0xB1D);
        _fundAndApprove(taker);

        vm.prank(taker);
        bytes32 restingBid = engine.fill(_order(price, fillQuantity, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(base.balanceOf(taker), 1_000_000 + fillCount);
        assertEq(quote.balanceOf(taker), 1_000_000 - _quoteValue(price, 1, false) * fillCount);

        for (uint256 i; i < fillCount; ++i) {
            vm.prank(makers[i]);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(asks[i]);

            assertEq(baseAmount, 0);
            assertEq(quoteAmount, _quoteValue(price, 1, false));
            assertEq(engine.ownerOfOrder(asks[i]), address(0));
        }

        for (uint256 i = fillCount; i < orderCount; ++i) {
            vm.prank(makers[i]);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(asks[i]);

            assertEq(baseAmount, 1);
            assertEq(quoteAmount, 0);
            assertEq(engine.ownerOfOrder(asks[i]), address(0));
        }

        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_ManySamePriceBidsPreserveTimePriority() public {
        uint256 orderCount = 32;
        uint160 fillQuantity = 16;
        uint256 fillCount = fillQuantity;
        int32 price = 77;

        bytes32[] memory bids = new bytes32[](orderCount);
        address[] memory makers = new address[](orderCount);

        for (uint256 i; i < orderCount; ++i) {
            // forge-lint: disable-next-line(unsafe-typecast)
            makers[i] = address(uint160(0x2000 + i));
            _fundAndApprove(makers[i]);

            vm.prank(makers[i]);
            bids[i] = engine.fill(_order(price, 1, 0), true);

            assertEq(uint256(_nonce(bids[i])), uint256(MAX_ORDER_NONCE) - i);
            assertEq(engine.ownerOfOrder(bids[i]), makers[i]);
        }

        address taker = address(0xA5C);
        _fundAndApprove(taker);

        vm.prank(taker);
        bytes32 restingAsk = engine.fill(_order(price, fillQuantity, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(base.balanceOf(taker), 1_000_000 - fillCount);
        assertEq(quote.balanceOf(taker), 1_000_000 + _quoteValue(price, 1, true) * fillCount);

        for (uint256 i; i < fillCount; ++i) {
            vm.prank(makers[i]);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(bids[i]);

            assertEq(baseAmount, 1);
            assertEq(quoteAmount, 0);
            assertEq(engine.ownerOfOrder(bids[i]), address(0));
        }

        for (uint256 i = fillCount; i < orderCount; ++i) {
            vm.prank(makers[i]);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(bids[i]);

            assertEq(baseAmount, 0);
            assertEq(quoteAmount, _quoteValue(price, 1, true));
            assertEq(engine.ownerOfOrder(bids[i]), address(0));
        }

        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_MatchingStopsWhenNextBestPriceDoesNotCross() public {
        vm.prank(alice);
        bytes32 highBid = engine.fill(_order(100, 1, 0), true);

        vm.prank(bob);
        bytes32 lowBid = engine.fill(_order(90, 1, 0), true);

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(95, 2, 0), false);

        assertEq(quote.balanceOf(carol), 1_000_000 + _quoteValue(100, 1, true));
        assertEq(base.balanceOf(carol), 1_000_000 - 2);
        assertEq(restingAsk, _order(95, 1, MAX_ORDER_NONCE - 2));
        assertEq(engine.ownerOfOrder(highBid), alice);
        assertEq(engine.ownerOfOrder(lowBid), bob);

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(highBid);

        assertEq(aliceBase, 1);
        assertEq(aliceQuote, 0);

        vm.prank(bob);
        (uint256 bobBase, uint256 bobQuote) = engine.cancel(lowBid);

        assertEq(bobBase, 0);
        assertEq(bobQuote, _quoteValue(90, 1, true));

        vm.prank(carol);
        (uint256 carolBase, uint256 carolQuote) = engine.cancel(restingAsk);

        assertEq(carolBase, 1);
        assertEq(carolQuote, 0);
    }

    function test_BidMatchingStopsWhenNextBestAskDoesNotCross() public {
        vm.prank(alice);
        bytes32 lowAsk = engine.fill(_order(90, 1, 0), false);

        vm.prank(bob);
        bytes32 highAsk = engine.fill(_order(100, 1, 0), false);

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(95, 2, 0), true);

        assertEq(base.balanceOf(carol), 1_000_001);
        assertEq(quote.balanceOf(carol), 1_000_000 - _quoteValue(90, 1, false) - _quoteValue(95, 1, true));
        assertEq(restingBid, _order(95, 1, MAX_ORDER_NONCE - 2));
        assertEq(engine.ownerOfOrder(lowAsk), alice);
        assertEq(engine.ownerOfOrder(highAsk), bob);

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(lowAsk);

        assertEq(aliceBase, 0);
        assertEq(aliceQuote, _quoteValue(90, 1, false));

        vm.prank(bob);
        (uint256 bobBase, uint256 bobQuote) = engine.cancel(highAsk);

        assertEq(bobBase, 1);
        assertEq(bobQuote, 0);

        vm.prank(carol);
        (uint256 carolBase, uint256 carolQuote) = engine.cancel(restingBid);

        assertEq(carolBase, 0);
        assertEq(carolQuote, _quoteValue(95, 1, true));
    }

    function _fundAndApprove(address account) internal {
        base.mint(account, 1_000_000);
        quote.mint(account, 1_000_000);

        vm.startPrank(account);
        base.approve(address(engine), type(uint256).max);
        quote.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _actorFor(uint256 index) internal view returns (address) {
        uint256 actorIndex = index % 3;
        if (actorIndex == 0) return alice;
        if (actorIndex == 1) return bob;
        return carol;
    }

    function _pricePrefixCombPrice(uint256 depth) internal pure returns (int32) {
        uint32 sortableTick = type(uint32).max ^ uint32(uint256(1) << (31 - depth));
        return int32(sortableTick ^ 0x80000000);
    }

    function _askPricePrefixCombPrice(uint256 depth) internal pure returns (int32) {
        uint32 askSortTick = type(uint32).max ^ uint32(uint256(1) << (31 - depth));
        uint32 sortableTick = type(uint32).max - askSortTick;
        return int32(sortableTick ^ 0x80000000);
    }

    function _buildFullDepthBidNonceComb() internal returns (bytes32[] memory orders, uint256 quoteTotal) {
        uint256 orderCount = 65;
        uint64 targetKey = type(uint64).max;
        orders = new bytes32[](orderCount);

        quote.mint(alice, uint256(1) << 200);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        orders[0] = engine.fill(_order(type(int32).max, 1, 0), true);

        assertEq(_pathKey(orders[0]), targetKey);
        quoteTotal += _quoteValue(_price(orders[0]), 1, true);

        for (uint256 depth; depth < 64; ++depth) {
            uint64 siblingKey = targetKey ^ uint64(uint256(1) << (63 - depth));
            // forge-lint: disable-next-line(unsafe-typecast)
            int32 price = int32(uint32(siblingKey >> 32) ^ 0x80000000);
            // forge-lint: disable-next-line(unsafe-typecast)
            uint32 nonce = uint32(siblingKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            orders[depth + 1] = engine.fill(_order(price, 1, 0), true);

            assertEq(_pathKey(orders[depth + 1]), siblingKey);
            quoteTotal += _quoteValue(price, 1, true);
        }
    }

    function _buildMaxValidDepthAskNonceComb() internal returns (bytes32[] memory orders, uint256 quoteTotal) {
        uint256 orderCount = 65;
        uint64 targetSortKey = type(uint64).max;
        orders = new bytes32[](orderCount);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        vm.prank(alice);
        orders[0] = engine.fill(_order(type(int32).min, 1, 0), false);

        assertEq(_askSortKey(orders[0]), targetSortKey);
        quoteTotal += _quoteValue(_price(orders[0]), 1, false);

        for (uint256 depth; depth < 64; ++depth) {
            uint64 sortKey = targetSortKey ^ uint64(uint256(1) << (63 - depth));
            uint32 sortableTick = type(uint32).max - uint32(sortKey >> 32);
            int32 price = int32(sortableTick ^ 0x80000000);
            uint32 nonce = uint32(sortKey);

            vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(nonce)));
            vm.prank(alice);
            orders[depth + 1] = engine.fill(_order(price, 1, 0), false);

            assertEq(_askSortKey(orders[depth + 1]), sortKey);
            quoteTotal += _quoteValue(price, 1, false);
        }
    }

    function _assertBidPricePrefixCombShape() internal view {
        bytes32 node = engine.bidRoot();

        for (uint256 depth; depth < 32; ++depth) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);

            assertTrue(leftNode != bytes32(0));
            assertTrue(rightNode != bytes32(0));
            assertEq(_commonPrefix(_pathKey(leftNode), _pathKey(rightNode)), depth);

            node = rightNode;
        }

        (bytes32 leftFinal, bytes32 rightFinal) = engine.tree(node);
        assertEq(_commonPrefix(_pathKey(leftFinal), _pathKey(rightFinal)), 63);
        assertEq(int256(_price(leftFinal)), int256(type(int32).max));
        assertEq(int256(_price(rightFinal)), int256(type(int32).max));
    }

    function _assertAskPricePrefixCombShape() internal view {
        bytes32 node = engine.askRoot();

        for (uint256 depth; depth < 32; ++depth) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);

            assertTrue(leftNode != bytes32(0));
            assertTrue(rightNode != bytes32(0));
            assertEq(_commonPrefix(_askSortKey(leftNode), _askSortKey(rightNode)), depth);

            node = rightNode;
        }

        (bytes32 leftFinal, bytes32 rightFinal) = engine.tree(node);
        assertEq(_commonPrefix(_askSortKey(leftFinal), _askSortKey(rightFinal)), 63);
        assertEq(int256(_price(leftFinal)), int256(type(int32).min));
        assertEq(int256(_price(rightFinal)), int256(type(int32).min));
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }

    function _bookId() internal view returns (bytes32) {
        return engine.bookId(address(base), address(quote), 0);
    }

    function _ownerOfOrderSlot(bytes32 order) internal view returns (bytes32) {
        return keccak256(abi.encode(keccak256(abi.encode(_bookId(), order)), uint256(1)));
    }

    function _orderStateSlotValue(address owner, bool isBid) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(owner)) | (isBid ? uint256(1) << 160 : 0));
    }

    function _bookSlot() internal view returns (bytes32) {
        return keccak256(abi.encode(_bookId(), uint256(0)));
    }

    function _treeMappingSlot() internal view returns (bytes32) {
        return bytes32(uint256(_bookSlot()) + 1);
    }

    function _treeSlot(bytes32 node) internal view returns (bytes32) {
        return keccak256(abi.encode(node, _treeMappingSlot()));
    }

    function _assertTreeBranchStorage(bytes32 branch, bytes32 leftNode, bytes32 rightNode, string memory label)
        internal
        view
    {
        bytes32 branchSlot = _treeSlot(branch);
        assertEq(vm.load(address(engine), branchSlot), leftNode, string.concat(label, " tree left slot"));
        assertEq(
            vm.load(address(engine), bytes32(uint256(branchSlot) + 1)),
            rightNode,
            string.concat(label, " tree right slot")
        );
    }

    function _storeTreeBranch(bytes32 branch, bytes32 leftNode, bytes32 rightNode) internal {
        bytes32 branchSlot = _treeSlot(branch);
        vm.store(address(engine), branchSlot, leftNode);
        vm.store(address(engine), bytes32(uint256(branchSlot) + 1), rightNode);
    }

    function _expectedBranchChildren(bytes32 a, bytes32 b, bool isBid)
        internal
        pure
        returns (bytes32 left, bytes32 right)
    {
        uint64 aKey = isBid ? _pathKey(a) : _askSortKey(a);
        uint64 bKey = isBid ? _pathKey(b) : _askSortKey(b);
        uint8 branchDepth = _commonPrefix(aKey, bKey);

        left = a;
        right = b;
        if (_bit(aKey, branchDepth)) {
            left = b;
            right = a;
        }
    }

    function _bidRootSlot() internal view returns (bytes32) {
        return bytes32(uint256(_treeSlot(bytes32(0))) + 1);
    }

    function _askRootSlot() internal view returns (bytes32) {
        return _treeSlot(bytes32(0));
    }

    function _nextNonceSlot() internal view returns (bytes32) {
        return _bookSlot();
    }

    function _branchFor(bytes32 a, bytes32 b, bool isBid) internal view returns (bytes32 branch) {
        uint64 aKey = _pathKey(a);
        uint64 bKey = _pathKey(b);
        uint64 boundaryKey = aKey > bKey ? aKey : bKey;

        int32 prefixPrice = int32(uint32(boundaryKey >> 32) ^ 0x80000000);
        uint32 prefixNonce = uint32(boundaryKey);
        uint160 quantity = _quantity(a) + _quantity(b);
        branch = _order(prefixPrice, quantity, prefixNonce);

        if (_price(a) == _price(b) && _uniformNode(a) && _uniformNode(b)) {
            uint256 childQuote = _uniformQuote(a, isBid) + _uniformQuote(b, isBid);
            uint256 aggregateQuote = _quoteValue(_price(a), quantity, isBid);
            uint256 correction = isBid ? childQuote - aggregateQuote : aggregateQuote - childQuote;
            branch = bytes32(uint256(branch) | ((correction + 1) << 32));
        }
    }

    function _uniformNode(bytes32 node) internal view returns (bool) {
        (bytes32 leftNode,) = engine.tree(node);
        return leftNode == bytes32(0) || _correctionCode(node) != 0;
    }

    function _uniformQuote(bytes32 node, bool isBid) internal view returns (uint256 quoteAmount) {
        quoteAmount = _quoteValue(_price(node), _quantity(node), isBid);
        (bytes32 leftNode,) = engine.tree(node);
        if (leftNode == bytes32(0)) return quoteAmount;
        uint256 correction = uint256(_correctionCode(node)) - 1;
        return isBid ? quoteAmount + correction : quoteAmount - correction;
    }

    function _expectAskMatches(bytes32 first, bytes32 second) internal {
        bytes32[] memory nodes = new bytes32[](2);
        nodes[0] = first;
        nodes[1] = second;
        vm.expectEmit(false, false, false, true, address(engine));
        emit AsksMatched(_bookId(), nodes);
    }

    function _expectAskMatches(bytes32 first, bytes32 second, bytes32 third) internal {
        bytes32[] memory nodes = new bytes32[](3);
        nodes[0] = first;
        nodes[1] = second;
        nodes[2] = third;
        vm.expectEmit(false, false, false, true, address(engine));
        emit AsksMatched(_bookId(), nodes);
    }

    function _expectBidMatches(bytes32 first, bytes32 second) internal {
        bytes32[] memory nodes = new bytes32[](2);
        nodes[0] = first;
        nodes[1] = second;
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidsMatched(_bookId(), nodes);
    }

    function _expectBidMatches(bytes32 first, bytes32 second, bytes32 third) internal {
        bytes32[] memory nodes = new bytes32[](3);
        nodes[0] = first;
        nodes[1] = second;
        nodes[2] = third;
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidsMatched(_bookId(), nodes);
    }

    function _matchEventNode(bytes32 node, uint160 quantity, uint256 quoteAmount, bool isBid)
        internal
        pure
        returns (bytes32)
    {
        uint256 baseline = _quoteValue(_price(node), quantity, isBid);
        uint256 correctionCode;
        if (isBid) {
            correctionCode = quoteAmount >= baseline ? quoteAmount - baseline + 1 : 0;
        } else {
            correctionCode = baseline >= quoteAmount ? baseline - quoteAmount + 1 : 0;
        }
        require(correctionCode <= type(uint32).max, "event correction overflow");

        uint256 quantityMask = ((uint256(1) << 160) - 1) << 64;
        uint256 correctionMask = uint256(type(uint32).max) << 32;
        return bytes32(
            (uint256(node) & ~(quantityMask | correctionMask)) | (uint256(quantity) << 64) | (correctionCode << 32)
        );
    }

    function _rightmostLeaf(bytes32 node) internal view returns (bytes32 leaf) {
        while (true) {
            (, bytes32 rightNode) = engine.tree(node);
            if (rightNode == bytes32(0)) return node;
            node = rightNode;
        }
    }

    function _subtreeQuantity(bytes32 node) internal view returns (uint160) {
        if (node == bytes32(0)) return 0;

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        if (leftNode == bytes32(0)) return _quantity(node);

        return _subtreeQuantity(leftNode) + _subtreeQuantity(rightNode);
    }

    function _pathKey(bytes32 order) internal pure returns (uint64) {
        return (uint64(uint32(_price(order)) ^ 0x80000000) << 32) | uint64(_nonce(order));
    }

    function _askSortKey(bytes32 order) internal pure returns (uint64) {
        uint32 sortableTick = uint32(_price(order)) ^ 0x80000000;
        return (uint64(type(uint32).max - sortableTick) << 32) | uint64(_nonce(order));
    }

    function _commonPrefix(uint64 a, uint64 b) internal pure returns (uint8 prefixLength) {
        for (; prefixLength < 64; ++prefixLength) {
            if (_bit(a, prefixLength) != _bit(b, prefixLength)) return prefixLength;
        }
    }

    function _bit(uint64 key, uint8 depth) internal pure returns (bool) {
        return ((key >> (63 - depth)) & 1) == 1;
    }

    function _price(bytes32 order) internal pure returns (int32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return int32(uint32(uint256(order) >> 224));
    }

    function _quantity(bytes32 order) internal pure returns (uint160) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160((uint256(order) >> 64) & ((uint256(1) << 160) - 1));
    }

    function _nonce(bytes32 order) internal pure returns (uint32) {
        return uint32(uint256(order));
    }

    function _correctionCode(bytes32 node) internal pure returns (uint32) {
        return uint32(uint256(node) >> 32);
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) internal pure returns (uint256) {
        return QuoteMath.quoteValue(tick, quantity, roundUp);
    }
}
