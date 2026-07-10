// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SinglePairEngineHarness} from "./SinglePairEngineHarness.sol";
import {QuoteMath} from "./QuoteMath.sol";

contract CoverageERC20 is ERC20 {
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

contract CoverageHook {
    uint256 public calls;
    bytes32 public lastPoolId;
    bytes32 public lastBookId;
    address public lastToken;
    uint160 public lastOutgoingAmount;
    uint32 public lastIncomingNonce;

    function execute(bytes32 poolId, bytes32 bookId, address token, uint160 outgoingAmount, uint32 incomingNonce)
        external
    {
        calls++;
        lastPoolId = poolId;
        lastBookId = bookId;
        lastToken = token;
        lastOutgoingAmount = outgoingAmount;
        lastIncomingNonce = incomingNonce;
    }
}

contract CoverageEngineHarness is SinglePairEngineHarness {
    constructor(address baseToken, address quoteToken) SinglePairEngineHarness(baseToken, quoteToken) {}

    function guardedForCoverage() external nonReentrant {}

    function reenterGuardedForCoverage() external nonReentrant {
        this.guardedForCoverage();
    }

    function initializeBookForCoverage(bytes32 id) external {
        _initializeBook(books[id]);
    }

    function takeTopOrderChangeForCoverage() external returns (uint160 outgoingAmount, uint32 incomingNonce) {
        return _takeTopOrderChange();
    }
}

contract RadixMatchingEngineCoverageTest is Test {
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;
    uint256 internal constant BID_RIGHT_SPINE_DIRTY = uint256(1) << 32;
    uint256 internal constant ASK_RIGHT_SPINE_DIRTY = uint256(1) << 33;

    event AskMatched(bytes32 bookId, bytes32 restingNode);
    event BidMatched(bytes32 bookId, bytes32 restingNode);

    CoverageERC20 internal base;
    CoverageERC20 internal quote;
    CoverageEngineHarness internal engine;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA701);

    function setUp() public {
        base = new CoverageERC20("Base", "BASE");
        quote = new CoverageERC20("Quote", "QUOTE");
        engine = new CoverageEngineHarness(address(base), address(quote));

        _fundAndApprove(alice);
        _fundAndApprove(bob);
        _fundAndApprove(carol);
    }

    function testCoverage_CancelRevertBranches() public {
        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("InvalidBook()")));
        engine.cancel(_order(100, 1, 1));

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(restingBid);

        bytes32 corruptedLeaf = _order(100, 3, _nonce(restingBid));
        vm.store(address(engine), _bidRootSlot(), corruptedLeaf);

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.cancel(restingBid);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NotOrderOwner()")));
        engine.cancel(_order(100, 1, 1));

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.cancel(_order(100, 0, 1));

        bytes32 zeroQuantityOwned = _order(100, 0, 2);
        vm.store(address(engine), _ownerOfOrderSlot(zeroQuantityOwned), _orderStateSlotValue(alice, true));

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.cancel(zeroQuantityOwned);
    }

    function testCoverage_InvalidOrdersAndDuplicateCorruption() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(bytes32(uint256(_order(0, 1, 0)) | (uint256(1) << 32)), true);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(_order(1, 0, 0), true);
        vm.expectRevert(bytes4(keccak256("InvalidOrder()")));
        engine.fill(_order(1, 1, 1), true);
        vm.stopPrank();

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(10, 1, 0), true);
        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("DuplicateOrder()")));
        engine.fill(_order(10, 1, 0), true);

        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
    }

    function testCoverage_InternalHarnessEntrypoints() public {
        bytes32 id = _bookId();
        bytes32 order = _order(7, 11, 13);

        engine.initializeBookForCoverage(id);
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE);
        engine.initializeBookForCoverage(id);
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE);
        assertEq(engine.orderId(id, order), keccak256(abi.encode(id, order)));

        (uint160 outgoingAmount, uint32 incomingNonce) = engine.takeTopOrderChangeForCoverage();
        assertEq(outgoingAmount, 0);
        assertEq(incomingNonce, 0);

        engine.guardedForCoverage();
        vm.expectRevert(bytes4(keccak256("ReentrantCall()")));
        engine.reenterGuardedForCoverage();
    }

    function testCoverage_HookEnabledTopChangesAcrossBidAndAskBooks() public {
        CoverageHook hook = new CoverageHook();
        engine.setPoolHookConfig(address(base), address(quote), address(hook), true, true);

        bytes32 id = _bookId();
        bytes32 pid = engine.poolId(address(base), address(quote));

        vm.prank(alice);
        bytes32 lowerBid = engine.fill(_order(100, 1, 0), true);
        assertEq(hook.calls(), 1);
        assertEq(hook.lastPoolId(), pid);
        assertEq(hook.lastBookId(), id);
        assertEq(hook.lastToken(), address(base));
        assertEq(hook.lastOutgoingAmount(), 0);
        assertEq(hook.lastIncomingNonce(), _nonce(lowerBid));

        vm.prank(bob);
        bytes32 topBid = engine.fill(_order(110, 1, 0), true);
        assertEq(hook.calls(), 2);
        assertEq(hook.lastOutgoingAmount(), 1);
        assertEq(hook.lastIncomingNonce(), _nonce(topBid));

        vm.prank(carol);
        engine.fill(_order(100, 1, 0), false);
        assertEq(hook.calls(), 3);
        assertEq(hook.lastToken(), address(base));
        assertEq(hook.lastOutgoingAmount(), 1);
        assertEq(hook.lastIncomingNonce(), _nonce(lowerBid));

        vm.prank(alice);
        bytes32 worseAsk = engine.fill(_order(120, 1, 0), false);
        assertEq(hook.calls(), 4);
        assertEq(hook.lastToken(), address(quote));
        assertEq(hook.lastOutgoingAmount(), 0);
        assertEq(hook.lastIncomingNonce(), _nonce(worseAsk));

        vm.prank(bob);
        bytes32 topAsk = engine.fill(_order(110, 1, 0), false);
        assertEq(hook.calls(), 5);
        assertEq(hook.lastOutgoingAmount(), 1);
        assertEq(hook.lastIncomingNonce(), _nonce(topAsk));

        vm.prank(carol);
        engine.fill(_order(110, 1, 0), true);
        assertEq(hook.calls(), 6);
        assertEq(hook.lastToken(), address(quote));
        assertEq(hook.lastOutgoingAmount(), 1);
        assertEq(hook.lastIncomingNonce(), _nonce(worseAsk));
    }

    function testCoverage_CancelNonTopBidAndAskBranches() public {
        vm.prank(alice);
        bytes32 topBid = engine.fill(_order(100, 1, 0), true);
        vm.prank(bob);
        bytes32 lowerBid = engine.fill(_order(90, 1, 0), true);

        vm.prank(bob);
        (uint256 lowerBidBase, uint256 lowerBidQuote) = engine.cancel(lowerBid);

        assertEq(lowerBidBase, 0);
        assertEq(lowerBidQuote, _quoteValue(90, 1, true));
        assertEq(engine.bidRoot(), topBid);

        vm.prank(alice);
        bytes32 topAsk = engine.fill(_order(50, 1, 0), false);
        vm.prank(bob);
        bytes32 higherAsk = engine.fill(_order(60, 1, 0), false);

        vm.prank(bob);
        (uint256 higherAskBase, uint256 higherAskQuote) = engine.cancel(higherAsk);

        assertEq(higherAskBase, 1);
        assertEq(higherAskQuote, 0);
        assertEq(engine.askRoot(), topAsk);
    }

    function testCoverage_CancelAskLeftLeafAndAbsentDivergentOrders() public {
        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(50, 1, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(60, 1, 0), false);

        (bytes32 leftAsk,) = engine.tree(engine.askRoot());
        if (leftAsk == firstAsk) {
            vm.prank(alice);
            engine.cancel(firstAsk);
        } else {
            assertEq(leftAsk, secondAsk);
            vm.prank(bob);
            engine.cancel(secondAsk);
        }

        vm.prank(alice);
        engine.fill(_order(100, 1, 0), true);
        vm.prank(bob);
        engine.fill(_order(101, 1, 0), true);

        bytes32 absentBid = _order(type(int32).max, 1, MAX_ORDER_NONCE - 20);
        assertLt(
            _commonPrefix(_bidSortKey(absentBid), _bidSortKey(engine.bidRoot())),
            _commonPrefix(_bidSortKey(_branchLeft(engine.bidRoot())), _bidSortKey(_branchRight(engine.bidRoot())))
        );
        vm.store(address(engine), _ownerOfOrderSlot(absentBid), _orderStateSlotValue(carol, true));
        base.mint(address(engine), 1);

        vm.prank(carol);
        engine.cancel(absentBid);

        vm.prank(alice);
        engine.fill(_order(40, 1, 0), false);
        vm.prank(bob);
        engine.fill(_order(41, 1, 0), false);

        bytes32 absentAsk = _order(type(int32).max, 1, MAX_ORDER_NONCE - 21);
        assertLt(
            _commonPrefix(_askSortKey(absentAsk), _askSortKey(engine.askRoot())),
            _commonPrefix(_askSortKey(_branchLeft(engine.askRoot())), _askSortKey(_branchRight(engine.askRoot())))
        );
        vm.store(address(engine), _ownerOfOrderSlot(absentAsk), _orderStateSlotValue(carol, false));
        quote.mint(address(engine), _quoteValue(type(int32).max, 1, false));

        vm.prank(carol);
        engine.cancel(absentAsk);
    }

    function testCoverage_OwnedAbsentOrdersSearchBranchesBeforeClaiming() public {
        vm.prank(alice);
        engine.fill(_order(100, 1, 0), true);
        vm.prank(bob);
        engine.fill(_order(90, 1, 0), true);

        bytes32 absentBid = _order(110, 1, MAX_ORDER_NONCE - 9);
        vm.store(address(engine), _ownerOfOrderSlot(absentBid), _orderStateSlotValue(carol, true));

        vm.prank(carol);
        vm.expectRevert();
        engine.cancel(absentBid);

        vm.prank(alice);
        engine.fill(_order(50, 1, 0), false);
        vm.prank(bob);
        engine.fill(_order(60, 1, 0), false);

        bytes32 absentAsk = _order(55, 1, MAX_ORDER_NONCE - 10);
        vm.store(address(engine), _ownerOfOrderSlot(absentAsk), _orderStateSlotValue(carol, false));

        vm.prank(carol);
        vm.expectRevert();
        engine.cancel(absentAsk);
    }

    function testCoverage_AskSubtreeAggregateAndRecursivePaths() public {
        address dave = address(0xD00D);
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 lowerAsk = engine.fill(_order(20, 2, 0), false);
        vm.prank(bob);
        bytes32 higherAsk = engine.fill(_order(21, 3, 0), false);
        vm.prank(dave);
        bytes32 bestAsk = engine.fill(_order(10, 1, 0), false);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(bestAsk, 1, _quoteValue(10, 1, false), false));
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(lowerAsk, 2, _quoteValue(20, 2, false), false));
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(
            _bookId(), _matchEventNode(higherAsk, 1, _quoteValue(21, 3, false) - _quoteValue(21, 2, false), false)
        );

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(21, 4, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(engine.askRoot(), _order(21, 2, _nonce(higherAsk)));

        vm.prank(alice);
        engine.cancel(lowerAsk);
        vm.prank(bob);
        engine.cancel(higherAsk);
        vm.prank(dave);
        engine.cancel(bestAsk);
    }

    function testCoverage_BidSubtreeAggregateAndRecursivePaths() public {
        address dave = address(0xD00D);
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 higherBid = engine.fill(_order(70, 2, 0), true);
        vm.prank(bob);
        bytes32 lowerBid = engine.fill(_order(69, 3, 0), true);
        vm.prank(dave);
        bytes32 bestBid = engine.fill(_order(80, 1, 0), true);

        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(bestBid, 1, _quoteValue(80, 1, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(higherBid, 2, _quoteValue(70, 2, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(
            _bookId(), _matchEventNode(lowerBid, 1, _quoteValue(69, 3, true) - _quoteValue(69, 2, true), true)
        );

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(69, 4, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(engine.bidRoot(), _order(69, 2, _nonce(lowerBid)));

        vm.prank(alice);
        engine.cancel(higherBid);
        vm.prank(bob);
        engine.cancel(lowerBid);
        vm.prank(dave);
        engine.cancel(bestBid);
    }

    function testCoverage_ExactSamePriceOffSpineAggregateAskAndBid() public {
        address dave = address(0xD00D);
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(20, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(20, 3, 0), false);
        vm.prank(dave);
        bytes32 bestAsk = engine.fill(_order(10, 1, 0), false);

        bytes32 askAggregate = _branchFor(firstAsk, secondAsk, false);
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(bestAsk, 1, _quoteValue(10, 1, false), false));
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(
            _bookId(), _matchEventNode(askAggregate, 5, _quoteValue(20, 2, false) + _quoteValue(20, 3, false), false)
        );

        vm.prank(carol);
        engine.fill(_order(20, 6, 0), true);

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(70, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(70, 3, 0), true);
        vm.prank(dave);
        bytes32 bestBid = engine.fill(_order(80, 1, 0), true);

        bytes32 bidAggregate = _branchFor(firstBid, secondBid, true);
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(bestBid, 1, _quoteValue(80, 1, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(
            _bookId(), _matchEventNode(bidAggregate, 5, _quoteValue(70, 2, true) + _quoteValue(70, 3, true), true)
        );

        vm.prank(carol);
        engine.fill(_order(70, 6, 0), false);
    }

    function testCoverage_ExactMixedPriceOffSpineAggregateAskAndBid() public {
        address dave = address(0xD00D);
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 lowerAsk = engine.fill(_order(20, 2, 0), false);
        vm.prank(bob);
        bytes32 higherAsk = engine.fill(_order(21, 3, 0), false);
        vm.prank(dave);
        bytes32 bestAsk = engine.fill(_order(10, 1, 0), false);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(bestAsk, 1, _quoteValue(10, 1, false), false));
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(lowerAsk, 2, _quoteValue(20, 2, false), false));
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(higherAsk, 3, _quoteValue(21, 3, false), false));

        vm.prank(carol);
        engine.fill(_order(21, 6, 0), true);

        vm.prank(alice);
        bytes32 higherBid = engine.fill(_order(70, 2, 0), true);
        vm.prank(bob);
        bytes32 lowerBid = engine.fill(_order(69, 3, 0), true);
        vm.prank(dave);
        bytes32 bestBid = engine.fill(_order(80, 1, 0), true);

        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(bestBid, 1, _quoteValue(80, 1, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(higherBid, 2, _quoteValue(70, 2, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(lowerBid, 3, _quoteValue(69, 3, true), true));

        vm.prank(carol);
        engine.fill(_order(69, 6, 0), false);
    }

    function testCoverage_StopsInsideOffSpineSubtrees() public {
        address dave = address(0xD00D);
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 lowerAsk = engine.fill(_order(30, 2, 0), false);
        vm.prank(bob);
        bytes32 higherAsk = engine.fill(_order(31, 3, 0), false);
        vm.prank(dave);
        bytes32 bestAsk = engine.fill(_order(10, 1, 0), false);

        vm.prank(carol);
        bytes32 restingBid = engine.fill(_order(20, 4, 0), true);

        assertEq(restingBid, _order(20, 3, MAX_ORDER_NONCE - 3));
        assertEq(engine.askRoot(), _branchFor(lowerAsk, higherAsk, false));

        assertTrue(bestAsk != bytes32(0));
    }

    function testCoverage_StopsInsideOffSpineBidSubtree() public {
        address dave = address(0xD00D);
        _fundAndApprove(dave);

        vm.prank(alice);
        bytes32 higherBid = engine.fill(_order(60, 2, 0), true);
        vm.prank(bob);
        bytes32 lowerBid = engine.fill(_order(59, 3, 0), true);
        vm.prank(dave);
        bytes32 bestBid = engine.fill(_order(80, 1, 0), true);

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(70, 4, 0), false);

        assertEq(restingAsk, _order(70, 3, MAX_ORDER_NONCE - 3));
        assertEq(engine.bidRoot(), _branchFor(higherBid, lowerBid, true));
        assertTrue(bestBid != bytes32(0));
    }

    function testCoverage_DirtyRightSpinesMaterializeOnSameSideInsert() public {
        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(60, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(60, 3, 0), false);
        bytes32 askAnchor = _branchFor(firstAsk, secondAsk, false);

        vm.prank(carol);
        engine.fill(_order(60, 1, 0), true);

        assertEq(engine.askRoot(), askAnchor);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 2) | ASK_RIGHT_SPINE_DIRTY
        );

        vm.prank(carol);
        bytes32 thirdAsk = engine.fill(_order(61, 1, 0), false);

        assertTrue(thirdAsk != bytes32(0));
        assertEq(uint256(vm.load(address(engine), _nextNonceSlot())), uint256(MAX_ORDER_NONCE) - 3);
        assertEq(_subtreeQuantity(engine.askRoot()), 5);
    }

    function testCoverage_DirtyBidRightSpineMaterializesOnBidInsert() public {
        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(80, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(80, 3, 0), true);
        bytes32 bidAnchor = _branchFor(firstBid, secondBid, true);

        vm.prank(carol);
        engine.fill(_order(80, 1, 0), false);

        assertEq(engine.bidRoot(), bidAnchor);
        assertEq(
            uint256(vm.load(address(engine), _nextNonceSlot())), (uint256(MAX_ORDER_NONCE) - 2) | BID_RIGHT_SPINE_DIRTY
        );

        vm.prank(carol);
        bytes32 thirdBid = engine.fill(_order(79, 1, 0), true);

        assertTrue(thirdBid != bytes32(0));
        assertEq(uint256(vm.load(address(engine), _nextNonceSlot())), uint256(MAX_ORDER_NONCE) - 3);
        assertEq(_subtreeQuantity(engine.bidRoot()), 5);
    }

    function testCoverage_DirtyMixedPriceRightSpinesUseRecursiveRouting() public {
        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(60, 2, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(61, 3, 0), false);

        vm.prank(carol);
        engine.fill(_order(60, 1, 0), true);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(
            _bookId(), _matchEventNode(_order(60, 1, _nonce(firstAsk)), 1, _quoteValue(60, 1, false), false)
        );
        vm.expectEmit(false, false, false, true, address(engine));
        emit AskMatched(_bookId(), _matchEventNode(secondAsk, 3, _quoteValue(61, 3, false), false));

        vm.prank(carol);
        engine.fill(_order(61, 4, 0), true);

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(80, 2, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(79, 3, 0), true);

        vm.prank(carol);
        engine.fill(_order(80, 1, 0), false);

        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(_order(80, 1, _nonce(firstBid)), 1, _quoteValue(80, 1, true), true));
        vm.expectEmit(false, false, false, true, address(engine));
        emit BidMatched(_bookId(), _matchEventNode(secondBid, 3, _quoteValue(79, 3, true), true));

        vm.prank(carol);
        engine.fill(_order(79, 4, 0), false);
    }

    function testCoverage_CorruptedAliasRightSpineRecomputesBranch() public {
        int32 price = 50;
        bytes32 leftAsk = _order(price, 2, MAX_ORDER_NONCE - 1);
        bytes32 rightAsk = _order(price, 5, MAX_ORDER_NONCE);
        bytes32 root = _order(price, 4, MAX_ORDER_NONCE);

        vm.store(address(engine), _nextNonceSlot(), bytes32(uint256(MAX_ORDER_NONCE)));
        _storeTreeBranch(root, leftAsk, rightAsk);
        vm.store(address(engine), _askRootSlot(), root);
        base.mint(address(engine), 1);

        vm.prank(carol);
        engine.fill(_order(price, 1, 0), true);

        bytes32 expectedRoot = _branchFor(leftAsk, root, false);
        assertEq(engine.askRoot(), expectedRoot);
        _assertTreeBranchStorage(expectedRoot, leftAsk, root);
    }

    function _fundAndApprove(address account) internal {
        base.mint(account, 1_000_000_000);
        quote.mint(account, 1_000_000_000);

        vm.startPrank(account);
        base.approve(address(engine), type(uint256).max);
        quote.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _bookId() internal view returns (bytes32) {
        return engine.bookId(address(base), address(quote), 0);
    }

    function _bookSlot() internal view returns (bytes32) {
        return keccak256(abi.encode(_bookId(), uint256(0)));
    }

    function _ownerOfOrderSlot(bytes32 order) internal view returns (bytes32) {
        return keccak256(abi.encode(keccak256(abi.encode(_bookId(), order)), uint256(1)));
    }

    function _orderStateSlotValue(address owner, bool isBid) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(owner)) | (isBid ? uint256(1) << 160 : 0));
    }

    function _treeMappingSlot() internal view returns (bytes32) {
        return bytes32(uint256(_bookSlot()) + 1);
    }

    function _treeSlot(bytes32 node) internal view returns (bytes32) {
        return keccak256(abi.encode(node, _treeMappingSlot()));
    }

    function _askRootSlot() internal view returns (bytes32) {
        return _treeSlot(bytes32(0));
    }

    function _bidRootSlot() internal view returns (bytes32) {
        return bytes32(uint256(_treeSlot(bytes32(0))) + 1);
    }

    function _nextNonceSlot() internal view returns (bytes32) {
        return _bookSlot();
    }

    function _storeTreeBranch(bytes32 branch, bytes32 leftNode, bytes32 rightNode) internal {
        bytes32 branchSlot = _treeSlot(branch);
        vm.store(address(engine), branchSlot, leftNode);
        vm.store(address(engine), bytes32(uint256(branchSlot) + 1), rightNode);
    }

    function _assertTreeBranchStorage(bytes32 branch, bytes32 leftNode, bytes32 rightNode) internal view {
        bytes32 branchSlot = _treeSlot(branch);
        assertEq(vm.load(address(engine), branchSlot), leftNode);
        assertEq(vm.load(address(engine), bytes32(uint256(branchSlot) + 1)), rightNode);
    }

    function _branchLeft(bytes32 branch) internal view returns (bytes32 leftNode) {
        (leftNode,) = engine.tree(branch);
    }

    function _branchRight(bytes32 branch) internal view returns (bytes32 rightNode) {
        (, rightNode) = engine.tree(branch);
    }

    function _branchFor(bytes32 a, bytes32 b, bool isBid) internal view returns (bytes32) {
        uint64 aKey = _pathKey(a);
        uint64 bKey = _pathKey(b);
        uint64 boundaryKey = aKey > bKey ? aKey : bKey;

        // forge-lint: disable-next-line(unsafe-typecast)
        int32 prefixPrice = int32(uint32(boundaryKey >> 32) ^ 0x80000000);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 prefixNonce = uint32(boundaryKey);
        uint160 quantity = _quantity(a) + _quantity(b);
        uint32 correctionCode;
        if (_price(a) == _price(b) && _uniformNode(a) && _uniformNode(b)) {
            uint256 childQuote = _uniformQuote(a, isBid) + _uniformQuote(b, isBid);
            uint256 aggregateQuote = _quoteValue(_price(a), quantity, isBid);
            uint256 correction = isBid ? childQuote - aggregateQuote : aggregateQuote - childQuote;
            correctionCode = uint32(correction + 1);
        }
        return bytes32(
            (uint256(uint32(prefixPrice)) << 224) | (uint256(quantity) << 64) | (uint256(correctionCode) << 32)
                | uint256(prefixNonce)
        );
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

    function _subtreeQuantity(bytes32 node) internal view returns (uint160) {
        if (node == bytes32(0)) return 0;

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        if (leftNode == bytes32(0)) return _quantity(node);

        return _subtreeQuantity(leftNode) + _subtreeQuantity(rightNode);
    }

    function _pathKey(bytes32 order) internal pure returns (uint64) {
        return (uint64(uint32(_price(order)) ^ 0x80000000) << 32) | uint64(_nonce(order));
    }

    function _bidSortKey(bytes32 order) internal pure returns (uint64) {
        return _pathKey(order);
    }

    function _askSortKey(bytes32 order) internal pure returns (uint64) {
        unchecked {
            uint32 tickKey = uint32(_price(order)) ^ 0x80000000;
            return (uint64(type(uint32).max - tickKey) << 32) | uint64(_nonce(order));
        }
    }

    function _commonPrefix(uint64 a, uint64 b) internal pure returns (uint8) {
        for (uint8 i; i < 64;) {
            if (_bit(a, i) != _bit(b, i)) return i;
            unchecked {
                ++i;
            }
        }
        return 64;
    }

    function _bit(uint64 key, uint8 depth) internal pure returns (bool) {
        return key & (uint64(1) << (63 - depth)) != 0;
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
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

    function _correctionCode(bytes32 order) internal pure returns (uint32) {
        return uint32(uint256(order) >> 32);
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) internal pure returns (uint256 quoteAmount) {
        quoteAmount = QuoteMath.quoteValue(tick, quantity, roundUp);
    }
}
