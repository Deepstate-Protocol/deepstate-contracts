// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapRouterNoChecks} from "v4-core/test/SwapRouterNoChecks.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";
import {V4SwapManagerModule} from "../src/V4SwapManagerModule.sol";
import {DeepstateV4LifecycleProbe} from "./helpers/DeepstateV4LifecycleProbe.sol";
import {DeepstateV4Router} from "./helpers/DeepstateV4Router.sol";
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

contract V4ReentrantERC20 is RoutingTestERC20 {
    address private _target;
    bytes private _payload;
    bool private _armed;

    bytes4 public reentrySelector;

    constructor(string memory name_, string memory symbol_) RoutingTestERC20(name_, symbol_) {}

    function arm(address target, bytes calldata payload) external {
        _target = target;
        _payload = payload;
        _armed = true;
    }

    function _afterTokenTransfer(address from, address to, uint256) internal override {
        if (!_armed || (from != _target && to != _target)) return;
        _armed = false;
        (bool success, bytes memory reason) = _target.call(_payload);
        if (!success && reason.length >= 4) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(reason, 0x20))
            }
            reentrySelector = selector;
        }
    }
}

contract GasBurningHook {
    function execute(bytes32, bytes32, address, uint160, uint32) external pure {
        assembly ("memory-safe") {
            for {} 1 {} {}
        }
    }
}

