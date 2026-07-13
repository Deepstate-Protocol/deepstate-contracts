// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";
import {QuoteMath} from "./QuoteMath.sol";

contract RoutingTestERC20 is ERC20 {
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

contract GasBurningHook {
    function execute(bytes32, bytes32, address, uint160, uint32) external pure {
        assembly ("memory-safe") {
            for {} 1 {} {}
        }
    }
}

contract DeepstateV1Harness is DeepstateV1 {
    function setNonceAndFlags(bytes32 id, uint256 nonceAndFlags) external {
        books[id].nonceAndFlags = nonceAndFlags;
    }

    function restBookForTest(
        bytes32 id,
        uint256 nonceAndFlags,
        int32 price,
        uint160 quantity,
        bool isBid,
        address owner
    ) external returns (bytes32 restingOrder, uint32 nextNonceAfter) {
        return _restBook(id, books[id], nonceAndFlags, price, quantity, isBid, owner, false);
    }
}

contract DeepstateV1Test is Test {
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;

    DeepstateV1Harness internal engine;
    RoutingTestERC20 internal token0;
    RoutingTestERC20 internal token1;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal feeRecipient = address(0xFEE);

    function setUp() public {
        RoutingTestERC20 a = new RoutingTestERC20("A", "A");
        RoutingTestERC20 b = new RoutingTestERC20("B", "B");
        if (address(a) < address(b)) {
            token0 = a;
            token1 = b;
        } else {
            token0 = b;
            token1 = a;
        }

        engine = new DeepstateV1Harness();

        _fundAndApprove(alice);
        _fundAndApprove(bob);
    }

    function test_FirstRestInitializesActiveBook() public {
        bytes32 bid = _order(10, 5, 0);

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, bid, true, false, false));

        bytes32 id = engine.bookId(address(token0), address(token1), 0);
        assertEq(engine.activeBookId(address(token0), address(token1)), id);
        assertEq(resting, _order(10, 5, MAX_ORDER_NONCE));
        assertEq(engine.nextNonce(address(token0), address(token1), 0), MAX_ORDER_NONCE - 1);
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 0);
        bytes32 orderId = engine.orderId(id, resting);
        assertEq(engine.ownerOfOrder(orderId), alice);
        assertTrue(engine.isBidOrder(orderId));
        assertEq(token1.balanceOf(address(engine)), _quoteValue(10, 5, true));
    }

    function test_InvalidTokenAndHookConfigBranches() public {
        vm.expectRevert(bytes4(keccak256("InvalidToken()")));
        engine.activeBookId(address(token1), address(token0));

        vm.expectRevert(bytes4(keccak256("InvalidToken()")));
        engine.nextNonce(address(0), address(token1), 0);

        vm.expectRevert(bytes4(keccak256("InvalidToken()")));
        engine.setPoolHookConfig(address(token1), address(token0), address(this), true, false);

        vm.expectRevert(bytes4(keccak256("InvalidHook()")));
        engine.setPoolHookConfig(address(token0), address(token1), address(0), true, false);

        engine.setPoolHookConfig(address(token0), address(token1), address(0), false, false);
        assertEq(engine.poolHook(engine.poolId(address(token0), address(token1))), address(0));
    }

    function test_FeeConfigValidationAndGetter() public {
        vm.expectRevert(bytes4(keccak256("InvalidFeeConfig()")));
        engine.setFeeConfig(feeRecipient, 101);

        vm.expectRevert(bytes4(keccak256("InvalidFeeConfig()")));
        engine.setFeeConfig(address(0), 1);

        engine.setFeeConfig(feeRecipient, 100);
        (address recipient, uint16 bps) = engine.feeConfig();
        assertEq(recipient, feeRecipient);
        assertEq(bps, 100);

        engine.setFeeConfig(address(0), 0);
        (recipient, bps) = engine.feeConfig();
        assertEq(recipient, address(0));
        assertEq(bps, 0);
    }

    function test_OnlyOwnerCanConfigureAndOwnershipTransferTakesEffect() public {
        assertEq(engine.owner(), address(this));

        vm.startPrank(alice);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setFeeConfig(feeRecipient, 1);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setPoolHookConfig(address(token0), address(token1), address(this), true, false);
        vm.stopPrank();

        engine.transferOwnership(bob);
        assertEq(engine.owner(), bob);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setFeeConfig(feeRecipient, 1);

        vm.prank(bob);
        engine.setFeeConfig(feeRecipient, 1);
        (address recipient, uint16 bps) = engine.feeConfig();
        assertEq(recipient, feeRecipient);
        assertEq(bps, 1);
    }

    function test_BidFillTakesFeeFromOutgoingBaseOnly() public {
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        bytes32 ask = engine.fill(_fill(0, _order(10, 10_000, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        vm.prank(bob);
        engine.fill(_fill(0, _order(10, 10_000, 0), true, true, false));

        uint256 matchedQuote = _quoteValue(10, 10_000, false);
        assertEq(token0.balanceOf(bob), bobToken0Before + 9_900);
        assertEq(token1.balanceOf(bob), bobToken1Before - matchedQuote);
        assertEq(token0.balanceOf(feeRecipient), 100);
        assertEq(token1.balanceOf(feeRecipient), 0);

        vm.prank(alice);
        (, uint256 quoteAmount) = engine.cancel(address(token0), address(token1), 0, ask);
        assertEq(quoteAmount, matchedQuote);
        assertEq(token0.balanceOf(feeRecipient), 100);
        assertEq(token1.balanceOf(feeRecipient), 0);
    }

    function test_FeeRecipientWithZeroBpsDoesNotTakeFee() public {
        engine.setFeeConfig(feeRecipient, 0);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 10_000, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        vm.prank(bob);
        engine.fill(_fill(0, _order(10, 10_000, 0), true, true, false));

        assertEq(token0.balanceOf(bob), bobToken0Before + 10_000);
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, 10_000, false));
        assertEq(token0.balanceOf(feeRecipient), 0);
    }

    function test_AskFillTakesFeeFromOutgoingQuoteOnly() public {
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        bytes32 bid = engine.fill(_fill(0, _order(10, 10_000, 0), true, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        vm.prank(bob);
        engine.fill(_fill(0, _order(10, 10_000, 0), false, true, false));

        uint256 matchedQuote = _quoteValue(10, 10_000, true);
        uint256 fee = matchedQuote * 100 / 10_000;
        assertEq(token0.balanceOf(bob), bobToken0Before - 10_000);
        assertEq(token1.balanceOf(bob), bobToken1Before + matchedQuote - fee);
        assertEq(token0.balanceOf(feeRecipient), 0);
        assertEq(token1.balanceOf(feeRecipient), fee);

        vm.prank(alice);
        (uint256 baseAmount,) = engine.cancel(address(token0), address(token1), 0, bid);
        assertEq(baseAmount, 10_000);
        assertEq(token0.balanceOf(feeRecipient), 0);
        assertEq(token1.balanceOf(feeRecipient), fee);
    }

    function test_MaxSignedAskOutputFeeDoesNotOverflow() public {
        engine.setFeeConfig(feeRecipient, 100);

        uint160 quantity = uint160(uint256(1) << 154);
        uint256 matchedQuote = _quoteValue(type(int32).max, quantity, true);
        assertGt(matchedQuote, type(uint256).max / 100);
        assertLe(matchedQuote, uint256(type(int256).max));

        token1.mint(alice, matchedQuote);
        vm.prank(alice);
        engine.fill(_fill(0, _order(type(int32).max, quantity, 0), true, false, false));

        token0.mint(bob, quantity);
        uint256 bobQuoteBefore = token1.balanceOf(bob);
        vm.prank(bob);
        engine.fill(_fill(0, _order(type(int32).max, quantity, 0), false, true, false));

        uint256 fee = matchedQuote / 100;
        assertEq(token1.balanceOf(bob), bobQuoteBefore + matchedQuote - fee);
        assertEq(token1.balanceOf(feeRecipient), fee);
    }

    function test_GasBurningHookCannotBlockFill() public {
        GasBurningHook hook = new GasBurningHook();
        engine.setPoolHookConfig(address(token0), address(token1), address(hook), true, false);

        vm.prank(alice);
        bytes32 restingBid = engine.fill{gas: 600_000}(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 id = engine.bookId(address(token0), address(token1), 0);
        assertEq(engine.ownerOfOrder(engine.orderId(id, restingBid)), alice);
        assertEq(engine.nextNonce(address(token0), address(token1), 0), MAX_ORDER_NONCE - 1);
    }

    function test_FillRouteFeeIsCarvedBeforeRemainderCanRestAndCancel() public {
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 10_000, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(0, _order(10, 10_000, 0), true, true, false);
        route[1] = _fill(0, _order(20, 5_000, 0), false, false, false);

        vm.prank(bob);
        engine.fillRoute(route);

        bytes32 restingAsk = _order(20, 5_000, MAX_ORDER_NONCE - 1);
        assertEq(token0.balanceOf(bob), bobToken0Before + 4_900);
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, 10_000, false));
        assertEq(token0.balanceOf(feeRecipient), 100);
        assertEq(
            engine.ownerOfOrder(engine.orderId(engine.bookId(address(token0), address(token1), 0), restingAsk)), bob
        );

        vm.prank(bob);
        (uint256 baseAmount,) = engine.cancel(address(token0), address(token1), 0, restingAsk);

        assertEq(baseAmount, 5_000);
        assertEq(token0.balanceOf(bob), bobToken0Before + 9_900);
        assertEq(token0.balanceOf(feeRecipient), 100);
    }

    function test_OldEpochMatchRemainderRestsInActiveEpoch() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 pid = engine.poolId(address(token0), address(token1));
        assertEq(engine.poolEpoch(pid), 1);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_fill(0, _order(10, 7, 0), false, false, false));

        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);
        assertEq(restingAsk, _order(10, 2, MAX_ORDER_NONCE));
        assertEq(engine.ownerOfOrder(engine.orderId(newBook, restingAsk)), bob);
        assertEq(engine.ownerOfOrder(engine.orderId(oldBook, restingAsk)), address(0));
    }

    function test_FillRouteMatchesOldEpochAndNetsTransfers() public {
        vm.prank(alice);
        bytes32 ask = engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](1);
        route[0] = _fill(0, _order(10, 3, 0), true, true, false);

        vm.prank(bob);
        engine.fillRoute(route);

        assertEq(token0.balanceOf(bob), bobToken0Before + 3);
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, 5, false) + _quoteValue(10, 2, false));

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(token0), address(token1), 0, ask);
        assertEq(baseAmount, 2);
        assertEq(quoteAmount, _quoteValue(10, 5, false) - _quoteValue(10, 2, false));
    }

    function test_FillRouteNetsRepeatedTouchedTokens() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(0, _order(10, 2, 0), true, true, false);
        route[1] = _fill(0, _order(10, 3, 0), true, true, false);

        vm.prank(bob);
        engine.fillRoute(route);

        assertEq(token0.balanceOf(bob), bobToken0Before + 5);
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, 5, false));
    }

    function test_FillRouteAccumulatesRepeatedFeesForOneToken() public {
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 20_000, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(0, _order(10, 10_000, 0), true, true, false);
        route[1] = _fill(0, _order(10, 10_000, 0), true, true, false);

        vm.prank(bob);
        engine.fillRoute(route);

        assertEq(token0.balanceOf(bob), bobToken0Before + 19_800);
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, 20_000, false));
        assertEq(token0.balanceOf(feeRecipient), 200);
        assertEq(token1.balanceOf(feeRecipient), 0);
    }

    function test_LateRouteFailureRevertsEarlierLegAtomically() public {
        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        bytes32 id = engine.bookId(address(token0), address(token1), 0);
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);
        uint256 engineToken0Before = token0.balanceOf(address(engine));
        uint256 engineToken1Before = token1.balanceOf(address(engine));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(0, _order(10, 3, 0), true, true, false);
        route[1] = _fill(0, _order(10, 3, 0), true, true, true);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("FillOrKill()")));
        engine.fillRoute(route);

        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertEq(askRoot, restingAsk);
        assertEq(engine.ownerOfOrder(engine.orderId(id, restingAsk)), alice);
        assertEq(token0.balanceOf(bob), bobToken0Before);
        assertEq(token1.balanceOf(bob), bobToken1Before);
        assertEq(token0.balanceOf(address(engine)), engineToken0Before);
        assertEq(token1.balanceOf(address(engine)), engineToken1Before);
    }

    function test_FillRouteCrossesPoolsAndNetsIntermediateToken() public {
        RoutingTestERC20 a = new RoutingTestERC20("Route A", "RA");
        RoutingTestERC20 b = new RoutingTestERC20("Route B", "RB");
        RoutingTestERC20 c = new RoutingTestERC20("Route C", "RC");
        RoutingTestERC20[3] memory sorted = _sortTokens(a, b, c);
        address makerAb = address(0xAB01);
        address makerBc = address(0xBC01);
        address taker = address(0xC0FFEE);
        uint160 quantity = 100_000;

        sorted[1].mint(makerAb, quantity);
        sorted[2].mint(makerBc, quantity);
        sorted[0].mint(taker, quantity);
        _approveRouteTokens(sorted, makerAb);
        _approveRouteTokens(sorted, makerBc);
        _approveRouteTokens(sorted, taker);

        vm.prank(makerAb);
        bytes32 bidAb = engine.fill(_fillFor(sorted[0], sorted[1], _order(0, quantity, 0), true, false, false));
        vm.prank(makerBc);
        bytes32 bidBc = engine.fill(_fillFor(sorted[1], sorted[2], _order(0, quantity, 0), true, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fillFor(sorted[0], sorted[1], _order(0, quantity, 0), false, true, true);
        route[1] = _fillFor(sorted[1], sorted[2], _order(0, quantity, 0), false, true, true);

        vm.prank(taker);
        engine.fillRoute(route);

        assertEq(sorted[0].balanceOf(taker), 0);
        assertEq(sorted[1].balanceOf(taker), 0);
        assertEq(sorted[2].balanceOf(taker), quantity);

        vm.prank(makerAb);
        (uint256 baseAb, uint256 quoteAb) = engine.cancel(address(sorted[0]), address(sorted[1]), 0, bidAb);
        vm.prank(makerBc);
        (uint256 baseBc, uint256 quoteBc) = engine.cancel(address(sorted[1]), address(sorted[2]), 0, bidBc);
        assertEq(baseAb, quantity);
        assertEq(quoteAb, 0);
        assertEq(baseBc, quantity);
        assertEq(quoteBc, 0);
    }

    function test_FillRouteZeroDeltaLegDoesNotTouchTokens() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](1);
        route[0] = _fill(0, _order(9, 1, 0), true, true, false);

        vm.prank(bob);
        engine.fillRoute(route);

        assertEq(token0.balanceOf(bob), bobToken0Before);
        assertEq(token1.balanceOf(bob), bobToken1Before);
    }

    function test_BookHookFlagWithoutPoolHookReturnsCleanly() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        bytes32 id = engine.bookId(address(token0), address(token1), 0);
        uint256 nonce = engine.nextNonce(address(token0), address(token1), 0);
        engine.setNonceAndFlags(id, nonce | (uint256(1) << 35));

        vm.prank(bob);
        engine.fill(_fill(0, _order(10, 1, 0), true, true, false));

        assertEq(token0.balanceOf(bob), 1_000_001);
    }

    function test_FillOrKillRevertsWhenRouteLegCannotFullyMatch() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 1, 0), false, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](1);
        route[0] = _fill(0, _order(10, 2, 0), true, true, true);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("FillOrKill()")));
        engine.fillRoute(route);
    }

    function test_EmptyBookNoRestAndFillOrKillRevertInvalidBook() public {
        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidBook()")));
        engine.fill(_fill(7, _order(10, 5, 0), true, true, false));

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidBook()")));
        engine.fill(_fill(7, _order(10, 5, 0), true, false, true));
    }

    function test_RestThatExhaustsNonceRotatesAndInitializesNextBook() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);

        assertEq(resting, _order(10, 5, 2));
        assertEq(engine.poolEpoch(pid), 1);
        assertEq(engine.nextNonce(address(token0), address(token1), 0), 1);
        assertEq(engine.nextNonce(address(token0), address(token1), 1), MAX_ORDER_NONCE);
        assertEq(engine.ownerOfOrder(engine.orderId(oldBook, resting)), alice);
        assertEq(engine.ownerOfOrder(engine.orderId(newBook, resting)), address(0));
    }

    function test_RestInExhaustedBookUsesNextActiveEpoch() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 1);

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 1);
        assertEq(resting, _order(10, 5, MAX_ORDER_NONCE));
        assertEq(engine.ownerOfOrder(engine.orderId(newBook, resting)), alice);
    }

    function test_RestInNonceOneBookWithHookFlagsUsesNextActiveEpoch() public {
        engine.setPoolHookConfig(address(token0), address(token1), address(this), true, true);

        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 1 | (uint256(1) << 34) | (uint256(1) << 35));

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 1);
        assertEq(engine.ownerOfOrder(engine.orderId(newBook, resting)), alice);
    }

    function test_StaleEmptyRoutedEpochCannotInitializeWhenPoolAdvanced() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 1);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("InvalidBook()")));
        engine.fill(_fill(2, _order(11, 5, 0), true, false, false));
    }

    function test_HookFlagsAreCarriedAcrossNonceExhaustionRotation() public {
        engine.setPoolHookConfig(address(token0), address(token1), address(this), true, true);

        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2 | (uint256(1) << 34) | (uint256(1) << 35));

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);
        assertEq(engine.nextNonce(address(token0), address(token1), 1), MAX_ORDER_NONCE);

        vm.prank(bob);
        bytes32 resting = engine.fill(_fill(1, _order(11, 5, 0), true, false, false));
        assertEq(engine.ownerOfOrder(engine.orderId(newBook, resting)), bob);
    }

    function test_RotationDoesNotOverwriteInitializedNextBook() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);
        engine.setNonceAndFlags(oldBook, 2);
        engine.setNonceAndFlags(newBook, MAX_ORDER_NONCE - 7);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 1);
        assertEq(engine.nextNonce(address(token0), address(token1), 1), MAX_ORDER_NONCE - 7);
    }

    function test_RestBookHarnessRejectsExhaustedNonce() public {
        bytes32 id = engine.bookId(address(token0), address(token1), 0);

        vm.expectRevert(bytes4(keccak256("NonceExhausted()")));
        engine.restBookForTest(id, 1, 10, 5, true, alice);
    }

    function _fill(uint256 epoch, bytes32 order, bool isBid, bool noRest, bool fillOrKill)
        internal
        view
        returns (DeepstateV1.FillParams memory params)
    {
        params = DeepstateV1.FillParams({
            token0: address(token0),
            token1: address(token1),
            epoch: epoch,
            order: order,
            isBid: isBid,
            noRest: noRest,
            fillOrKill: fillOrKill
        });
    }

    function _fillFor(
        RoutingTestERC20 lower,
        RoutingTestERC20 upper,
        bytes32 order,
        bool isBid,
        bool noRest,
        bool fillOrKill
    ) internal pure returns (DeepstateV1.FillParams memory params) {
        params = DeepstateV1.FillParams({
            token0: address(lower),
            token1: address(upper),
            epoch: 0,
            order: order,
            isBid: isBid,
            noRest: noRest,
            fillOrKill: fillOrKill
        });
    }

    function _sortTokens(RoutingTestERC20 a, RoutingTestERC20 b, RoutingTestERC20 c)
        internal
        pure
        returns (RoutingTestERC20[3] memory sorted)
    {
        sorted = [a, b, c];
        if (address(sorted[0]) > address(sorted[1])) (sorted[0], sorted[1]) = (sorted[1], sorted[0]);
        if (address(sorted[1]) > address(sorted[2])) (sorted[1], sorted[2]) = (sorted[2], sorted[1]);
        if (address(sorted[0]) > address(sorted[1])) (sorted[0], sorted[1]) = (sorted[1], sorted[0]);
    }

    function _approveRouteTokens(RoutingTestERC20[3] memory sorted, address user) internal {
        vm.startPrank(user);
        sorted[0].approve(address(engine), type(uint256).max);
        sorted[1].approve(address(engine), type(uint256).max);
        sorted[2].approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _fundAndApprove(address user) internal {
        token0.mint(user, 1_000_000);
        token1.mint(user, 1_000_000);

        vm.startPrank(user);
        token0.approve(address(engine), type(uint256).max);
        token1.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) internal pure returns (uint256 quoteAmount) {
        quoteAmount = QuoteMath.quoteValue(tick, quantity, roundUp);
    }
}
