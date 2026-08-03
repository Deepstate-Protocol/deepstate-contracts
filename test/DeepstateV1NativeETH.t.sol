// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";

contract NativeTestERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Native Test";
    }

    function symbol() public pure override returns (string memory) {
        return "NATIVE-TEST";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract NativeRecordingHook {
    bytes32 public lastPoolId;
    bytes32 public lastBookId;
    address public lastToken;
    uint160 public lastOutgoingQuantity;
    uint32 public lastIncomingNonce;

    function execute(bytes32 poolId, bytes32 bookId, address token, uint160 outgoingQuantity, uint32 incomingNonce)
        external
    {
        lastPoolId = poolId;
        lastBookId = bookId;
        lastToken = token;
        lastOutgoingQuantity = outgoingQuantity;
        lastIncomingNonce = incomingNonce;
    }
}

contract RevertingNativeFeeRecipient {
    receive() external payable {
        revert();
    }
}

contract NativeReentrantBuyer {
    DeepstateV1 internal immutable ENGINE;
    address internal immutable QUOTE;

    bool public reentryBlocked;

    constructor(DeepstateV1 engine, address quote) {
        ENGINE = engine;
        QUOTE = quote;
    }

    function approveQuote() external {
        NativeTestERC20(QUOTE).approve(address(ENGINE), type(uint256).max);
    }

    function buy(DeepstateV1.FillParams calldata params) external {
        ENGINE.fill(params);
    }

    receive() external payable {
        try ENGINE.cancel(address(0), QUOTE, 0, bytes32(0)) {}
        catch (bytes memory reason) {
            bytes4 selector;
            assembly {
                selector := mload(add(reason, 0x20))
            }
            reentryBlocked = selector == DeepstateV1.ReentrantCall.selector;
        }
    }
}

contract DeepstateV1NativeETHTest is Test {
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;

    DeepstateV1 internal engine;
    NativeTestERC20 internal quoteA;
    NativeTestERC20 internal quoteB;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal makerB = address(0xBEEF);
    address internal feeRecipient = address(0xFEE);
    address internal integratorRecipient = address(0x1A7E);

    function setUp() public {
        engine = new DeepstateV1();
        quoteA = new NativeTestERC20();
        quoteB = new NativeTestERC20();

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(makerB, 100 ether);

        _fundAndApprove(quoteA, alice);
        _fundAndApprove(quoteA, bob);
        _fundAndApprove(quoteA, makerB);
        _fundAndApprove(quoteB, alice);
        _fundAndApprove(quoteB, bob);
        _fundAndApprove(quoteB, makerB);
    }

    function test_NativeETHIsCanonicalToken0Only() public {
        assertEq(engine.nextNonce(address(0), address(quoteA), 0), 0);
        assertEq(engine.activeBookId(address(0), address(quoteA)), engine.bookId(address(0), address(quoteA), 0));

        vm.expectRevert(DeepstateV1.InvalidToken.selector);
        engine.nextNonce(address(quoteA), address(0), 0);

        vm.expectRevert(DeepstateV1.InvalidToken.selector);
        engine.nextNonce(address(0), address(0), 0);
    }

    function test_NativeAskRestsAndCancelRefundsETH() public {
        uint160 quantity = 5 ether;
        uint256 aliceBefore = alice.balance;

        vm.prank(alice);
        bytes32 ask = engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        assertEq(ask, _order(0, quantity, MAX_ORDER_NONCE));
        assertEq(address(engine).balance, quantity);
        assertEq(alice.balance, aliceBefore - quantity);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(0), address(quoteA), 0, ask);

        assertEq(baseAmount, quantity);
        assertEq(quoteAmount, 0);
        assertEq(address(engine).balance, 0);
        assertEq(alice.balance, aliceBefore);
    }

    function test_NativeAskMatchesBidAndMakerClaimsETH() public {
        uint160 quantity = 4 ether;

        vm.prank(alice);
        bytes32 bid = engine.fill(_fill(quoteA, _order(0, quantity), true, false, false));

        uint256 bobQuoteBefore = quoteA.balanceOf(bob);
        vm.prank(bob);
        engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, true, true));

        assertEq(quoteA.balanceOf(bob), bobQuoteBefore + quantity);
        assertEq(address(engine).balance, quantity);

        uint256 aliceEthBefore = alice.balance;
        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(0), address(quoteA), 0, bid);

        assertEq(baseAmount, quantity);
        assertEq(quoteAmount, 0);
        assertEq(alice.balance, aliceEthBefore + quantity);
        assertEq(address(engine).balance, 0);
    }

    function test_NativeBidMatchesAskAndPaysETH() public {
        uint160 quantity = 3 ether;

        vm.prank(alice);
        bytes32 ask = engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        uint256 bobEthBefore = bob.balance;
        vm.prank(bob);
        engine.fill(_fill(quoteA, _order(0, quantity), true, true, true));

        assertEq(bob.balance, bobEthBefore + quantity);
        assertEq(address(engine).balance, 0);

        uint256 aliceQuoteBefore = quoteA.balanceOf(alice);
        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(0), address(quoteA), 0, ask);

        assertEq(baseAmount, 0);
        assertEq(quoteAmount, quantity);
        assertEq(quoteA.balanceOf(alice), aliceQuoteBefore + quantity);
    }

    function test_NativeValueMustCoverNetDebitAndRefundsExcess() public {
        uint160 quantity = 2 ether;
        uint256 excess = 0.25 ether;
        DeepstateV1.FillParams memory ask = _fill(quoteA, _order(0, quantity), false, false, false);

        vm.prank(alice);
        vm.expectRevert(DeepstateV1.InvalidNativeValue.selector);
        engine.fill{value: quantity - 1}(ask);
        assertEq(engine.nextNonce(address(0), address(quoteA), 0), 0);
        assertEq(address(engine).balance, 0);

        uint256 aliceNativeBefore = alice.balance;
        vm.prank(alice);
        bytes32 restingAsk = engine.fill{value: quantity + excess}(ask);
        assertEq(alice.balance, aliceNativeBefore - quantity);
        assertEq(address(engine).balance, quantity);

        vm.prank(alice);
        engine.cancel(address(0), address(quoteA), 0, restingAsk);
        assertEq(alice.balance, aliceNativeBefore);
        assertEq(address(engine).balance, 0);

        address lower = address(quoteA) < address(quoteB) ? address(quoteA) : address(quoteB);
        address upper = address(quoteA) < address(quoteB) ? address(quoteB) : address(quoteA);
        DeepstateV1.FillParams memory erc20Fill = DeepstateV1.FillParams({
            token0: lower,
            token1: upper,
            epoch: 0,
            order: _order(0, quantity),
            isBid: true,
            noRest: false,
            fillOrKill: false
        });

        aliceNativeBefore = alice.balance;
        vm.prank(alice);
        engine.fill{value: 1}(erc20Fill);
        assertEq(alice.balance, aliceNativeBefore);

        DeepstateV1.FillParams[] memory emptyRoute = new DeepstateV1.FillParams[](0);
        aliceNativeBefore = alice.balance;
        vm.prank(alice);
        engine.fillRoute{value: 1}(emptyRoute);
        assertEq(alice.balance, aliceNativeBefore);
    }

    function test_RouteNetsNativeETHAndCollectsOnlyNetDebit() public {
        uint160 boughtEth = 3 ether;
        uint160 soldEth = 5 ether;

        vm.prank(alice);
        engine.fill{value: boughtEth}(_fill(quoteA, _order(0, boughtEth), false, false, false));

        vm.prank(makerB);
        bytes32 bidB = engine.fill(_fill(quoteB, _order(0, soldEth), true, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(quoteA, _order(0, boughtEth), true, true, true);
        route[1] = _fill(quoteB, _order(0, soldEth), false, true, true);

        uint256 bobEthBefore = bob.balance;
        uint256 bobQuoteABefore = quoteA.balanceOf(bob);
        uint256 bobQuoteBBefore = quoteB.balanceOf(bob);
        vm.prank(bob);
        vm.expectRevert(DeepstateV1.InvalidNativeValue.selector);
        engine.fillRoute{value: soldEth - boughtEth - 1}(route);

        assertEq(bob.balance, bobEthBefore);
        assertEq(quoteA.balanceOf(bob), bobQuoteABefore);
        assertEq(quoteB.balanceOf(bob), bobQuoteBBefore);

        uint256 excess = 0.5 ether;
        vm.prank(bob);
        engine.fillRoute{value: soldEth - boughtEth + excess}(route);

        assertEq(bob.balance, bobEthBefore - (soldEth - boughtEth));
        assertEq(quoteA.balanceOf(bob), bobQuoteABefore - boughtEth);
        assertEq(quoteB.balanceOf(bob), bobQuoteBBefore + soldEth);
        assertEq(address(engine).balance, soldEth);

        vm.prank(makerB);
        (uint256 baseAmount,) = engine.cancel(address(0), address(quoteB), 0, bidB);
        assertEq(baseAmount, soldEth);
        assertEq(address(engine).balance, 0);
    }

    function test_RoutePaysPositiveNetNativeETH() public {
        uint160 boughtEth = 5 ether;
        uint160 soldEth = 3 ether;

        vm.prank(alice);
        engine.fill{value: boughtEth}(_fill(quoteA, _order(0, boughtEth), false, false, false));

        vm.prank(makerB);
        engine.fill(_fill(quoteB, _order(0, soldEth), true, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(quoteA, _order(0, boughtEth), true, true, true);
        route[1] = _fill(quoteB, _order(0, soldEth), false, true, true);

        uint256 bobEthBefore = bob.balance;
        uint256 excess = 0.5 ether;
        vm.prank(bob);
        engine.fillRoute{value: excess}(route);

        assertEq(bob.balance, bobEthBefore + (boughtEth - soldEth));
        assertEq(address(engine).balance, soldEth);
    }

    function test_RouteTransfersNativeFeeAfterUserOutput() public {
        uint160 quantity = 10_000;
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](1);
        route[0] = _fill(quoteA, _order(0, quantity), true, true, true);

        uint256 bobEthBefore = bob.balance;
        vm.prank(bob);
        engine.fillRoute(route);

        assertEq(bob.balance, bobEthBefore + 9_900);
        assertEq(feeRecipient.balance, 100);
        assertEq(address(engine).balance, 0);
    }

    function test_NativeBidOutputPaysProtocolAndIntegratorFees() public {
        uint160 quantity = 10_000;
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        uint256 bobEthBefore = bob.balance;
        vm.prank(bob);
        engine.fillWithIntegratorFee(
            _fill(quoteA, _order(0, quantity), true, true, true),
            DeepstateV1.IntegratorFee({recipient: integratorRecipient, bps: 10})
        );

        assertEq(bob.balance, bobEthBefore + 9_890);
        assertEq(feeRecipient.balance, 100);
        assertEq(integratorRecipient.balance, 10);
        assertEq(address(engine).balance, 0);
    }

    function test_NativeAskInputPaysIntegratorFeeFromQuoteOutputAndRefundsExcess() public {
        uint160 quantity = 10_000;
        vm.prank(alice);
        bytes32 bid = engine.fill(_fill(quoteA, _order(0, quantity), true, false, false));

        uint256 bobEthBefore = bob.balance;
        uint256 bobQuoteBefore = quoteA.balanceOf(bob);
        vm.prank(bob);
        engine.fillWithIntegratorFee{value: quantity + 7}(
            _fill(quoteA, _order(0, quantity), false, true, true),
            DeepstateV1.IntegratorFee({recipient: integratorRecipient, bps: 10})
        );

        assertEq(bob.balance, bobEthBefore - quantity);
        assertEq(quoteA.balanceOf(bob), bobQuoteBefore + 9_990);
        assertEq(quoteA.balanceOf(integratorRecipient), 10);
        assertEq(address(engine).balance, quantity);

        vm.prank(alice);
        (uint256 makerNativeClaim,) = engine.cancel(address(0), address(quoteA), 0, bid);
        assertEq(makerNativeClaim, quantity);
        assertEq(address(engine).balance, 0);
    }

    function test_NativeIntegratorRouteAccumulatesAndSettlesOnce() public {
        uint160 quantity = 20_000;
        engine.setFeeConfig(feeRecipient, 100);

        vm.prank(alice);
        engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        DeepstateV1.FillParams[] memory route = new DeepstateV1.FillParams[](2);
        route[0] = _fill(quoteA, _order(0, 10_000), true, true, true);
        route[1] = _fill(quoteA, _order(0, 10_000), true, true, true);

        uint256 bobEthBefore = bob.balance;
        vm.prank(bob);
        engine.fillRouteWithIntegratorFee(route, DeepstateV1.IntegratorFee({recipient: integratorRecipient, bps: 10}));

        assertEq(bob.balance, bobEthBefore + 19_780);
        assertEq(feeRecipient.balance, 200);
        assertEq(integratorRecipient.balance, 20);
        assertEq(address(engine).balance, 0);
    }

    function test_RevertingNativeIntegratorPayoutRevertsFillAtomically() public {
        uint160 quantity = 10_000;
        RevertingNativeFeeRecipient recipient = new RevertingNativeFeeRecipient();

        vm.prank(alice);
        bytes32 ask = engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        bytes32 id = engine.bookId(address(0), address(quoteA), 0);
        uint256 bobEthBefore = bob.balance;
        uint256 bobQuoteBefore = quoteA.balanceOf(bob);
        vm.prank(bob);
        vm.expectRevert();
        engine.fillWithIntegratorFee(
            _fill(quoteA, _order(0, quantity), true, true, true),
            DeepstateV1.IntegratorFee({recipient: address(recipient), bps: 100})
        );

        (bytes32 askRoot,) = engine.roots(address(0), address(quoteA), 0);
        assertEq(askRoot, ask);
        assertEq(engine.ownerOfOrder(engine.orderId(id, ask)), alice);
        assertEq(bob.balance, bobEthBefore);
        assertEq(quoteA.balanceOf(bob), bobQuoteBefore);
        assertEq(address(engine).balance, quantity);
    }

    function test_NativePoolHookReceivesZeroAddressToken() public {
        NativeRecordingHook hook = new NativeRecordingHook();
        engine.setPoolHookConfig(address(0), address(quoteA), address(hook), true, false);

        uint160 quantity = 1 ether;
        vm.prank(alice);
        engine.fill(_fill(quoteA, _order(0, quantity), true, false, false));

        bytes32 pool = engine.poolId(address(0), address(quoteA));
        assertEq(engine.poolHook(pool), address(hook));
        assertEq(hook.lastPoolId(), pool);
        assertEq(hook.lastBookId(), engine.bookId(address(0), address(quoteA), 0));
        assertEq(hook.lastToken(), address(0));
        assertEq(hook.lastOutgoingQuantity(), 0);
        assertEq(hook.lastIncomingNonce(), MAX_ORDER_NONCE);
    }

    function test_NativePayoutReentrancyIsBlockedWithoutBlockingFill() public {
        uint160 quantity = 1 ether;
        vm.prank(alice);
        engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        NativeReentrantBuyer buyer = new NativeReentrantBuyer(engine, address(quoteA));
        quoteA.mint(address(buyer), quantity);
        buyer.approveQuote();

        buyer.buy(_fill(quoteA, _order(0, quantity), true, true, true));

        assertTrue(buyer.reentryBlocked());
        assertEq(address(buyer).balance, quantity);
        assertEq(address(engine).balance, 0);
    }

    function test_ForcedNativeSurplusPersistsWithoutReducingCollateral() public {
        uint160 quantity = 5 ether;
        uint160 filled = 2 ether;
        uint256 forcedSurplus = 7 ether;

        vm.prank(alice);
        bytes32 ask = engine.fill{value: quantity}(_fill(quoteA, _order(0, quantity), false, false, false));

        // Simulate ETH delivered outside a protocol settlement, which cannot be rejected by an EVM account.
        vm.deal(address(engine), address(engine).balance + forcedSurplus);

        vm.prank(bob);
        engine.fill(_fill(quoteA, _order(0, filled), true, true, true));
        assertEq(address(engine).balance, uint256(quantity - filled) + forcedSurplus);

        vm.prank(alice);
        (uint256 baseAmount,) = engine.cancel(address(0), address(quoteA), 0, ask);
        assertEq(baseAmount, quantity - filled);
        assertEq(address(engine).balance, forcedSurplus);
    }

    function _fill(NativeTestERC20 quote, bytes32 order, bool isBid, bool noRest, bool fillOrKill)
        internal
        pure
        returns (DeepstateV1.FillParams memory params)
    {
        params = DeepstateV1.FillParams({
            token0: address(0),
            token1: address(quote),
            epoch: 0,
            order: order,
            isBid: isBid,
            noRest: noRest,
            fillOrKill: fillOrKill
        });
    }

    function _fundAndApprove(NativeTestERC20 token, address user) internal {
        token.mint(user, 1_000_000 ether);
        vm.prank(user);
        token.approve(address(engine), type(uint256).max);
    }

    function _order(int32 tick, uint160 quantity) internal pure returns (bytes32) {
        return _order(tick, quantity, 0);
    }

    function _order(int32 tick, uint160 quantity, uint32 nonce) internal pure returns (bytes32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return bytes32((uint256(uint32(tick)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }
}