contract RecordingHook {
    uint256 public calls;
    bytes32 public lastPoolId;
    bytes32 public lastBookId;
    address public lastToken;

    function execute(bytes32 poolId, bytes32 bookId, address token, uint160, uint32) external {
        ++calls;
        lastPoolId = poolId;
        lastBookId = bookId;
        lastToken = token;
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
    DeepstateV4LifecycleProbe internal v4Probe;
    DeepstateV4Router internal v4Router;
    SwapRouterNoChecks internal officialV4Router;
    V4SwapManagerModule internal v4Module;
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
        v4Probe = new DeepstateV4LifecycleProbe(IPoolManager(address(engine)));
        v4Router = new DeepstateV4Router(IPoolManager(address(engine)));
        officialV4Router = new SwapRouterNoChecks(IPoolManager(address(engine)));
        v4Module = new V4SwapManagerModule();

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

    function test_V4SwapSelectorAndTupleLayoutMatchCore() public pure {
        assertEq(DeepstateV1.swap.selector, IPoolManager.swap.selector);
    }

    function test_V4InternalModuleSelectorsAreNotExposedByEngineFallback() public {
        (bool success,) = address(engine).call(abi.encodeCall(V4SwapManagerModule.limitTick, (uint160(1) << 96, false)));
        assertFalse(success);
    }

    function test_V4ModuleLifecycleCannotBeCalledDirectly() public {
        vm.expectRevert(IPoolManager.ManagerLocked.selector);
        v4Module.unlock("");

        vm.expectRevert(IPoolManager.ManagerLocked.selector);
        v4Module.sync(Currency.wrap(address(token0)));
    }

    function testFuzz_V4LimitTickMatchesExhaustiveBinarySearch(uint160 rawSqrtPriceX96, bool zeroForOne) public view {
        uint160 sqrtPriceLimitX96 = uint160(bound(rawSqrtPriceX96, _minSqrtLimit(), _maxSqrtLimit()));
        assertEq(
            v4Module.limitTick(sqrtPriceLimitX96, zeroForOne), _v4LimitTickReference(sqrtPriceLimitX96, zeroForOne)
        );
    }

    function test_UnmodifiedV4CoreSwapRouterSettlesAgainstEngine() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));

        uint256 bobBaseBefore = token0.balanceOf(bob);
        uint256 bobQuoteBefore = token1.balanceOf(bob);
        vm.prank(bob);
        officialV4Router.swap(_v4Key(), _v4Params(false, -6, _maxSqrtLimit()));

        assertEq(token0.balanceOf(bob), bobBaseBefore + 6);
        assertEq(token1.balanceOf(bob), bobQuoteBefore - 6);
    }

    function test_V4UnlockRouteCrossesPoolsAndNetsIntermediateToken() public {
        RoutingTestERC20 a = new RoutingTestERC20("V4 Route A", "V4A");
        RoutingTestERC20 b = new RoutingTestERC20("V4 Route B", "V4B");
        RoutingTestERC20 c = new RoutingTestERC20("V4 Route C", "V4C");
        RoutingTestERC20[3] memory sorted = _sortTokens(a, b, c);
        address makerAb = address(0xAB02);
        address makerBc = address(0xBC02);
        address taker = address(0xC0FFEF);
        uint160 quantity = 100_000;

        sorted[1].mint(makerAb, quantity);
        sorted[2].mint(makerBc, quantity);
        sorted[0].mint(taker, quantity);
        _approveRouteTokens(sorted, makerAb);
        _approveRouteTokens(sorted, makerBc);

        vm.prank(makerAb);
        engine.fill(_fillFor(sorted[0], sorted[1], _order(0, quantity, 0), true, false, false));
        vm.prank(makerBc);
        engine.fill(_fillFor(sorted[1], sorted[2], _order(0, quantity, 0), true, false, false));

        vm.startPrank(taker);
        sorted[0].approve(address(v4Router), type(uint256).max);
        DeepstateV4Router.SwapCall[] memory route = new DeepstateV4Router.SwapCall[](2);
        route[0] = DeepstateV4Router.SwapCall({
            key: _v4KeyFor(sorted[0], sorted[1]),
            params: _v4Params(true, -int256(uint256(quantity)), _minSqrtLimit()),
            hookData: ""
        });
        route[1] = DeepstateV4Router.SwapCall({
            key: _v4KeyFor(sorted[1], sorted[2]),
            params: _v4Params(true, -int256(uint256(quantity)), _minSqrtLimit()),
            hookData: ""
        });
        BalanceDelta[] memory deltas = v4Router.swapRoute(route);
        vm.stopPrank();

        assertEq(deltas.length, 2);
        _assertDelta(deltas[0], -100_000, 100_000);
        _assertDelta(deltas[1], -100_000, 100_000);
        assertEq(sorted[0].balanceOf(taker), 0);
        assertEq(sorted[1].balanceOf(taker), 0);
        assertEq(sorted[2].balanceOf(taker), quantity);
        assertEq(sorted[1].balanceOf(address(v4Router)), 0);
    }

    function test_V4LifecycleSettleForAndBatchTransientRead() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));

        uint256 bobBaseBefore = token0.balanceOf(bob);
        uint256 bobQuoteBefore = token1.balanceOf(bob);
        bytes memory result = v4Probe.run(
            DeepstateV4LifecycleProbe.Action.SettleForAndTake, bob, _v4Key(), _v4Params(false, -6, _maxSqrtLimit())
        );
        (BalanceDelta delta, bytes32[] memory transientDeltas) = abi.decode(result, (BalanceDelta, bytes32[]));

        _assertDelta(delta, 6, -6);
        assertEq(transientDeltas.length, 2);
        assertEq(transientDeltas[0], bytes32(uint256(6)));
        assertEq(transientDeltas[1], bytes32(type(uint256).max - 5));
        assertEq(token0.balanceOf(bob), bobBaseBefore + 6);
        assertEq(token1.balanceOf(bob), bobQuoteBefore - 6);
    }

    function test_V4LifecycleClearForgoesExactPositiveDelta() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));

        uint256 bobBaseBefore = token0.balanceOf(bob);
        uint256 bobQuoteBefore = token1.balanceOf(bob);
        v4Probe.run(DeepstateV4LifecycleProbe.Action.ClearOutput, bob, _v4Key(), _v4Params(false, -6, _maxSqrtLimit()));

        assertEq(token0.balanceOf(bob), bobBaseBefore);
        assertEq(token1.balanceOf(bob), bobQuoteBefore - 6);
    }

    function test_V4LifecycleRejectsWrongClearAmount() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));

        vm.expectRevert(IPoolManager.MustClearExactPositiveDelta.selector);
        v4Probe.run(
            DeepstateV4LifecycleProbe.Action.ClearWrongAmount, bob, _v4Key(), _v4Params(false, -6, _maxSqrtLimit())
        );
    }

    function test_V4LifecycleRejectsNestedUnlockAndUnsettledCallback() public {
        vm.expectRevert(IPoolManager.AlreadyUnlocked.selector);
        v4Probe.run(DeepstateV4LifecycleProbe.Action.NestedUnlock, bob, _v4Key(), _v4Params(false, -1, _maxSqrtLimit()));

        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));
        vm.expectRevert(IPoolManager.CurrencyNotSettled.selector);
        v4Probe.run(
            DeepstateV4LifecycleProbe.Action.LeaveUnsettled, bob, _v4Key(), _v4Params(false, -6, _maxSqrtLimit())
        );
    }

    function test_V4LifecycleRejectsUnauthorizedLockerDuringUnlock() public {
        vm.expectRevert(IPoolManager.ManagerLocked.selector);
        v4Probe.run(
            DeepstateV4LifecycleProbe.Action.UnauthorizedLocker, bob, _v4Key(), _v4Params(false, -1, _maxSqrtLimit())
        );
    }

    function test_V4LifecycleCoversNativeSyncZeroDeltaAndInvalidNativeSettlement() public {
        v4Probe.run(DeepstateV4LifecycleProbe.Action.SyncNative, bob, _v4Key(), _v4Params(false, -1, _maxSqrtLimit()));
        v4Probe.run(DeepstateV4LifecycleProbe.Action.ZeroDelta, bob, _v4Key(), _v4Params(false, -1, _maxSqrtLimit()));
        v4Probe.run{value: 1}(
            DeepstateV4LifecycleProbe.Action.RoundTripPositiveDelta,
            bob,
            _v4Key(),
            _v4Params(false, -1, _maxSqrtLimit())
        );

        vm.expectRevert(IPoolManager.NonzeroNativeValue.selector);
        v4Probe.run{value: 1}(
            DeepstateV4LifecycleProbe.Action.NonzeroNativeValue, bob, _v4Key(), _v4Params(false, -1, _maxSqrtLimit())
        );
    }

    function test_V4LifecycleBlocksLockerReentryWhileSwapIsActive() public {
        engine.setPoolHookConfig(address(token0), address(token1), address(v4Probe), false, true);
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));

        v4Probe.armSwapReentry(_v4Key(), _v4Params(false, -1, _maxSqrtLimit()));
        v4Probe.run(
            DeepstateV4LifecycleProbe.Action.SettleForAndTake, bob, _v4Key(), _v4Params(false, -6, _maxSqrtLimit())
        );

        assertEq(v4Probe.reentrySelector(), DeepstateV1.ReentrantCall.selector);
    }

    function test_V4UnlockCannotReenterOrdinaryFill() public {
        V4ReentrantERC20 a = new V4ReentrantERC20("Reentrant A", "RA");
        V4ReentrantERC20 b = new V4ReentrantERC20("Reentrant B", "RB");
        V4ReentrantERC20 lower = address(a) < address(b) ? a : b;
        V4ReentrantERC20 upper = address(a) < address(b) ? b : a;
        DeepstateV1 localEngine = new DeepstateV1();

        lower.mint(alice, 5);
        vm.prank(alice);
        lower.approve(address(localEngine), type(uint256).max);
        lower.arm(address(localEngine), abi.encodeCall(IPoolManager.unlock, (bytes(""))));

        vm.prank(alice);
        localEngine.fill(_fillFor(lower, upper, _order(0, 5, 0), false, false, false));

        assertEq(lower.reentrySelector(), DeepstateV1.ReentrantCall.selector);
    }

    function test_V4SwapRequiresUnlockCallback() public {
        vm.expectRevert(IPoolManager.ManagerLocked.selector);
        engine.swap(_v4Key(), _v4Params(false, -1, _maxSqrtLimit()), "");
    }

    function test_V4SwapBlocksTokenCallbackReentrancy() public {
        V4ReentrantERC20 a = new V4ReentrantERC20("Reentrant A", "RA");
        V4ReentrantERC20 b = new V4ReentrantERC20("Reentrant B", "RB");
        RoutingTestERC20 lower = address(a) < address(b) ? a : b;
        RoutingTestERC20 upper = address(a) < address(b) ? b : a;
        V4ReentrantERC20 output = V4ReentrantERC20(address(lower));
        DeepstateV1 localEngine = new DeepstateV1();
        DeepstateV4Router localV4Router = new DeepstateV4Router(IPoolManager(address(localEngine)));

        lower.mint(alice, 5);
        upper.mint(bob, 5);
        vm.prank(alice);
        lower.approve(address(localEngine), type(uint256).max);
        vm.prank(bob);
        upper.approve(address(localV4Router), type(uint256).max);

        vm.prank(alice);
        localEngine.fill(_fillFor(lower, upper, _order(0, 5, 0), false, false, false));

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(lower)),
            currency1: Currency.wrap(address(upper)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        IPoolManager.SwapParams memory params = _v4Params(false, -5, _maxSqrtLimit());
        output.arm(address(localEngine), abi.encodeCall(DeepstateV1.swap, (key, params, bytes(""))));

        vm.prank(bob);
        BalanceDelta delta = localV4Router.swap(key, params, "");

        _assertDelta(delta, 5, -5);
        assertEq(output.reentrySelector(), IPoolManager.ManagerLocked.selector);
    }

    function test_V4SwapExactInputZeroForOne() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), true, false, false));

        uint256 bobBaseBefore = token0.balanceOf(bob);
        uint256 bobQuoteBefore = token1.balanceOf(bob);
        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(true, -6, _minSqrtLimit()), hex"1234");

        _assertDelta(delta, -6, 6);
        assertEq(token0.balanceOf(bob), bobBaseBefore - 6);
        assertEq(token1.balanceOf(bob), bobQuoteBefore + 6);
    }

    function test_V4SwapExactOutputZeroForOne() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), true, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(true, 6, _minSqrtLimit()), "");

        _assertDelta(delta, -6, 6);
    }

    function test_V4SwapExactInputOneForZero() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -6, _maxSqrtLimit()), "");

        _assertDelta(delta, 6, -6);
    }

    function test_V4SwapExactOutputOneForZero() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, 6, _maxSqrtLimit()), "");

        _assertDelta(delta, 6, -6);
    }

    function test_V4SwapPriceLimitStopsAtTickWithoutRestingRemainder() public {
        vm.startPrank(alice);
        engine.fill(_fill(0, _order(0, 5, 0), false, false, false));
        engine.fill(_fill(0, _order(1, 5, 0), false, false, false));
        vm.stopPrank();

        uint32 nonceBefore = engine.nextNonce(address(token0), address(token1), 0);
        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -10, uint160(1) << 96), "");

        _assertDelta(delta, 5, -5);
        assertEq(engine.nextNonce(address(token0), address(token1), 0), nonceBefore);
        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertNotEq(askRoot, bytes32(0));
    }

    function test_V4SwapZeroForOnePriceLimitIncludesBoundaryTickOnly() public {
        vm.startPrank(alice);
        engine.fill(_fill(0, _order(0, 5, 0), true, false, false));
        engine.fill(_fill(0, _order(-1, 5, 0), true, false, false));
        vm.stopPrank();

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(true, -10, uint160(1) << 96), "");

        _assertDelta(delta, -5, 5);
        (, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 0);
        assertNotEq(bidRoot, bytes32(0));
    }

    function test_V4SwapQuoteExactInputPartiallyFillsNonzeroTick() public {
        int32 tick = 100_000_000;
        uint160 quantity = 1_000;
        uint160 expectedFill = 400;
        uint256 quoteBudget = _quoteValue(tick, quantity, false) - _quoteValue(tick, quantity - expectedFill, false);

        vm.prank(alice);
        engine.fill(_fill(0, _order(tick, quantity, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -int256(quoteBudget), _maxSqrtLimit()), "");

        _assertDelta(delta, int128(uint128(expectedFill)), -int128(int256(quoteBudget)));
    }

    function test_V4SwapQuoteExactOutputPartiallyFillsNonzeroTick() public {
        int32 tick = 100_000_000;
        uint160 quantity = 1_000;
        uint160 expectedFill = 400;
        uint256 quoteTarget = _quoteValue(tick, quantity, true) - _quoteValue(tick, quantity - expectedFill, true);

        vm.prank(alice);
        engine.fill(_fill(0, _order(tick, quantity, 0), true, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(true, int256(quoteTarget), _minSqrtLimit()), "");

        _assertDelta(delta, -int128(uint128(expectedFill)), int128(int256(quoteTarget)));
    }

    function test_V4SwapQuoteBudgetPreservesMixedPricePriority() public {
        int32 bestTick = -100_000_000;
        int32 nextTick = 100_000_000;
        uint160 bestQuantity = 1_000;
        uint160 nextQuantity = 1_000;
        uint160 nextFill = 10;
        uint256 bestQuote = _quoteValue(bestTick, bestQuantity, false);
        uint256 nextQuote =
            _quoteValue(nextTick, nextQuantity, false) - _quoteValue(nextTick, nextQuantity - nextFill, false);

        vm.startPrank(alice);
        engine.fill(_fill(0, _order(nextTick, nextQuantity, 0), false, false, false));
        engine.fill(_fill(0, _order(bestTick, bestQuantity, 0), false, false, false));
        vm.stopPrank();

        vm.prank(bob);
        BalanceDelta delta =
            v4Router.swap(_v4Key(), _v4Params(false, -int256(bestQuote + nextQuote), _maxSqrtLimit()), "");

        _assertDelta(delta, int128(uint128(bestQuantity + nextFill)), -int128(int256(bestQuote + nextQuote)));
    }

    function test_V4SwapQuoteBudgetConsumesDirtySameTickSpine() public {
        int32 tick = 100_000_000;
        vm.startPrank(alice);
        engine.fill(_fill(0, _order(tick, 20, 0), false, false, false));
        engine.fill(_fill(0, _order(tick, 30, 0), false, false, false));
        vm.stopPrank();

        vm.prank(bob);
        v4Router.swap(_v4Key(), _v4Params(false, 10, _maxSqrtLimit()), "");

        uint256 quoteBudget = _quoteValue(tick, 10, false) + _quoteValue(tick, 30, false);
        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -int256(quoteBudget), _maxSqrtLimit()), "");

        _assertDelta(delta, 40, -int128(int256(quoteBudget)));
    }

    function test_V4SwapQuoteBudgetConsumesDirtyMixedTickSpine() public {
        int32 bestTick = 100_000_000;
        int32 nextTick = 100_000_001;
        vm.startPrank(alice);
        engine.fill(_fill(0, _order(bestTick, 20, 0), false, false, false));
        engine.fill(_fill(0, _order(nextTick, 30, 0), false, false, false));
        vm.stopPrank();

        vm.prank(bob);
        v4Router.swap(_v4Key(), _v4Params(false, 10, _maxSqrtLimit()), "");

        uint256 quoteBudget = _quoteValue(bestTick, 10, false) + _quoteValue(nextTick, 30, false);
        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -int256(quoteBudget), _maxSqrtLimit()), "");

        _assertDelta(delta, 40, -int128(int256(quoteBudget)));
    }

    function test_V4SwapQuoteBudgetConsumesWholeCleanBranch() public {
        vm.startPrank(alice);
        engine.fill(_fill(0, _order(0, 5, 0), false, false, false));
        engine.fill(_fill(0, _order(0, 5, 0), false, false, false));
        vm.stopPrank();

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -11, _maxSqrtLimit()), "");

        _assertDelta(delta, 10, -10);
    }

    function test_V4SwapQuoteBudgetStopsAfterPartiallyFillingBestBranchLeaf() public {
        vm.startPrank(alice);
        engine.fill(_fill(0, _order(1, 10, 0), false, false, false));
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));
        vm.stopPrank();

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -5, _maxSqrtLimit()), "");

        _assertDelta(delta, 5, -5);
        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertNotEq(askRoot, bytes32(0));
    }

    function test_V4SwapDirtyUniformBranchOutsidePriceLimitReturnsZero() public {
        vm.startPrank(alice);
        engine.fill(_fill(0, _order(1, 20, 0), false, false, false));
        engine.fill(_fill(0, _order(1, 30, 0), false, false, false));
        vm.stopPrank();

        vm.prank(bob);
        v4Router.swap(_v4Key(), _v4Params(false, 10, _maxSqrtLimit()), "");

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -10, uint160(1) << 96), "");

        _assertDelta(delta, 0, 0);
    }

    function test_V4SwapExecutesConfiguredTopOrderHook() public {
        RecordingHook hook = new RecordingHook();
        engine.setPoolHookConfig(address(token0), address(token1), address(hook), false, true);

        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 10, 0), false, false, false));
        uint256 callsBefore = hook.calls();

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, 5, _maxSqrtLimit()), "");

        _assertDelta(delta, 5, -5);
        assertEq(hook.calls(), callsBefore + 1);
        assertEq(hook.lastPoolId(), engine.poolId(address(token0), address(token1)));
        assertEq(hook.lastBookId(), engine.bookId(address(token0), address(token1), 0));
        assertEq(hook.lastToken(), address(token1));
    }

    function test_V4SwapPartialLiquidityReturnsActualDelta() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 5, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, 10, _maxSqrtLimit()), "");

        _assertDelta(delta, 5, -5);
    }

    function test_V4SwapExactOutputUsesPostFeeAmount() public {
        engine.setFeeConfig(feeRecipient, 100);
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 200, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, 100, _maxSqrtLimit()), "");

        _assertDelta(delta, 100, -101);
        assertEq(token0.balanceOf(feeRecipient), 1);
    }

    function test_V4SwapExactOutputUsesMinimumGrossAmount() public {
        engine.setFeeConfig(feeRecipient, 3);
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 4_000, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, 3_333, _maxSqrtLimit()), "");

        _assertDelta(delta, 3_333, -3_333);
        assertEq(token0.balanceOf(feeRecipient), 0);
    }

    function test_V4SwapExactQuoteOutputUsesPostFeeAmount() public {
        engine.setFeeConfig(feeRecipient, 100);
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 200, 0), true, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(true, 100, _minSqrtLimit()), "");

        _assertDelta(delta, -101, 100);
        assertEq(token1.balanceOf(feeRecipient), 1);
    }

    function test_V4SwapValidatesCanonicalKeyAmountLimitAndInitialization() public {
        PoolKey memory key = _v4Key();
        IPoolManager.SwapParams memory params = _v4Params(false, 1, _maxSqrtLimit());

        PoolKey memory reversed = PoolKey({
            currency0: key.currency1,
            currency1: key.currency0,
            fee: key.fee,
            tickSpacing: key.tickSpacing,
            hooks: key.hooks
        });
        vm.expectRevert(
            abi.encodeWithSelector(IPoolManager.CurrenciesOutOfOrderOrEqual.selector, address(token1), address(token0))
        );
        v4Router.swap(reversed, params, "");

        key.fee = 1;
        vm.expectRevert(IPoolManager.PoolNotInitialized.selector);
        v4Router.swap(key, params, "");
        key.fee = 0;
        key.tickSpacing = 2;
        vm.expectRevert(IPoolManager.PoolNotInitialized.selector);
        v4Router.swap(key, params, "");
        key.tickSpacing = 1;
        key.hooks = IHooks(address(1));
        vm.expectRevert(IPoolManager.PoolNotInitialized.selector);
        v4Router.swap(key, params, "");

        key.hooks = IHooks(address(0));
        params.amountSpecified = 0;
        vm.expectRevert(IPoolManager.SwapAmountCannotBeZero.selector);
        v4Router.swap(key, params, "");

        params.amountSpecified = 1;
        params.sqrtPriceLimitX96 = uint160(1) << 48;
        vm.expectRevert(abi.encodeWithSelector(DeepstateV1.PriceLimitOutOfBounds.selector, params.sqrtPriceLimitX96));
        v4Router.swap(key, params, "");
        params.sqrtPriceLimitX96 = uint160(1) << 144;
        vm.expectRevert(abi.encodeWithSelector(DeepstateV1.PriceLimitOutOfBounds.selector, params.sqrtPriceLimitX96));
        v4Router.swap(key, params, "");

        params.sqrtPriceLimitX96 = _maxSqrtLimit();
        vm.expectRevert(IPoolManager.PoolNotInitialized.selector);
        v4Router.swap(key, params, "");
    }

    function test_V4SwapInitializedBookWithoutOppositeLiquidityReturnsZero() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 5, 0), true, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -5, _maxSqrtLimit()), "");
        _assertDelta(delta, 0, 0);
    }

    function test_V4SwapHandlesInt256MinExactInputAsPartial() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 5, 0), true, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(true, type(int256).min, _minSqrtLimit()), "");
        _assertDelta(delta, -5, 5);
    }

    function test_V4SwapHandlesInt256MaxExactOutputWithFeeAsPartial() public {
        engine.setFeeConfig(feeRecipient, 100);
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, 5, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, type(int256).max, _maxSqrtLimit()), "");

        _assertDelta(delta, 5, -5);
    }

    function test_V4SwapRevertsWhenActualDeltaExceedsInt128() public {
        uint160 quantity = uint160(uint256(uint128(type(int128).max)) + 1);
        token0.mint(alice, quantity);

        vm.prank(alice);
        engine.fill(_fill(0, _order(0, quantity, 0), false, false, false));

        vm.prank(bob);
        vm.expectRevert(SafeCast.SafeCastOverflow.selector);
        v4Router.swap(_v4Key(), _v4Params(false, -int256(uint256(quantity)), _maxSqrtLimit()), "");

        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertNotEq(askRoot, bytes32(0));
    }

    function testFuzz_V4SwapQuoteExactInputInvertsLeafRounding(uint32 rawTick, uint160 rawQuantity, uint160 rawFill)
        public
    {
        int32 tick = int32(int256(uint256(bound(rawTick, 1, 500_000_000))));
        uint160 quantity = uint160(bound(rawQuantity, 1, 1_000_000));
        uint160 expectedFill = uint160(bound(rawFill, 1, quantity));
        uint256 quoteBudget = _quoteValue(tick, quantity, false) - _quoteValue(tick, quantity - expectedFill, false);
        token1.mint(bob, quoteBudget);

        vm.prank(alice);
        engine.fill(_fill(0, _order(tick, quantity, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, -int256(quoteBudget), _maxSqrtLimit()), "");

        _assertDelta(delta, int128(uint128(expectedFill)), -int128(int256(quoteBudget)));
    }

    function testFuzz_V4SwapExactOutputFeeGrossUpIsMinimal(uint16 rawFeeBps, uint160 rawTarget) public {
        uint16 feeBps = uint16(bound(rawFeeBps, 1, 100));
        uint160 target = uint160(bound(rawTarget, 1, 10_000));
        uint160 gross = target;
        while (uint256(gross) - uint256(gross) * feeBps / 10_000 < target) {
            ++gross;
        }

        engine.setFeeConfig(feeRecipient, feeBps);
        vm.prank(alice);
        engine.fill(_fill(0, _order(0, gross, 0), false, false, false));

        vm.prank(bob);
        BalanceDelta delta = v4Router.swap(_v4Key(), _v4Params(false, int256(uint256(target)), _maxSqrtLimit()), "");

        _assertDelta(delta, int128(uint128(target)), -int128(uint128(gross)));
        assertEq(token0.balanceOf(feeRecipient), uint256(gross) - target);
        if (gross != target) {
            uint256 prior = uint256(gross) - 1;
            assertLt(prior - prior * feeBps / 10_000, target);
        }
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

    function _v4Key() internal view returns (PoolKey memory key) {
        return _v4KeyFor(token0, token1);
    }

    function _v4KeyFor(RoutingTestERC20 lower, RoutingTestERC20 upper) internal pure returns (PoolKey memory key) {
        key = PoolKey({
            currency0: Currency.wrap(address(lower)),
            currency1: Currency.wrap(address(upper)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
    }

    function _v4Params(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96)
        internal
        pure
        returns (IPoolManager.SwapParams memory params)
    {
        params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: sqrtPriceLimitX96
        });
    }

    function _minSqrtLimit() internal pure returns (uint160) {
        return (uint160(1) << 48) + 1;
    }

    function _maxSqrtLimit() internal pure returns (uint160) {
        return (uint160(1) << 144) - 1;
    }

    function _v4LimitTickReference(uint160 sqrtPriceLimitX96, bool zeroForOne) internal pure returns (int32 tick) {
        uint256 limitQuote = _sqrtPriceQuoteAtMaxQuantity(sqrtPriceLimitX96);
        uint64 low;
        uint64 high = type(uint32).max;
        while (low < high) {
            uint64 mid = (low + high + 1) >> 1;
            // Search bounds prove `mid` fits in 32 bits.
            // forge-lint: disable-next-line(unsafe-typecast)
            int32 candidate = _tickFromOrderedKey(uint32(mid));
            if (_quoteValue(candidate, type(uint160).max, false) <= limitQuote) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }

        // Search bounds prove `low` fits in 32 bits.
        // forge-lint: disable-next-line(unsafe-typecast)
        tick = _tickFromOrderedKey(uint32(low));
        if (zeroForOne && tick != type(int32).max && _quoteValue(tick, type(uint160).max, false) < limitQuote) {
            unchecked {
                ++tick;
            }
        }
    }

    function _tickFromOrderedKey(uint32 key) internal pure returns (int32 tick) {
        uint32 raw = key ^ 0x80000000;
        assembly ("memory-safe") {
            tick := signextend(3, raw)
        }
    }

    function _sqrtPriceQuoteAtMaxQuantity(uint160 sqrtPriceX96) internal pure returns (uint256 quoteAmount) {
        uint256 sqrtPrice = uint256(sqrtPriceX96);
        uint256 squareLow;
        uint256 squareHigh;
        uint256 productLow;
        uint256 productHigh;
        uint256 quantity = type(uint160).max;
        assembly ("memory-safe") {
            squareLow := mul(sqrtPrice, sqrtPrice)
            let mm := mulmod(sqrtPrice, sqrtPrice, not(0))
            squareHigh := sub(mm, add(squareLow, lt(mm, squareLow)))

            productLow := mul(squareLow, quantity)
            mm := mulmod(squareLow, quantity, not(0))
            productHigh := sub(mm, add(productLow, lt(mm, productLow)))
        }

        unchecked {
            uint256 upper = productHigh + squareHigh * quantity;
            quoteAmount = (upper << 64) | (productLow >> 192);
        }
    }

    function _assertDelta(BalanceDelta delta, int128 expected0, int128 expected1) internal pure {
        int256 packed = BalanceDelta.unwrap(delta);
        int128 amount0;
        int128 amount1;
        assembly ("memory-safe") {
            amount0 := sar(128, packed)
            amount1 := signextend(15, packed)
        }
        assertEq(amount0, expected0);
        assertEq(amount1, expected1);
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
        token0.approve(address(v4Probe), type(uint256).max);
        token1.approve(address(v4Probe), type(uint256).max);
        token0.approve(address(v4Router), type(uint256).max);
        token1.approve(address(v4Router), type(uint256).max);
        token0.approve(address(officialV4Router), type(uint256).max);
        token1.approve(address(officialV4Router), type(uint256).max);
        vm.stopPrank();
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) internal pure returns (uint256 quoteAmount) {
        quoteAmount = QuoteMath.quoteValue(tick, quantity, roundUp);
    }
}
