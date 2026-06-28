// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {RadixMatchingEngine} from "../src/RadixMatchingEngine.sol";

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

contract FeeERC20 is TestERC20 {
    constructor() TestERC20("Fee", "FEE") {}

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        super.transferFrom(from, to, amount);
        _burn(to, 1);
        return true;
    }
}

contract FeeTransferERC20 is TestERC20 {
    constructor() TestERC20("FeeTransfer", "FEEOUT") {}

    function transfer(address to, uint256 amount) public override returns (bool) {
        super.transfer(to, amount);
        _burn(to, 1);
        return true;
    }
}

contract ReentrantERC20 is TestERC20 {
    RadixMatchingEngine internal target;
    bytes32 internal targetOrder;
    bool internal armed;
    bool public reentrySucceeded;
    bytes4 public reentrySelector;

    constructor() TestERC20("Reentrant", "REENTRANT") {}

    function arm(RadixMatchingEngine target_, bytes32 targetOrder_) external {
        target = target_;
        targetOrder = targetOrder_;
        armed = true;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (armed) {
            armed = false;
            bytes memory data;
            (reentrySucceeded, data) = address(target).call(abi.encodeCall(RadixMatchingEngine.cancel, (targetOrder)));
            // forge-lint: disable-next-line(unsafe-typecast)
            if (data.length >= 4) reentrySelector = bytes4(data);
        }
        return super.transfer(to, amount);
    }
}

contract ReentrantTransferFromERC20 is TestERC20 {
    RadixMatchingEngine internal target;
    bytes32 internal targetOrder;
    bool internal armed;
    bool public reentrySucceeded;
    bytes4 public reentrySelector;

    constructor() TestERC20("ReentrantTransferFrom", "REENTRANT_FROM") {}

    function arm(RadixMatchingEngine target_, bytes32 targetOrder_) external {
        target = target_;
        targetOrder = targetOrder_;
        armed = true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (armed) {
            armed = false;
            bytes memory data;
            (reentrySucceeded, data) = address(target).call(abi.encodeCall(RadixMatchingEngine.cancel, (targetOrder)));
            // forge-lint: disable-next-line(unsafe-typecast)
            if (data.length >= 4) reentrySelector = bytes4(data);
        }
        return super.transferFrom(from, to, amount);
    }
}

