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

contract RotationRecordingHook {
    struct Call {
        bytes32 poolId;
        bytes32 bookId;
        address token;
        uint160 outgoingAmount;
        uint32 incomingNonce;
    }

    address internal immutable ENGINE;
    Call[] internal calls;

    constructor(address engine_) {
        ENGINE = engine_;
    }

    function execute(bytes32 poolId, bytes32 bookId, address token, uint160 outgoingAmount, uint32 incomingNonce)
        external
    {
        require(msg.sender == ENGINE, "only engine");
        calls.push(
            Call({
                poolId: poolId,
                bookId: bookId,
                token: token,
                outgoingAmount: outgoingAmount,
                incomingNonce: incomingNonce
            })
        );
    }

    function callCount() external view returns (uint256) {
        return calls.length;
    }

    function callAt(uint256 index)
        external
        view
        returns (bytes32 poolId, bytes32 bookId, address token, uint160 outgoingAmount, uint32 incomingNonce)
    {
        Call storage recorded = calls[index];
        return (recorded.poolId, recorded.bookId, recorded.token, recorded.outgoingAmount, recorded.incomingNonce);
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
    address internal integratorRecipient = address(0x1A7E);

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

        assertEq(engine.nextNonce(address(0), address(token1), 0), 0);

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

    function test_IntegratorFeeValidationMatchesProtocolFeeConstraints() public {
        DeepstateV1.IntegratorFee memory fee = _integratorFee(integratorRecipient, 101);
        vm.expectRevert(DeepstateV1.InvalidFeeConfig.selector);
        engine.fillWithIntegratorFee(_fill(0, _order(10, 5, 0), true, false, false), fee);

        fee = _integratorFee(address(0), 1);
        vm.expectRevert(DeepstateV1.InvalidFeeConfig.selector);
        engine.fillWithIntegratorFee(_fill(0, _order(10, 5, 0), true, false, false), fee);

        fee = _integratorFee(integratorRecipient, 0);
        vm.prank(alice);
        bytes32 resting = engine.fillWithIntegratorFee(_fill(0, _order(10, 5, 0), true, false, false), fee);
        assertTrue(resting != bytes32(0));
        assertEq(token0.balanceOf(integratorRecipient), 0);
        assertEq(token1.balanceOf(integratorRecipient), 0);
    }

    function test_IntegratorBidFeeUsesSameGrossOutputAndRoundingAsProtocolFee() public {
        uint160 quantity = 12_345;
        uint16 protocolBps = 37;
        uint16 integratorBps = 61;
        engine.setFeeConfig(feeRecipient, protocolBps);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, quantity, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);
        uint256 protocolFee = uint256(quantity) * protocolBps / 10_000;
        uint256 integratorFee = uint256(quantity) * integratorBps / 10_000;

        vm.prank(bob);
        engine.fillWithIntegratorFee(
            _fill(0, _order(10, quantity, 0), true, true, true), _integratorFee(integratorRecipient, integratorBps)
        );

        assertEq(token0.balanceOf(bob), bobToken0Before + quantity - protocolFee - integratorFee);
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, quantity, false));
        assertEq(token0.balanceOf(feeRecipient), protocolFee);
        assertEq(token0.balanceOf(integratorRecipient), integratorFee);
        assertEq(token1.balanceOf(feeRecipient), 0);
        assertEq(token1.balanceOf(integratorRecipient), 0);
    }

    function test_IntegratorAskFeeUsesSameGrossOutputAndRoundingAsProtocolFee() public {
        uint160 quantity = 12_345;
        int32 tick = 10;
        uint16 protocolBps = 37;
        uint16 integratorBps = 61;
        engine.setFeeConfig(feeRecipient, protocolBps);

        vm.prank(alice);
        engine.fill(_fill(0, _order(tick, quantity, 0), true, false, false));

        uint256 quoteOutput = _quoteValue(tick, quantity, true);
        uint256 protocolFee = quoteOutput * protocolBps / 10_000;
        uint256 integratorFee = quoteOutput * integratorBps / 10_000;
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        vm.prank(bob);
        engine.fillWithIntegratorFee(
            _fill(0, _order(tick, quantity, 0), false, true, true), _integratorFee(integratorRecipient, integratorBps)
        );

        assertEq(token0.balanceOf(bob), bobToken0Before - quantity);
        assertEq(token1.balanceOf(bob), bobToken1Before + quoteOutput - protocolFee - integratorFee);
        assertEq(token1.balanceOf(feeRecipient), protocolFee);
        assertEq(token1.balanceOf(integratorRecipient), integratorFee);
        assertEq(token0.balanceOf(feeRecipient), 0);
        assertEq(token0.balanceOf(integratorRecipient), 0);
    }

    function test_IntegratorFeeAppliesOnlyToMatchedOutputBeforeRemainderRests() public {
        uint160 makerQuantity = 10_000;
        uint160 takerQuantity = 15_000;
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, makerQuantity, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);
        vm.prank(bob);
        bytes32 remainder = engine.fillWithIntegratorFee(
            _fill(0, _order(10, takerQuantity, 0), true, false, false), _integratorFee(integratorRecipient, 100)
        );

        assertTrue(remainder != bytes32(0));
        assertEq(token0.balanceOf(bob), bobToken0Before + 9_800);
        assertEq(token0.balanceOf(feeRecipient), 100);
        assertEq(token0.balanceOf(integratorRecipient), 100);

        vm.prank(bob);
        (, uint256 returnedCollateral) = engine.cancel(address(token0), address(token1), 0, remainder);
        assertEq(returnedCollateral, _quoteValue(10, takerQuantity - makerQuantity, true));
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, makerQuantity, false));
        assertEq(token0.balanceOf(feeRecipient), 100);
        assertEq(token0.balanceOf(integratorRecipient), 100);
    }

    function test_UnmatchedIntegratorFillRestsAndCancelRemainsFeeFree() public {
        vm.prank(alice);
        bytes32 resting = engine.fillWithIntegratorFee(
            _fill(0, _order(10, 10_000, 0), true, false, false), _integratorFee(integratorRecipient, 100)
        );

        assertTrue(resting != bytes32(0));
        assertEq(token0.balanceOf(integratorRecipient), 0);
        assertEq(token1.balanceOf(integratorRecipient), 0);

        vm.prank(alice);
        engine.cancel(address(token0), address(token1), 0, resting);
        assertEq(token0.balanceOf(integratorRecipient), 0);
        assertEq(token1.balanceOf(integratorRecipient), 0);
    }

    function test_ProtocolAndIntegratorCanShareRecipientWithoutCompounding() public {
        uint160 quantity = 10_000;
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, quantity, 0), false, false, false));

        vm.prank(bob);
        engine.fillWithIntegratorFee(
            _fill(0, _order(10, quantity, 0), true, true, true), _integratorFee(feeRecipient, 100)
        );

        assertEq(token0.balanceOf(feeRecipient), 200);
    }

    function test_MaxSignedAskOutputSupportsProtocolAndIntegratorFees() public {
        uint160 quantity = uint160(uint256(1) << 154);
        uint256 quoteOutput = _quoteValue(type(int32).max, quantity, true);
        engine.setFeeConfig(feeRecipient, 100);

        token1.mint(alice, quoteOutput);
        vm.prank(alice);
        engine.fill(_fill(0, _order(type(int32).max, quantity, 0), true, false, false));

        token0.mint(bob, quantity);
        uint256 bobQuoteBefore = token1.balanceOf(bob);
        vm.prank(bob);
        engine.fillWithIntegratorFee(
            _fill(0, _order(type(int32).max, quantity, 0), false, true, true), _integratorFee(integratorRecipient, 100)
        );

        uint256 fee = quoteOutput / 100;
        assertEq(token1.balanceOf(bob), bobQuoteBefore + quoteOutput - fee - fee);
        assertEq(token1.balanceOf(feeRecipient), fee);
        assertEq(token1.balanceOf(integratorRecipient), fee);
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

    function test_OldEpochMatchRemainderIsAutomaticallyNoRest() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 pid = engine.poolId(address(token0), address(token1));
        assertEq(engine.poolEpoch(pid), 1);

        vm.prank(bob);
        bytes32 restingAsk = engine.fill(_fill(0, _order(10, 7, 0), false, false, false));

        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);
        assertEq(restingAsk, bytes32(0));
        (bytes32 askRoot, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 1);
        assertEq(askRoot, bytes32(0));
        assertEq(bidRoot, bytes32(0));
        assertEq(engine.ownerOfOrder(engine.orderId(newBook, _order(10, 2, MAX_ORDER_NONCE))), address(0));
    }

    function test_OldEpochFillOrKillStillRevertsOnUnmatchedRemainder() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        bytes32 restingBid = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("FillOrKill()")));
        engine.fill(_fill(0, _order(10, 7, 0), false, false, true));

        (, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 0);
        assertEq(bidRoot, restingBid);
        assertEq(engine.ownerOfOrder(engine.orderId(oldBook, restingBid)), alice);
    }

    function test_HistoricalRemainderCannotCrossActiveBook() public {
        engine.setPoolHookConfig(address(token0), address(token1), address(this), true, true);
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        engine.fill(_fill(0, _order(type(int32).min, 1, 0), true, false, false));
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 1);

        vm.prank(alice);
        bytes32 activeAsk = engine.fill(_fill(1, _order(-10, 5, 0), false, false, false));
        assertTrue(activeAsk != bytes32(0));

        vm.prank(bob);
        bytes32 resting = engine.fill(_fill(0, _order(0, 5, 0), true, false, false));
        assertEq(resting, bytes32(0));

        (bytes32 askRoot, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 1);
        assertEq(askRoot, activeAsk);
        assertEq(bidRoot, bytes32(0));

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(token0), address(token1), 1, activeAsk);
        assertEq(baseAmount, 5);
        assertEq(quoteAmount, 0);
    }

    function test_HistoricalRemainderDoesNotInitializeEmptyActiveBook() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        engine.fill(_fill(0, _order(type(int32).min, 1, 0), true, false, false));

        bytes32 activeBook = engine.bookId(address(token0), address(token1), 1);
        engine.setNonceAndFlags(activeBook, 0);

        vm.prank(bob);
        bytes32 resting = engine.fill(_fill(0, _order(-1, 5, 0), true, false, false));

        assertEq(resting, bytes32(0));
        assertEq(engine.nextNonce(address(token0), address(token1), 1), 0);
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

    function test_IntegratorRouteAccumulatesRepeatedFeesForOneToken() public {
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 20_000, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);
        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(0, _order(10, 10_000, 0), true, true, true);
        route[1] = _fill(0, _order(10, 10_000, 0), true, true, true);

        vm.prank(bob);
        engine.fillRouteWithIntegratorFee(route, _integratorFee(integratorRecipient, 100));

        assertEq(token0.balanceOf(bob), bobToken0Before + 19_600);
        assertEq(token1.balanceOf(bob), bobToken1Before - _quoteValue(10, 20_000, false));
        assertEq(token0.balanceOf(feeRecipient), 200);
        assertEq(token0.balanceOf(integratorRecipient), 200);
    }

    function test_IntegratorRouteChargesEveryLegExactlyLikeProtocolTakerFee() public {
        RoutingTestERC20 a = new RoutingTestERC20("Route A", "RA");
        RoutingTestERC20 b = new RoutingTestERC20("Route B", "RB");
        RoutingTestERC20 c = new RoutingTestERC20("Route C", "RC");
        RoutingTestERC20[3] memory sorted = _sortTokens(a, b, c);
        address makerAb = address(0xAB01);
        address makerBc = address(0xBC01);
        address taker = address(0xC0FFEE);
        uint160 quantity = 100_000;
        uint256 protocolFee = 1_000;
        uint256 integratorFee = 500;
        engine.setFeeConfig(feeRecipient, 100);

        sorted[1].mint(makerAb, quantity);
        sorted[2].mint(makerBc, quantity);
        sorted[0].mint(taker, quantity);
        sorted[1].mint(taker, protocolFee + integratorFee);
        _approveRouteTokens(sorted, makerAb);
        _approveRouteTokens(sorted, makerBc);
        _approveRouteTokens(sorted, taker);

        vm.prank(makerAb);
        engine.fill(_fillFor(sorted[0], sorted[1], _order(0, quantity, 0), true, false, false));
        vm.prank(makerBc);
        engine.fill(_fillFor(sorted[1], sorted[2], _order(0, quantity, 0), true, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fillFor(sorted[0], sorted[1], _order(0, quantity, 0), false, true, true);
        route[1] = _fillFor(sorted[1], sorted[2], _order(0, quantity, 0), false, true, true);

        vm.prank(taker);
        engine.fillRouteWithIntegratorFee(route, _integratorFee(integratorRecipient, 50));

        assertEq(sorted[0].balanceOf(taker), 0);
        assertEq(sorted[1].balanceOf(taker), 0);
        assertEq(sorted[2].balanceOf(taker), quantity - protocolFee - integratorFee);
        assertEq(sorted[1].balanceOf(feeRecipient), protocolFee);
        assertEq(sorted[2].balanceOf(feeRecipient), protocolFee);
        assertEq(sorted[1].balanceOf(integratorRecipient), integratorFee);
        assertEq(sorted[2].balanceOf(integratorRecipient), integratorFee);
    }

    function test_IntegratorRouteZeroOutputLegChargesNoFee() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](1);
        route[0] = _fill(0, _order(9, 1, 0), true, true, false);

        vm.prank(bob);
        engine.fillRouteWithIntegratorFee(route, _integratorFee(integratorRecipient, 100));

        assertEq(token0.balanceOf(integratorRecipient), 0);
        assertEq(token1.balanceOf(integratorRecipient), 0);
    }

    function test_IntegratorLateRouteFailureRevertsMatchingAndAllFeesAtomically() public {
        engine.setFeeConfig(feeRecipient, 100);
        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        bytes32 id = engine.bookId(address(token0), address(token1), 0);
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);
        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(0, _order(10, 3, 0), true, true, false);
        route[1] = _fill(0, _order(10, 3, 0), true, true, true);

        vm.prank(bob);
        vm.expectRevert(DeepstateV1.FillOrKill.selector);
        engine.fillRouteWithIntegratorFee(route, _integratorFee(integratorRecipient, 100));

        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertEq(askRoot, restingAsk);
        assertEq(engine.ownerOfOrder(engine.orderId(id, restingAsk)), alice);
        assertEq(token0.balanceOf(bob), bobToken0Before);
        assertEq(token1.balanceOf(bob), bobToken1Before);
        assertEq(token0.balanceOf(feeRecipient), 0);
        assertEq(token0.balanceOf(integratorRecipient), 0);
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

    function test_RotationFinalizesBothEnabledOldBookTopsBeforeDisablingHooks() public {
        RotationRecordingHook hook = new RotationRecordingHook(address(engine));
        engine.setPoolHookConfig(address(token0), address(token1), address(hook), true, true);

        vm.prank(alice);
        bytes32 ask = engine.fill(_fill(0, _order(20, 7, 0), false, false, false));
        vm.prank(bob);
        bytes32 bid = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        uint256 callsBeforeRotation = hook.callCount();
        assertEq(callsBeforeRotation, 2);

        engine.setNonceAndFlags(oldBook, 2 | (uint256(1) << 34) | (uint256(1) << 35));
        vm.prank(alice);
        engine.fill(_fill(0, _order(5, 3, 0), true, false, false));

        assertEq(engine.poolEpoch(pid), 1);
        assertEq(hook.callCount(), callsBeforeRotation + 2);

        (bytes32 bidPid, bytes32 bidBook, address bidToken, uint160 bidAmount, uint32 bidIncoming) =
            hook.callAt(callsBeforeRotation);
        assertEq(bidPid, pid);
        assertEq(bidBook, oldBook);
        assertEq(bidToken, address(token1));
        assertEq(bidAmount, _quoteValue(10, 5, true));
        assertEq(bidIncoming, 0);

        (bytes32 askPid, bytes32 askBook, address askToken, uint160 askAmount, uint32 askIncoming) =
            hook.callAt(callsBeforeRotation + 1);
        assertEq(askPid, pid);
        assertEq(askBook, oldBook);
        assertEq(askToken, address(token0));
        assertEq(askAmount, 7);
        assertEq(askIncoming, 0);

        vm.prank(bob);
        engine.cancel(address(token0), address(token1), 0, bid);
        vm.prank(alice);
        engine.cancel(address(token0), address(token1), 0, ask);
        assertEq(hook.callCount(), callsBeforeRotation + 2);
    }

    function test_FinalEpochCannotAliasHookFlagsAndFailedRestIsAtomic() public {
        uint256 finalEpoch = (uint256(1) << 254) - 1;
        bytes32 pid = engine.poolId(address(token0), address(token1));
        // `_poolEpochAndHookFlags` is mapping slot two; the strict storage-layout test pins this.
        bytes32 poolStateSlot = keccak256(abi.encode(pid, uint256(2)));
        vm.store(address(engine), poolStateSlot, bytes32(finalEpoch));

        bytes32 finalBook = engine.bookId(address(token0), address(token1), finalEpoch);
        engine.setNonceAndFlags(finalBook, 2);
        bytes32 candidate = _order(10, 5, 2);
        uint256 aliceToken1Before = token1.balanceOf(alice);

        vm.startPrank(alice);
        vm.expectRevert(DeepstateV1.EpochExhausted.selector);
        engine.fill(_fill(finalEpoch, _order(10, 5, 0), true, false, false));
        vm.stopPrank();

        assertEq(engine.poolEpoch(pid), finalEpoch);
        assertEq(engine.nextNonce(address(token0), address(token1), finalEpoch), 2);
        (bytes32 askRoot, bytes32 bidRoot) = engine.roots(address(token0), address(token1), finalEpoch);
        assertEq(askRoot, bytes32(0));
        assertEq(bidRoot, bytes32(0));
        assertEq(engine.ownerOfOrder(engine.orderId(finalBook, candidate)), address(0));
        assertEq(token1.balanceOf(alice), aliceToken1Before);
    }

    function test_ExhaustedBookAutomaticallyDisablesRest() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 1);

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 0);
        assertEq(resting, bytes32(0));
        assertEq(engine.nextNonce(address(token0), address(token1), 0), 1);
    }

    function test_ExhaustedHookBookAutomaticallyDisablesRest() public {
        engine.setPoolHookConfig(address(token0), address(token1), address(this), true, true);

        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 1 | (uint256(1) << 34) | (uint256(1) << 35));

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 0);
        assertEq(resting, bytes32(0));
        assertEq(engine.nextNonce(address(token0), address(token1), 0), 1);
    }

    function test_StaleEmptyRoutedEpochCannotInitializeWhenPoolAdvanced() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 1);

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

    function testFuzz_IntegratorBidFeeEqualsIndependentProtocolFormula(
        uint128 quantitySeed,
        uint8 protocolBpsSeed,
        uint8 integratorBpsSeed
    ) public {
        uint160 quantity = uint160(bound(uint256(quantitySeed), 1, 1e24));
        uint16 protocolBps = uint16(bound(uint256(protocolBpsSeed), 0, 100));
        uint16 integratorBps = uint16(bound(uint256(integratorBpsSeed), 0, 100));
        engine.setFeeConfig(feeRecipient, protocolBps);
        token0.mint(alice, quantity);
        token1.mint(bob, _quoteValue(0, quantity, false));

        vm.prank(alice);
        engine.fill(_fill(0, _order(0, quantity, 0), false, false, false));

        uint256 bobBaseBefore = token0.balanceOf(bob);
        vm.prank(bob);
        engine.fillWithIntegratorFee(
            _fill(0, _order(0, quantity, 0), true, true, true), _integratorFee(integratorRecipient, integratorBps)
        );

        uint256 protocolFee = uint256(quantity) * protocolBps / 10_000;
        uint256 integratorFee = uint256(quantity) * integratorBps / 10_000;
        assertEq(token0.balanceOf(bob), bobBaseBefore + quantity - protocolFee - integratorFee);
        assertEq(token0.balanceOf(feeRecipient), protocolFee);
        assertEq(token0.balanceOf(integratorRecipient), integratorFee);
    }

    function testFuzz_IntegratorAskFeeEqualsIndependentProtocolFormula(
        uint96 quantitySeed,
        int24 tickSeed,
        uint8 protocolBpsSeed,
        uint8 integratorBpsSeed
    ) public {
        uint160 quantity = uint160(bound(uint256(quantitySeed), 1, 1e24));
        int32 tick = int32(bound(int256(tickSeed), -100_000, 100_000));
        uint16 protocolBps = uint16(bound(uint256(protocolBpsSeed), 0, 100));
        uint16 integratorBps = uint16(bound(uint256(integratorBpsSeed), 0, 100));
        uint256 quoteOutput = _quoteValue(tick, quantity, true);
        engine.setFeeConfig(feeRecipient, protocolBps);
        token1.mint(alice, quoteOutput);
        token0.mint(bob, quantity);

        vm.prank(alice);
        engine.fill(_fill(0, _order(tick, quantity, 0), true, false, false));

        uint256 bobQuoteBefore = token1.balanceOf(bob);
        vm.prank(bob);
        engine.fillWithIntegratorFee(
            _fill(0, _order(tick, quantity, 0), false, true, true), _integratorFee(integratorRecipient, integratorBps)
        );

        uint256 protocolFee = quoteOutput * protocolBps / 10_000;
        uint256 integratorFee = quoteOutput * integratorBps / 10_000;
        assertEq(token1.balanceOf(bob), bobQuoteBefore + quoteOutput - protocolFee - integratorFee);
        assertEq(token1.balanceOf(feeRecipient), protocolFee);
        assertEq(token1.balanceOf(integratorRecipient), integratorFee);
    }

    function _integratorFee(address recipient, uint16 bps)
        internal
        pure
        returns (DeepstateV1.IntegratorFee memory fee)
    {
        fee = DeepstateV1.IntegratorFee({recipient: recipient, bps: bps});
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
