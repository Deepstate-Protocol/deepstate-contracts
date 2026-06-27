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

contract RadixMatchingEngineTest is Test {
    uint40 internal constant MAX_ORDER_NONCE = (uint40(1) << 38) - 1;
    uint40 internal constant SIDE_NONCE_FLAG = uint40(1) << 38;
    uint40 internal constant BID_BRANCH_NONCE_FLAG = uint40(1) << 39;
    uint40 internal constant ASK_BRANCH_NONCE_FLAG = BID_BRANCH_NONCE_FLAG | SIDE_NONCE_FLAG;

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
    }

    function test_InternalNodesUseReservedNonceTags() public {
        vm.prank(alice);
        bytes32 firstBid = engine.fill(_order(100, 1, 0), true);

        assertEq(_nonce(firstBid), MAX_ORDER_NONCE);
        assertEq(engine.nextNonce(), MAX_ORDER_NONCE - 1);

        vm.prank(bob);
        bytes32 secondBid = engine.fill(_order(99, 1, 0), true);

        bytes32 root = engine.bidRoot();
        assertEq(_nonce(secondBid), MAX_ORDER_NONCE - 1);
        assertEq(_nonce(root) & BID_BRANCH_NONCE_FLAG, BID_BRANCH_NONCE_FLAG);
        assertEq(_nonce(root) & SIDE_NONCE_FLAG, 0);
        assertEq(engine.ownerOfOrder(root), address(0));
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
        assertEq(_nonce(bidRoot) & BID_BRANCH_NONCE_FLAG, BID_BRANCH_NONCE_FLAG);
        assertEq(_nonce(bidRoot) & SIDE_NONCE_FLAG, 0);
        assertEq(_nonce(askRoot) & ASK_BRANCH_NONCE_FLAG, ASK_BRANCH_NONCE_FLAG);
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

    function _nonce(bytes32 order) internal pure returns (uint40) {
        return uint40(uint256(order));
    }
}