contract RadixMatchingEngineTest is Test {
    uint40 internal constant MAX_ORDER_NONCE = type(uint40).max;

    TestERC20 internal base;
    TestERC20 internal quote;
    RadixMatchingEngine internal engine;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);

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

        vm.prank(alice);
        bytes32 restingBid = engine.fill(bid, true);

        assertEq(restingBid, _order(100, 5, MAX_ORDER_NONCE));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(quote.balanceOf(address(engine)), 500);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingBid);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, 500);
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.ownerOfOrder(restingBid), address(0));
        assertEq(quote.balanceOf(alice), 1_000_000);
    }

    function test_ConstructorRejectsInvalidTokens() public {
        vm.expectRevert(RadixMatchingEngine.InvalidToken.selector);
        new RadixMatchingEngine(address(0), address(quote));

        vm.expectRevert(RadixMatchingEngine.InvalidToken.selector);
        new RadixMatchingEngine(address(base), address(0));

        vm.expectRevert(RadixMatchingEngine.InvalidToken.selector);
        new RadixMatchingEngine(address(base), address(base));

        vm.expectRevert(RadixMatchingEngine.InvalidToken.selector);
        new RadixMatchingEngine(alice, address(quote));

        vm.expectRevert(RadixMatchingEngine.InvalidToken.selector);
        new RadixMatchingEngine(address(base), bob);
    }

    function test_InvalidOrdersRevert() public {
        vm.startPrank(alice);

        vm.expectRevert(RadixMatchingEngine.InvalidOrder.selector);
        engine.fill(_order(0, 1, 0), true);

        vm.expectRevert(RadixMatchingEngine.InvalidOrder.selector);
        engine.fill(_order(1, 0, 0), true);

        vm.expectRevert(RadixMatchingEngine.InvalidOrder.selector);
        engine.fill(_order(1, 1, 1), true);

        vm.stopPrank();
    }

    function test_OnlyOwnerCanCancel() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        vm.expectRevert(RadixMatchingEngine.NotOrderOwner.selector);
        engine.cancel(restingBid);

        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.bidRoot(), restingBid);
        assertEq(quote.balanceOf(address(engine)), 200);
    }

    function test_FilledOrderClaimCanOnlyHappenOnce() public {
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        vm.prank(alice);
        engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(restingAsk);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, 180);
        assertEq(engine.ownerOfOrder(restingAsk), address(0));

        vm.prank(bob);
        vm.expectRevert(RadixMatchingEngine.NotOrderOwner.selector);
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

    function test_NonceExhaustionRevertsWithoutMutatingBook() public {
        bytes32 nextNonceSlot = bytes32(uint256(4));
        vm.store(address(engine), nextNonceSlot, bytes32(uint256(1)));

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(10, 1, 0), true);

        assertEq(restingBid, _order(10, 1, 1));
        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.nextNonce(), 0);

        vm.prank(bob);
        vm.expectRevert(RadixMatchingEngine.NonceExhausted.selector);
        engine.fill(_order(11, 1, 0), true);

        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.nextNonce(), 0);
        assertEq(quote.balanceOf(address(engine)), 10);
    }

    function test_MaxPriceAndQuantityBidCancels() public {
        uint24 price = type(uint24).max;
        uint192 quantity = type(uint192).max;
        uint256 quoteAmount = uint256(price) * uint256(quantity);

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

    function test_BranchQuantityOverflowRevertsWithoutMutatingBook() public {
        quote.mint(alice, type(uint216).max);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(1, type(uint192).max, 0), true);

        bytes32 overflowingBid = _order(2, 1, MAX_ORDER_NONCE - 1);

        vm.prank(bob);
        vm.expectRevert();
        engine.fill(_order(2, 1, 0), true);

        assertEq(engine.bidRoot(), restingBid);
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.ownerOfOrder(overflowingBid), address(0));
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE - 1);
        assertEq(quote.balanceOf(address(engine)), type(uint192).max);
    }

    function test_SideMetadataUsesZeroQuantityNamespace() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 5, 0), true);

        bytes32 bidSideKey = _order(100, 0, _nonce(restingBid));
        assertEq(engine.ownerOfOrder(restingBid), alice);
        assertEq(engine.ownerOfOrder(bidSideKey), address(1));

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(101, 7, 0), false);

        bytes32 askSideKey = _order(101, 0, _nonce(restingAsk));
        assertEq(engine.ownerOfOrder(restingAsk), bob);
        assertEq(engine.ownerOfOrder(askSideKey), address(2));

        vm.prank(alice);
        engine.cancel(restingBid);
        vm.prank(bob);
        engine.cancel(restingAsk);

        assertEq(engine.ownerOfOrder(bidSideKey), address(0));
        assertEq(engine.ownerOfOrder(askSideKey), address(0));
    }

    function test_BidAndAskBranchesCoexistInSingleMapping() public {
        vm.prank(alice);
        engine.fill(_order(100, 1, 0), true);
        vm.prank(bob);
        engine.fill(_order(99, 1, 0), true);

        uint24 maxPrice = type(uint24).max;
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
        uint24[40] memory prices = [
            uint24(549),
            uint24(308),
            uint24(394),
            uint24(742),
            uint24(69),
            uint24(591),
            uint24(261),
            uint24(806),
            uint24(179),
            uint24(494),
            uint24(247),
            uint24(605),
            uint24(906),
            uint24(801),
            uint24(69),
            uint24(626),
            uint24(781),
            uint24(992),
            uint24(666),
            uint24(731),
            uint24(256),
            uint24(716),
            uint24(853),
            uint24(822),
            uint24(339),
            uint24(658),
            uint24(10),
            uint24(746),
            uint24(244),
            uint24(938),
            uint24(216),
            uint24(77),
            uint24(417),
            uint24(851),
            uint24(990),
            uint24(166),
            uint24(573),
            uint24(717),
            uint24(634),
            uint24(179)
        ];

        bytes32[] memory orders = new bytes32[](prices.length);
        uint256 quoteSpent;

        for (uint256 i; i < prices.length; ++i) {
            vm.prank(alice);
            orders[i] = engine.fill(_order(prices[i], 1, 0), true);

            assertEq(engine.ownerOfOrder(orders[i]), alice);
            quoteSpent += prices[i];
        }

        assertEq(quote.balanceOf(address(engine)), quoteSpent);

        for (uint256 i; i < orders.length; ++i) {
            vm.prank(alice);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(orders[i]);

            assertEq(baseAmount, 0);
            assertEq(quoteAmount, prices[i]);
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
        assertEq(quoteAmount, 68);
    }

    function test_SamePriceBranchSplitsAtFinalNonceBit() public {
        uint24 price = 321;

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

        bytes32 finalSplit = _branchFor(firstBid, secondBid);
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(finalSplit);

        assertEq(_pathKey(finalSplit), _pathKey(firstBid));
        assertEq(_quantity(finalSplit), _quantity(firstBid) + _quantity(secondBid));
        assertEq(leftNode, secondBid);
        assertEq(rightNode, firstBid);
    }

    function test_InsertPreservesChildBranchWhenItReusesParentAddress() public {
        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(108, 77, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(14, 19, 0), true);

        bytes32 oldRoot = _branchFor(firstBid, secondBid);
        assertEq(engine.bidRoot(), oldRoot);

        vm.prank(carol);
        bytes32 thirdBid = engine.fill(_order(80, 19, 0), true);

        bytes32 reusedChild = _branchFor(firstBid, thirdBid);
        bytes32 newRoot = _branchFor(secondBid, reusedChild);

        assertEq(reusedChild, oldRoot);
        assertEq(engine.bidRoot(), newRoot);

        (bytes32 rootLeft, bytes32 rootRight) = engine.tree(newRoot);
        assertEq(rootLeft, secondBid);
        assertEq(rootRight, reusedChild);

        (bytes32 childLeft, bytes32 childRight) = engine.tree(reusedChild);
        assertEq(childLeft, thirdBid);
        assertEq(childRight, firstBid);
    }

    function test_CancelDeletesCollapsedBranchStorage() public {
        uint24 price = 222;

        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(price, 1, 0), true);
        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(price, 1, 0), true);

        bytes32 branch = _branchFor(firstBid, secondBid);
        assertEq(engine.bidRoot(), branch);

        vm.prank(bob);
        engine.cancel(secondBid);

        assertEq(engine.bidRoot(), firstBid);
        _assertEmptyBranch(branch);
    }

    function test_MatchDeletesCollapsedBranchStorage() public {
        uint24 price = 333;

        vm.prank(alice);
        bytes32 firstAsk = engine.fill(_order(price, 1, 0), false);
        vm.prank(bob);
        bytes32 secondAsk = engine.fill(_order(price, 1, 0), false);

        bytes32 branch = _branchFor(firstAsk, secondAsk);
        assertEq(engine.askRoot(), branch);

        vm.prank(carol);
        engine.fill(_order(price, 1, 0), true);

        assertEq(engine.askRoot(), secondAsk);
        _assertEmptyBranch(branch);
    }

    function test_FeeOnTransferTokenReverts() public {
        FeeERC20 feeBase = new FeeERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine feeEngine = new RadixMatchingEngine(address(feeBase), address(plainQuote));

        feeBase.mint(alice, 1_000);
        plainQuote.mint(alice, 1_000);

        vm.startPrank(alice);
        feeBase.approve(address(feeEngine), type(uint256).max);
        plainQuote.approve(address(feeEngine), type(uint256).max);
        vm.expectRevert(RadixMatchingEngine.InexactTokenTransfer.selector);
        feeEngine.fill(_order(10, 2, 0), false);
        vm.stopPrank();

        bytes32 expectedAsk = _order(10, 2, MAX_ORDER_NONCE);
        assertEq(feeEngine.askRoot(), bytes32(0));
        assertEq(feeEngine.ownerOfOrder(expectedAsk), address(0));
        assertEq(feeEngine.nextNonce(), MAX_ORDER_NONCE);
        assertEq(feeBase.balanceOf(address(feeEngine)), 0);
    }

    function test_FeeOnTransferQuoteTokenReverts() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FeeERC20 feeQuote = new FeeERC20();
        RadixMatchingEngine feeEngine = new RadixMatchingEngine(address(plainBase), address(feeQuote));

        plainBase.mint(alice, 1_000);
        feeQuote.mint(alice, 1_000);

        vm.startPrank(alice);
        plainBase.approve(address(feeEngine), type(uint256).max);
        feeQuote.approve(address(feeEngine), type(uint256).max);
        vm.expectRevert(RadixMatchingEngine.InexactTokenTransfer.selector);
        feeEngine.fill(_order(10, 2, 0), true);
        vm.stopPrank();

        bytes32 expectedBid = _order(10, 2, MAX_ORDER_NONCE);
        assertEq(feeEngine.bidRoot(), bytes32(0));
        assertEq(feeEngine.ownerOfOrder(expectedBid), address(0));
        assertEq(feeEngine.nextNonce(), MAX_ORDER_NONCE);
        assertEq(feeQuote.balanceOf(address(feeEngine)), 0);
    }

    function test_FeeOnBasePayoutRevertsAndPreservesBook() public {
        FeeTransferERC20 feeBase = new FeeTransferERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine feeEngine = new RadixMatchingEngine(address(feeBase), address(plainQuote));

        feeBase.mint(bob, 1_000);
        plainQuote.mint(alice, 1_000);

        vm.startPrank(bob);
        feeBase.approve(address(feeEngine), type(uint256).max);
        bytes32 restingAsk = feeEngine.fill(_order(10, 2, 0), false);
        vm.stopPrank();

        vm.startPrank(alice);
        plainQuote.approve(address(feeEngine), type(uint256).max);
        vm.expectRevert(RadixMatchingEngine.InexactTokenTransfer.selector);
        feeEngine.fill(_order(10, 1, 0), true);
        vm.stopPrank();

        assertEq(feeEngine.askRoot(), restingAsk);
        assertEq(feeEngine.ownerOfOrder(restingAsk), bob);
        assertEq(feeBase.balanceOf(alice), 0);
        assertEq(plainQuote.balanceOf(address(feeEngine)), 0);
    }

    function test_FeeOnQuotePayoutRevertsAndPreservesBook() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FeeTransferERC20 feeQuote = new FeeTransferERC20();
        RadixMatchingEngine feeEngine = new RadixMatchingEngine(address(plainBase), address(feeQuote));

        feeQuote.mint(alice, 1_000);
        plainBase.mint(bob, 1_000);

        vm.startPrank(alice);
        feeQuote.approve(address(feeEngine), type(uint256).max);
        bytes32 restingBid = feeEngine.fill(_order(10, 2, 0), true);
        vm.stopPrank();

        vm.startPrank(bob);
        plainBase.approve(address(feeEngine), type(uint256).max);
        vm.expectRevert(RadixMatchingEngine.InexactTokenTransfer.selector);
        feeEngine.fill(_order(10, 1, 0), false);
        vm.stopPrank();

        assertEq(feeEngine.bidRoot(), restingBid);
        assertEq(feeEngine.ownerOfOrder(restingBid), alice);
        assertEq(plainBase.balanceOf(address(feeEngine)), 0);
        assertEq(feeQuote.balanceOf(bob), 0);
    }

    function test_FeeOnBaseCancelPayoutRevertsAndPreservesBook() public {
        FeeTransferERC20 feeBase = new FeeTransferERC20();
        TestERC20 plainQuote = new TestERC20("Plain", "PLAIN");
        RadixMatchingEngine feeEngine = new RadixMatchingEngine(address(feeBase), address(plainQuote));

        feeBase.mint(alice, 1_000);

        vm.startPrank(alice);
        feeBase.approve(address(feeEngine), type(uint256).max);
        bytes32 restingAsk = feeEngine.fill(_order(10, 2, 0), false);

        vm.expectRevert(RadixMatchingEngine.InexactTokenTransfer.selector);
        feeEngine.cancel(restingAsk);
        vm.stopPrank();

        assertEq(feeEngine.askRoot(), restingAsk);
        assertEq(feeEngine.ownerOfOrder(restingAsk), alice);
        assertEq(feeBase.balanceOf(address(feeEngine)), 2);
        assertEq(feeBase.balanceOf(alice), 998);
    }

    function test_FeeOnQuoteCancelPayoutRevertsAndPreservesBook() public {
        TestERC20 plainBase = new TestERC20("Plain", "PLAIN");
        FeeTransferERC20 feeQuote = new FeeTransferERC20();
        RadixMatchingEngine feeEngine = new RadixMatchingEngine(address(plainBase), address(feeQuote));

        feeQuote.mint(alice, 1_000);

        vm.startPrank(alice);
        feeQuote.approve(address(feeEngine), type(uint256).max);
        bytes32 restingBid = feeEngine.fill(_order(10, 2, 0), true);

        vm.expectRevert(RadixMatchingEngine.InexactTokenTransfer.selector);
        feeEngine.cancel(restingBid);
        vm.stopPrank();

        assertEq(feeEngine.bidRoot(), restingBid);
        assertEq(feeEngine.ownerOfOrder(restingBid), alice);
        assertEq(feeQuote.balanceOf(address(feeEngine)), 20);
        assertEq(feeQuote.balanceOf(alice), 980);
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
        assertEq(reentrantBase.reentrySelector(), RadixMatchingEngine.ReentrantCall.selector);
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
        assertEq(reentrantQuote.reentrySelector(), RadixMatchingEngine.ReentrantCall.selector);
        assertEq(reentrantQuote.balanceOf(bob), 1_010);
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
        assertEq(reentrantQuote.reentrySelector(), RadixMatchingEngine.ReentrantCall.selector);
        assertEq(reentrantEngine.bidRoot(), restingBid);
        assertEq(reentrantEngine.ownerOfOrder(restingBid), alice);
        assertEq(reentrantQuote.balanceOf(address(reentrantEngine)), 10);
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
        assertEq(reentrantBase.reentrySelector(), RadixMatchingEngine.ReentrantCall.selector);
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
        assertEq(quote.balanceOf(alice), 1_000_000 - 270 - 200);
        assertEq(restingBid, _order(100, 2, MAX_ORDER_NONCE - 1));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.bidRoot(), restingBid);

        vm.prank(bob);
        (uint256 bobBase, uint256 bobQuote) = engine.cancel(restingAsk);

        assertEq(bobBase, 0);
        assertEq(bobQuote, 270);
        assertEq(quote.balanceOf(bob), 1_000_270);

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(restingBid);

        assertEq(aliceBase, 0);
        assertEq(aliceQuote, 200);
        assertEq(engine.bidRoot(), bytes32(0));
    }

    function test_BidPartiallyFillsBestAsk() public {
        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(80, 5, 0), false);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        assertEq(restingBid, bytes32(0));
        assertEq(base.balanceOf(alice), 1_000_002);
        assertEq(quote.balanceOf(alice), 1_000_000 - 160);
        assertEq(engine.askRoot(), _order(80, 3, MAX_ORDER_NONCE));

        vm.prank(bob);
        (uint256 bobBase, uint256 bobQuote) = engine.cancel(restingAsk);

        assertEq(bobBase, 3);
        assertEq(bobQuote, 160);
        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_FullyFilledBidClaimPaysBase() public {
        vm.prank(alice);
        bytes32 restingBid = engine.fill(_order(100, 2, 0), true);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_order(90, 2, 0), false);

        assertEq(restingAsk, bytes32(0));
        assertEq(base.balanceOf(bob), 1_000_000 - 2);
        assertEq(quote.balanceOf(bob), 1_000_200);

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
        assertEq(quote.balanceOf(bob), 1_000_200);
        assertEq(base.balanceOf(bob), 1_000_000 - 2);
        assertEq(engine.bidRoot(), _order(100, 3, MAX_ORDER_NONCE));

        vm.prank(alice);
        (uint256 aliceBase, uint256 aliceQuote) = engine.cancel(restingBid);

        assertEq(aliceBase, 2);
        assertEq(aliceQuote, 300);
        assertEq(base.balanceOf(alice), 1_000_002);
        assertEq(quote.balanceOf(alice), 1_000_000 - 500 + 300);
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
        assertEq(firstQuote, 50);

        vm.prank(bob);
        (uint256 secondBase, uint256 secondQuote) = engine.cancel(secondAsk);

        assertEq(secondBase, 1);
        assertEq(secondQuote, 0);
        assertEq(engine.askRoot(), bytes32(0));
    }

    function test_ManySamePriceOrdersPreserveTimePriority() public {
        uint256 orderCount = 32;
        uint192 fillQuantity = 16;
        uint256 fillCount = fillQuantity;
        uint24 price = 77;

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
        assertEq(quote.balanceOf(taker), 1_000_000 - price * fillCount);

        for (uint256 i; i < fillCount; ++i) {
            vm.prank(makers[i]);
            (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(asks[i]);

            assertEq(baseAmount, 0);
            assertEq(quoteAmount, price);
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

    function test_MatchingStopsWhenNextBestPriceDoesNotCross() public {
        vm.prank(alice);
        bytes32 highBid = engine.fill(_order(100, 1, 0), true);

        vm.prank(bob);
        bytes32 lowBid = engine.fill(_order(90, 1, 0), true);

        vm.prank(carol);
        bytes32 restingAsk = engine.fill(_order(95, 2, 0), false);

        assertEq(quote.balanceOf(carol), 1_000_100);
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
        assertEq(bobQuote, 90);

        vm.prank(carol);
        (uint256 carolBase, uint256 carolQuote) = engine.cancel(restingAsk);

        assertEq(carolBase, 1);
        assertEq(carolQuote, 0);
    }

    function _fundAndApprove(address account) internal {
        base.mint(account, 1_000_000);
        quote.mint(account, 1_000_000);

        vm.startPrank(account);
        base.approve(address(engine), type(uint256).max);
        quote.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _order(uint24 price, uint192 quantity, uint40 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(price) << 232) | (uint256(quantity) << 40) | uint256(nonce));
    }

    function _branchFor(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        uint64 aKey = _pathKey(a);
        uint64 bKey = _pathKey(b);
        uint64 boundaryKey = aKey > bKey ? aKey : bKey;

        // forge-lint: disable-next-line(unsafe-typecast)
        uint24 prefixPrice = uint24(boundaryKey >> 40);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 prefixNonce = uint40(boundaryKey);
        return _order(prefixPrice, _quantity(a) + _quantity(b), prefixNonce);
    }

    function _pathKey(bytes32 order) internal pure returns (uint64) {
        return (uint64(_price(order)) << 40) | uint64(_nonce(order));
    }

    function _commonPrefix(uint64 a, uint64 b) internal pure returns (uint8 prefixLength) {
        for (; prefixLength < 64; ++prefixLength) {
            if (_bit(a, prefixLength) != _bit(b, prefixLength)) return prefixLength;
        }
    }

    function _bit(uint64 key, uint8 depth) internal pure returns (bool) {
        return ((key >> (63 - depth)) & 1) == 1;
    }

    function _assertEmptyBranch(bytes32 branch) internal view {
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(branch);
        assertEq(leftNode, bytes32(0));
        assertEq(rightNode, bytes32(0));
    }

    function _price(bytes32 order) internal pure returns (uint24) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(order) >> 232);
    }

    function _quantity(bytes32 order) internal pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192((uint256(order) >> 40) & ((uint256(1) << 192) - 1));
    }

    function _nonce(bytes32 order) internal pure returns (uint40) {
        return uint40(uint256(order));
    }
}
