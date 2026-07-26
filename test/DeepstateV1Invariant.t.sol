// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";
import {QuoteMath} from "./QuoteMath.sol";

contract MultiPoolInvariantERC20 is ERC20 {
    string private _name;

    constructor(string memory name_) {
        _name = name_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _name;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DeepstateV1MultiPoolHarness is DeepstateV1 {
    function forceNextNonce(address token0, address token1, uint256 epoch, uint32 nonce) external {
        bytes32 id = bookId(token0, token1, epoch);
        uint256 nonceAndFlags = books[id].nonceAndFlags;
        books[id].nonceAndFlags = (nonceAndFlags & ~uint256(type(uint32).max)) | uint256(nonce);
    }
}

contract MultiPoolRecordingHook {
    struct Call {
        bytes32 poolId;
        bytes32 bookId;
        address token;
        uint160 outgoingAmount;
        uint32 incomingNonce;
    }

    address public immutable ENGINE_ADDRESS;
    Call[] private _calls;

    constructor(address engine_) {
        ENGINE_ADDRESS = engine_;
    }

    function execute(bytes32 poolId, bytes32 bookId, address token, uint160 outgoingAmount, uint32 incomingNonce)
        external
    {
        require(msg.sender == ENGINE_ADDRESS, "only engine");
        _calls.push(
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
        return _calls.length;
    }

    function callAt(uint256 index)
        external
        view
        returns (bytes32 poolId, bytes32 bookId, address token, uint160 outgoingAmount, uint32 incomingNonce)
    {
        Call storage record = _calls[index];
        return (record.poolId, record.bookId, record.token, record.outgoingAmount, record.incomingNonce);
    }
}

contract MultiPoolRevertingHook {
    function execute(bytes32, bytes32, address, uint160, uint32) external pure {
        revert("hook failure");
    }
}

contract DeepstateV1MultiPoolHandler is Test {
    struct TrackedOrder {
        bytes32 bookId;
        bytes32 order;
        address owner;
        uint160 remaining;
        uint256 epoch;
        uint8 actorIndex;
        uint8 poolIndex;
        bool isBid;
        bool active;
    }

    struct TopOrder {
        bytes32 order;
        uint160 quantity;
        uint32 nonce;
        bool exists;
    }

    struct RestLog {
        bytes32 bookId;
        bytes32 order;
        address owner;
        bool isBid;
    }

    struct ExpectedHook {
        bytes32 poolId;
        bytes32 bookId;
        address token;
        uint160 outgoingAmount;
        uint32 incomingNonce;
    }

    struct AppliedLeg {
        int256 amount0;
        int256 amount1;
        uint256 restCursor;
        uint256 hookCount;
    }

    DeepstateV1MultiPoolHarness internal immutable ENGINE;
    MultiPoolInvariantERC20 internal immutable TOKEN0;
    MultiPoolInvariantERC20 internal immutable TOKEN1;
    MultiPoolInvariantERC20 internal immutable TOKEN2;
    MultiPoolRecordingHook internal immutable RECORDING_HOOK;
    MultiPoolRevertingHook internal immutable REVERTING_HOOK;

    uint256 internal constant INITIAL_BALANCE = type(uint216).max;
    uint160 internal constant MAX_ORDER_QUANTITY = 1e18;
    uint256 internal constant MAX_TRACKED_ORDERS = 128;
    int32 internal constant MIN_FUZZ_TICK = -100_000_000;
    int32 internal constant MAX_FUZZ_TICK = 100_000_000;
    address internal constant FEE_RECIPIENT = address(0xFEE);
    bytes32 internal constant ORDER_RESTED_TOPIC = keccak256("OrderRested(bytes32,bytes32,address,bool)");

    address[6] internal actors;
    uint256[3][6] internal expectedActorBalances;
    uint256[3] internal expectedFeeBalances;
    uint256[3] internal expectedEpochs;
    uint8[3] internal poolHookMasks;
    uint8[3] internal poolHookKinds;

    TrackedOrder[] internal trackedOrders;
    bytes32[] internal knownBooks;
    mapping(bytes32 bookId => bool known) internal isKnownBook;
    mapping(bytes32 bookId => uint8 poolIndex) internal knownBookPool;
    mapping(bytes32 bookId => uint8 mask) internal bookHookMasks;
    mapping(bytes32 orderId => address owner) internal expectedOrderOwner;
    mapping(bytes32 orderId => bool isBid) internal expectedOrderSide;

    address internal expectedFeeRecipient;
    uint16 internal expectedFeeBps;
    uint256 public validatedHookCalls;
    uint256 public unexpectedFillReverts;
    uint256 public unexpectedRouteReverts;
    uint256 public unexpectedCancelReverts;
    bytes4 public lastUnexpectedRevert;
    uint256 public singleFillCalls;
    uint256 public routeCalls;
    uint256 public cancelCalls;
    uint256 public rotationCalls;

    constructor(
        MultiPoolInvariantERC20 token0_,
        MultiPoolInvariantERC20 token1_,
        MultiPoolInvariantERC20 token2_,
        DeepstateV1MultiPoolHarness engine_,
        MultiPoolRecordingHook recordingHook_,
        MultiPoolRevertingHook revertingHook_
    ) {
        TOKEN0 = token0_;
        TOKEN1 = token1_;
        TOKEN2 = token2_;
        ENGINE = engine_;
        RECORDING_HOOK = recordingHook_;
        REVERTING_HOOK = revertingHook_;

        actors = [address(0xA11CE), address(0xB0B), address(0xCA201), address(0xD00D), address(0xE1EE), address(0xF00D)];

        for (uint256 i; i < actors.length; ++i) {
            for (uint8 tokenIndex; tokenIndex < 3; ++tokenIndex) {
                MultiPoolInvariantERC20 token = _token(tokenIndex);
                token.mint(actors[i], INITIAL_BALANCE);
                expectedActorBalances[i][tokenIndex] = INITIAL_BALANCE;
                vm.prank(actors[i]);
                token.approve(address(ENGINE), type(uint256).max);
            }
        }

        for (uint8 poolIndex; poolIndex < 3; ++poolIndex) {
            (address lower, address upper,,) = _pair(poolIndex);
            _rememberBook(ENGINE.bookId(lower, upper, 0), poolIndex);
        }
    }

    function placeBid(
        uint256 poolSeed,
        uint256 actorSeed,
        int32 tickSeed,
        uint256 quantitySeed,
        uint256 epochSeed,
        bool noRest
    ) external {
        _place(poolSeed, actorSeed, tickSeed, quantitySeed, epochSeed, true, noRest);
    }

    function placeAsk(
        uint256 poolSeed,
        uint256 actorSeed,
        int32 tickSeed,
        uint256 quantitySeed,
        uint256 epochSeed,
        bool noRest
    ) external {
        _place(poolSeed, actorSeed, tickSeed, quantitySeed, epochSeed, false, noRest);
    }

    function routeForward(
        uint256 actorSeed,
        int32 firstTickSeed,
        int32 secondTickSeed,
        uint256 firstQuantitySeed,
        uint256 secondQuantitySeed,
        uint256 flags
    ) external {
        DeepstateV1.FillParams[] memory fills = new DeepstateV1.FillParams[](2);
        fills[0] = _routeParam(0, firstTickSeed, firstQuantitySeed, true, flags & 1 != 0, flags >> 2);
        fills[1] = _routeParam(1, secondTickSeed, secondQuantitySeed, true, flags & 2 != 0, flags >> 3);
        _performRoute(uint8(bound(actorSeed, 0, actors.length - 1)), fills);
    }

    function routeReverse(
        uint256 actorSeed,
        int32 firstTickSeed,
        int32 secondTickSeed,
        uint256 firstQuantitySeed,
        uint256 secondQuantitySeed,
        uint256 flags
    ) external {
        DeepstateV1.FillParams[] memory fills = new DeepstateV1.FillParams[](2);
        fills[0] = _routeParam(0, firstTickSeed, firstQuantitySeed, false, flags & 1 != 0, flags >> 2);
        fills[1] = _routeParam(1, secondTickSeed, secondQuantitySeed, false, flags & 2 != 0, flags >> 3);
        _performRoute(uint8(bound(actorSeed, 0, actors.length - 1)), fills);
    }

    function cancel(uint256 orderSeed) external {
        uint256 length = trackedOrders.length;
        if (length == 0) return;

        uint256 start = bound(orderSeed, 0, length - 1);
        for (uint256 offset; offset < length; ++offset) {
            uint256 index = (start + offset) % length;
            if (trackedOrders[index].active) {
                _cancel(index);
                return;
            }
        }
    }

    function configureFee(uint256 modeSeed, uint16 bpsSeed) external {
        if (modeSeed % 3 == 0) {
            ENGINE.setFeeConfig(address(0), 0);
            expectedFeeRecipient = address(0);
            expectedFeeBps = 0;
        } else {
            uint16 bps = uint16(bound(bpsSeed, 0, 100));
            ENGINE.setFeeConfig(FEE_RECIPIENT, bps);
            expectedFeeRecipient = FEE_RECIPIENT;
            expectedFeeBps = bps;
        }
    }

    function configureHook(uint256 poolSeed, uint256 modeSeed) external {
        uint8 poolIndex = uint8(bound(poolSeed, 0, 2));
        uint256 mode = modeSeed % 7;
        uint8 mask;
        uint8 kind;
        address hook;

        if (mode != 0) {
            mask = uint8(((mode - 1) % 3) + 1);
            kind = mode <= 3 ? 1 : 2;
            hook = kind == 1 ? address(RECORDING_HOOK) : address(REVERTING_HOOK);
        }

        (address lower, address upper,,) = _pair(poolIndex);
        ENGINE.setPoolHookConfig(lower, upper, hook, mask & 1 != 0, mask & 2 != 0);

        poolHookMasks[poolIndex] = mask;
        poolHookKinds[poolIndex] = kind;
        bytes32 id = ENGINE.bookId(lower, upper, expectedEpochs[poolIndex]);
        bookHookMasks[id] = mask;
        _rememberBook(id, poolIndex);
    }

    function rotatePool(uint256 poolSeed, uint256 actorSeed, bool isBid) external {
        if (trackedOrders.length >= MAX_TRACKED_ORDERS) return;

        uint8 poolIndex = uint8(bound(poolSeed, 0, 2));
        uint8 actorIndex = uint8(bound(actorSeed, 0, actors.length - 1));
        uint256 oldEpoch = expectedEpochs[poolIndex];
        (address lower, address upper,,) = _pair(poolIndex);
        bytes32 oldBook = ENGINE.bookId(lower, upper, oldEpoch);

        ENGINE.forceNextNonce(lower, upper, oldEpoch, 2);
        int32 tick = isBid ? type(int32).min : type(int32).max;
        DeepstateV1.FillParams memory params = _fillParams(poolIndex, oldEpoch, tick, 1, isBid, false);
        _performSingle(actorIndex, params);
        if (unexpectedFillReverts != 0) return;

        uint256 nextEpoch = ENGINE.poolEpoch(ENGINE.poolId(lower, upper));
        assertEq(nextEpoch, oldEpoch + 1, "rotation epoch");
        expectedEpochs[poolIndex] = nextEpoch;
        bookHookMasks[oldBook] = 0;

        bytes32 nextBook = ENGINE.bookId(lower, upper, nextEpoch);
        bookHookMasks[nextBook] = poolHookMasks[poolIndex];
        _rememberBook(nextBook, poolIndex);
        ++rotationCalls;
    }

    function actorCount() external pure returns (uint256) {
        return 6;
    }

    function actorAt(uint256 index) external view returns (address) {
        return actors[index];
    }

    function tokenAt(uint256 index) external view returns (address) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return address(_token(uint8(index)));
    }

    function expectedActorBalance(uint256 actorIndex, uint256 tokenIndex) external view returns (uint256) {
        return expectedActorBalances[actorIndex][tokenIndex];
    }

    function expectedFeeBalance(uint256 tokenIndex) external view returns (uint256) {
        return expectedFeeBalances[tokenIndex];
    }

    function expectedEngineBalance(uint256 tokenIndex) external view returns (uint256 amount) {
        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage tracked = trackedOrders[i];
            if (!tracked.active) continue;

            (,, uint8 lowerIndex, uint8 upperIndex) = _pair(tracked.poolIndex);
            uint160 original = _quantity(tracked.order);
            uint160 filled = original - tracked.remaining;
            int32 tick = _tick(tracked.order);

            if (tracked.isBid) {
                if (tokenIndex == lowerIndex) amount += filled;
                if (tokenIndex == upperIndex) amount += _quoteValue(tick, tracked.remaining, true);
            } else {
                if (tokenIndex == lowerIndex) amount += tracked.remaining;
                if (tokenIndex == upperIndex) {
                    amount += _quoteValue(tick, original, false) - _quoteValue(tick, tracked.remaining, false);
                }
            }
        }
    }

    function expectedSupply(uint256) external pure returns (uint256) {
        return INITIAL_BALANCE * 6;
    }

    function orderCount() external view returns (uint256) {
        return trackedOrders.length;
    }

    function orderAt(uint256 index)
        external
        view
        returns (
            bytes32 bookId,
            bytes32 order,
            address owner,
            uint160 remaining,
            uint256 epoch,
            uint8 poolIndex,
            bool isBid,
            bool active
        )
    {
        TrackedOrder storage tracked = trackedOrders[index];
        return (
            tracked.bookId,
            tracked.order,
            tracked.owner,
            tracked.remaining,
            tracked.epoch,
            tracked.poolIndex,
            tracked.isBid,
            tracked.active
        );
    }

    function knownBookCount() external view returns (uint256) {
        return knownBooks.length;
    }

    function knownBookAt(uint256 index) external view returns (bytes32 bookId, uint8 poolIndex) {
        bookId = knownBooks[index];
        poolIndex = knownBookPool[bookId];
    }

    function expectedOwnerAt(bytes32 id, bytes32 order) external view returns (address) {
        return expectedOrderOwner[_orderId(id, order)];
    }

    function expectedSideAt(bytes32 id, bytes32 order) external view returns (bool) {
        return expectedOrderSide[_orderId(id, order)];
    }

    function expectedEpoch(uint256 poolIndex) external view returns (uint256) {
        return expectedEpochs[poolIndex];
    }

    function expectedPoolHook(uint256 poolIndex) external view returns (address hook, uint8 mask) {
        uint8 kind = poolHookKinds[poolIndex];
        hook = kind == 1 ? address(RECORDING_HOOK) : kind == 2 ? address(REVERTING_HOOK) : address(0);
        mask = poolHookMasks[poolIndex];
    }

    function expectedFeeConfig() external view returns (address recipient, uint16 bps) {
        return (expectedFeeRecipient, expectedFeeBps);
    }

    function modelTop(bytes32 id, bool isBid)
        external
        view
        returns (bytes32 order, uint160 quantity, uint32 nonce, bool exists)
    {
        TopOrder memory top = _top(id, isBid);
        return (top.order, top.quantity, top.nonce, top.exists);
    }

    function _place(
        uint256 poolSeed,
        uint256 actorSeed,
        int32 tickSeed,
        uint256 quantitySeed,
        uint256 epochSeed,
        bool isBid,
        bool noRest
    ) private {
        uint8 poolIndex = uint8(bound(poolSeed, 0, 2));
        uint8 actorIndex = uint8(bound(actorSeed, 0, actors.length - 1));
        uint256 epoch = _selectedEpoch(poolIndex, epochSeed);
        int32 tick = int32(bound(tickSeed, MIN_FUZZ_TICK, MAX_FUZZ_TICK));
        uint160 quantity = uint160(bound(quantitySeed, 1, uint256(MAX_ORDER_QUANTITY)));

        (address lower, address upper,,) = _pair(poolIndex);
        if (ENGINE.nextNonce(lower, upper, epoch) == 0) noRest = false;
        if (trackedOrders.length >= MAX_TRACKED_ORDERS) noRest = true;
        if (noRest && ENGINE.nextNonce(lower, upper, epoch) == 0) return;

        _performSingle(actorIndex, _fillParams(poolIndex, epoch, tick, quantity, isBid, noRest));
    }

    function _routeParam(
        uint8 poolIndex,
        int32 tickSeed,
        uint256 quantitySeed,
        bool isBid,
        bool noRest,
        uint256 epochSeed
    ) private view returns (DeepstateV1.FillParams memory params) {
        uint256 epoch = _selectedEpoch(poolIndex, epochSeed);
        int32 tick = int32(bound(tickSeed, MIN_FUZZ_TICK, MAX_FUZZ_TICK));
        uint160 quantity = uint160(bound(quantitySeed, 1, uint256(MAX_ORDER_QUANTITY)));
        (address lower, address upper,,) = _pair(poolIndex);
        if (ENGINE.nextNonce(lower, upper, epoch) == 0) noRest = false;
        if (trackedOrders.length >= MAX_TRACKED_ORDERS) noRest = true;
        params = _fillParams(poolIndex, epoch, tick, quantity, isBid, noRest);
    }

    function _performSingle(uint8 actorIndex, DeepstateV1.FillParams memory params) private {
        uint256 hookStart = RECORDING_HOOK.callCount();
        vm.recordLogs();
        vm.prank(actors[actorIndex]);
        try ENGINE.fill(params) returns (bytes32 restingOrder) {
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (RestLog[] memory rests, uint256 restCount) = _restLogs(entries, actors[actorIndex]);
            ExpectedHook[] memory expectedHooks = new ExpectedHook[](3);
            AppliedLeg memory applied = _applyLeg(params, actorIndex, rests, 0, expectedHooks, 0);

            assertEq(applied.restCursor, restCount, "single rest log count");
            if (restCount == 0) assertEq(restingOrder, bytes32(0), "single unexpected return");
            else assertEq(restingOrder, rests[0].order, "single resting return");

            (,, uint8 lowerIndex, uint8 upperIndex) = _pair(_poolIndex(params.token0, params.token1));
            _applyActorDelta(actorIndex, lowerIndex, applied.amount0);
            _applyActorDelta(actorIndex, upperIndex, applied.amount1);
            _assertHookCalls(hookStart, expectedHooks, applied.hookCount);
            ++singleFillCalls;
        } catch (bytes memory reason) {
            vm.getRecordedLogs();
            ++unexpectedFillReverts;
            _recordUnexpected(reason);
        }
    }

    function _performRoute(uint8 actorIndex, DeepstateV1.FillParams[] memory fills) private {
        uint256 hookStart = RECORDING_HOOK.callCount();
        vm.recordLogs();
        vm.prank(actors[actorIndex]);
        try ENGINE.fillRoute(fills) {
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (RestLog[] memory rests, uint256 restCount) = _restLogs(entries, actors[actorIndex]);
            ExpectedHook[] memory expectedHooks = new ExpectedHook[](fills.length * 3);
            int256[3] memory deltas;
            uint256 restCursor;
            uint256 hookCount;

            for (uint256 i; i < fills.length; ++i) {
                AppliedLeg memory applied = _applyLeg(fills[i], actorIndex, rests, restCursor, expectedHooks, hookCount);
                restCursor = applied.restCursor;
                hookCount = applied.hookCount;
                (,, uint8 lowerIndex, uint8 upperIndex) = _pair(_poolIndex(fills[i].token0, fills[i].token1));
                deltas[lowerIndex] += applied.amount0;
                deltas[upperIndex] += applied.amount1;
            }

            assertEq(restCursor, restCount, "route rest log count");
            for (uint8 tokenIndex; tokenIndex < 3; ++tokenIndex) {
                _applyActorDelta(actorIndex, tokenIndex, deltas[tokenIndex]);
            }
            _assertHookCalls(hookStart, expectedHooks, hookCount);
            ++routeCalls;
        } catch (bytes memory reason) {
            vm.getRecordedLogs();
            ++unexpectedRouteReverts;
            _recordUnexpected(reason);
        }
    }

    function _applyLeg(
        DeepstateV1.FillParams memory params,
        uint8 actorIndex,
        RestLog[] memory rests,
        uint256 restCursor,
        ExpectedHook[] memory expectedHooks,
        uint256 hookCount
    ) private returns (AppliedLeg memory applied) {
        uint8 poolIndex = _poolIndex(params.token0, params.token1);
        bytes32 routedBook = ENGINE.bookId(params.token0, params.token1, params.epoch);
        TopOrder memory beforeMatched = _top(routedBook, !params.isBid);
        (uint160 remaining, uint160 baseFilled, uint256 quoteAmount) =
            _matchModel(routedBook, params.isBid, _tick(params.order), _quantity(params.order));
        TopOrder memory afterMatched = _top(routedBook, !params.isBid);
        hookCount = _appendHookIfNeeded(
            expectedHooks, hookCount, poolIndex, routedBook, !params.isBid, beforeMatched, afterMatched
        );

        bool restAllowed = !params.noRest && params.epoch >= expectedEpochs[poolIndex];

        if (remaining != 0 && restAllowed) {
            assertLt(restCursor, rests.length, "missing rest log");
            RestLog memory rested = rests[restCursor++];
            assertEq(rested.owner, actors[actorIndex], "rest owner");
            assertEq(rested.isBid, params.isBid, "rest side");
            assertEq(_tick(rested.order), _tick(params.order), "rest tick");
            assertEq(_quantity(rested.order), remaining, "rest quantity");
            assertEq(uint32(uint256(rested.order) >> 32), 0, "rest correction");
            assertTrue(
                rested.bookId == routedBook || rested.bookId == ENGINE.activeBookId(params.token0, params.token1),
                "rest book scope"
            );

            TopOrder memory beforeRest = _top(rested.bookId, params.isBid);
            _trackRest(poolIndex, params.epoch, actorIndex, rested);
            TopOrder memory afterRest = _top(rested.bookId, params.isBid);
            hookCount = _appendHookIfNeeded(
                expectedHooks, hookCount, poolIndex, rested.bookId, params.isBid, beforeRest, afterRest
            );
        }

        uint256 feeAmount;
        if (params.isBid) {
            applied.amount0 = int256(uint256(baseFilled));
            // Model bounds keep every quote below `int256.max`, matching production validation.
            // forge-lint: disable-next-line(unsafe-typecast)
            applied.amount1 = -int256(quoteAmount);
            if (remaining != 0 && restAllowed) {
                applied.amount1 -= int256(_quoteValue(_tick(params.order), remaining, true));
            }
            if (expectedFeeRecipient != address(0) && expectedFeeBps != 0) {
                feeAmount = _feeAmount(baseFilled, expectedFeeBps);
                // forge-lint: disable-next-line(unsafe-typecast)
                applied.amount0 -= int256(feeAmount);
                (,, uint8 lowerIndex,) = _pair(poolIndex);
                expectedFeeBalances[lowerIndex] += feeAmount;
            }
        } else {
            applied.amount0 = -int256(uint256(baseFilled));
            // forge-lint: disable-next-line(unsafe-typecast)
            applied.amount1 = int256(quoteAmount);
            if (remaining != 0 && restAllowed) applied.amount0 -= int256(uint256(remaining));
            if (expectedFeeRecipient != address(0) && expectedFeeBps != 0) {
                feeAmount = _feeAmount(quoteAmount, expectedFeeBps);
                // forge-lint: disable-next-line(unsafe-typecast)
                applied.amount1 -= int256(feeAmount);
                (,,, uint8 upperIndex) = _pair(poolIndex);
                expectedFeeBalances[upperIndex] += feeAmount;
            }
        }

        applied.restCursor = restCursor;
        applied.hookCount = hookCount;
    }

    function _cancel(uint256 index) private {
        TrackedOrder storage tracked = trackedOrders[index];
        (address lower, address upper, uint8 lowerIndex, uint8 upperIndex) = _pair(tracked.poolIndex);
        TopOrder memory beforeTop = _top(tracked.bookId, tracked.isBid);
        (uint256 expectedBase, uint256 expectedQuote) = _cancelAmounts(tracked);
        uint256 hookStart = RECORDING_HOOK.callCount();

        vm.prank(tracked.owner);
        try ENGINE.cancel(lower, upper, tracked.epoch, tracked.order) returns (
            uint256 baseAmount, uint256 quoteAmount
        ) {
            assertEq(baseAmount, expectedBase, "cancel base");
            assertEq(quoteAmount, expectedQuote, "cancel quote");

            uint8 actorIndex = tracked.actorIndex;
            bytes32 id = _orderId(tracked.bookId, tracked.order);
            tracked.active = false;
            tracked.remaining = 0;
            delete expectedOrderOwner[id];
            delete expectedOrderSide[id];
            expectedActorBalances[actorIndex][lowerIndex] += baseAmount;
            expectedActorBalances[actorIndex][upperIndex] += quoteAmount;

            TopOrder memory afterTop = _top(tracked.bookId, tracked.isBid);
            ExpectedHook[] memory expectedHooks = new ExpectedHook[](1);
            uint256 hookCount = _appendHookIfNeeded(
                expectedHooks, 0, tracked.poolIndex, tracked.bookId, tracked.isBid, beforeTop, afterTop
            );
            _assertHookCalls(hookStart, expectedHooks, hookCount);
            ++cancelCalls;
        } catch (bytes memory reason) {
            ++unexpectedCancelReverts;
            _recordUnexpected(reason);
        }
    }

    function _matchModel(bytes32 id, bool incomingIsBid, int32 limitTick, uint160 quantity)
        private
        returns (uint160 remaining, uint160 baseFilled, uint256 quoteAmount)
    {
        remaining = quantity;
        while (remaining != 0) {
            (uint256 index, bool found) = _bestMatch(id, incomingIsBid, limitTick);
            if (!found) break;

            TrackedOrder storage resting = trackedOrders[index];
            uint160 oldRemaining = resting.remaining;
            uint160 fillQuantity = remaining < oldRemaining ? remaining : oldRemaining;
            uint160 nextRemaining = oldRemaining - fillQuantity;
            quoteAmount += _quoteValue(_tick(resting.order), oldRemaining, resting.isBid)
            - _quoteValue(_tick(resting.order), nextRemaining, resting.isBid);
            resting.remaining = nextRemaining;
            remaining -= fillQuantity;
            baseFilled += fillQuantity;
        }
    }

    function _bestMatch(bytes32 id, bool incomingIsBid, int32 limitTick)
        private
        view
        returns (uint256 bestIndex, bool found)
    {
        int32 bestTick;
        uint32 bestNonce;

        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage candidate = trackedOrders[i];
            if (
                !candidate.active || candidate.bookId != id || candidate.isBid == incomingIsBid
                    || candidate.remaining == 0
            ) continue;

            int32 candidateTick = _tick(candidate.order);
            if (incomingIsBid) {
                if (candidateTick > limitTick) continue;
                if (
                    found
                        && (candidateTick > bestTick
                            || candidateTick == bestTick
                            && _nonce(candidate.order) <= bestNonce)
                ) continue;
            } else {
                if (candidateTick < limitTick) continue;
                if (
                    found
                        && (candidateTick < bestTick
                            || candidateTick == bestTick
                            && _nonce(candidate.order) <= bestNonce)
                ) continue;
            }

            found = true;
            bestIndex = i;
            bestTick = candidateTick;
            bestNonce = _nonce(candidate.order);
        }
    }

    function _trackRest(uint8 poolIndex, uint256 routedEpoch, uint8 actorIndex, RestLog memory rested) private {
        uint256 epoch = routedEpoch;
        (address lower, address upper,,) = _pair(poolIndex);
        if (rested.bookId != ENGINE.bookId(lower, upper, routedEpoch)) {
            epoch = ENGINE.poolEpoch(ENGINE.poolId(lower, upper));
        }

        trackedOrders.push(
            TrackedOrder({
                bookId: rested.bookId,
                order: rested.order,
                owner: rested.owner,
                remaining: _quantity(rested.order),
                epoch: epoch,
                actorIndex: actorIndex,
                poolIndex: poolIndex,
                isBid: rested.isBid,
                active: true
            })
        );
        bytes32 id = _orderId(rested.bookId, rested.order);
        expectedOrderOwner[id] = rested.owner;
        expectedOrderSide[id] = rested.isBid;
        _rememberBook(rested.bookId, poolIndex);
    }

    function _top(bytes32 id, bool isBid) private view returns (TopOrder memory top) {
        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage candidate = trackedOrders[i];
            if (!candidate.active || candidate.bookId != id || candidate.isBid != isBid || candidate.remaining == 0) {
                continue;
            }

            if (!top.exists || _isBetter(candidate.order, top.order, isBid)) {
                top = TopOrder({
                    order: candidate.order, quantity: candidate.remaining, nonce: _nonce(candidate.order), exists: true
                });
            }
        }
    }

    function _isBetter(bytes32 candidate, bytes32 current, bool isBid) private pure returns (bool) {
        int32 candidateTick = _tick(candidate);
        int32 currentTick = _tick(current);
        if (candidateTick != currentTick) return isBid ? candidateTick > currentTick : candidateTick < currentTick;
        return _nonce(candidate) > _nonce(current);
    }

    function _appendHookIfNeeded(
        ExpectedHook[] memory expectedHooks,
        uint256 hookCount,
        uint8 poolIndex,
        bytes32 id,
        bool isBid,
        TopOrder memory beforeTop,
        TopOrder memory afterTop
    ) private view returns (uint256) {
        if (!_topChanged(beforeTop, afterTop)) return hookCount;
        uint8 sideFlag = isBid ? 1 : 2;
        if (bookHookMasks[id] & sideFlag == 0 || poolHookKinds[poolIndex] != 1) return hookCount;

        (address lower, address upper,,) = _pair(poolIndex);
        expectedHooks[hookCount] = ExpectedHook({
            poolId: ENGINE.poolId(lower, upper),
            bookId: id,
            token: isBid ? lower : upper,
            outgoingAmount: beforeTop.exists ? beforeTop.quantity : 0,
            incomingNonce: afterTop.exists ? afterTop.nonce : 0
        });
        return hookCount + 1;
    }

    function _assertHookCalls(uint256 start, ExpectedHook[] memory expectedHooks, uint256 expectedCount) private {
        uint256 end = RECORDING_HOOK.callCount();
        assertEq(end - start, expectedCount, "hook call count");

        for (uint256 i; i < expectedCount; ++i) {
            (bytes32 pid, bytes32 id, address token, uint160 outgoingAmount, uint32 incomingNonce) =
                RECORDING_HOOK.callAt(start + i);
            ExpectedHook memory expected = expectedHooks[i];
            assertEq(pid, expected.poolId, "hook pool");
            assertEq(id, expected.bookId, "hook book");
            assertEq(token, expected.token, "hook token");
            assertEq(outgoingAmount, expected.outgoingAmount, "hook outgoing");
            assertEq(incomingNonce, expected.incomingNonce, "hook incoming");
        }
        validatedHookCalls = end;
    }

    function _topChanged(TopOrder memory beforeTop, TopOrder memory afterTop) private pure returns (bool) {
        if (beforeTop.exists != afterTop.exists) return true;
        if (!beforeTop.exists) return false;
        return beforeTop.nonce != afterTop.nonce || beforeTop.quantity != afterTop.quantity;
    }

    function _restLogs(Vm.Log[] memory entries, address actor)
        private
        view
        returns (RestLog[] memory rests, uint256 count)
    {
        rests = new RestLog[](entries.length);
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];
            if (entry.emitter != address(ENGINE) || entry.topics.length == 0 || entry.topics[0] != ORDER_RESTED_TOPIC) {
                continue;
            }
            (bytes32 id, bytes32 order, address owner, bool isBid) =
                abi.decode(entry.data, (bytes32, bytes32, address, bool));
            assertEq(owner, actor, "rest log actor");
            rests[count++] = RestLog({bookId: id, order: order, owner: owner, isBid: isBid});
        }
    }

    function _cancelAmounts(TrackedOrder storage tracked)
        private
        view
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        uint160 original = _quantity(tracked.order);
        uint160 filled = original - tracked.remaining;
        int32 tick = _tick(tracked.order);
        if (tracked.isBid) {
            baseAmount = filled;
            quoteAmount = _quoteValue(tick, tracked.remaining, true);
        } else {
            baseAmount = tracked.remaining;
            quoteAmount = _quoteValue(tick, original, false) - _quoteValue(tick, tracked.remaining, false);
        }
    }

    function _applyActorDelta(uint8 actorIndex, uint8 tokenIndex, int256 delta) private {
        uint256 current = expectedActorBalances[actorIndex][tokenIndex];
        if (delta >= 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            expectedActorBalances[actorIndex][tokenIndex] = current + uint256(delta);
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            expectedActorBalances[actorIndex][tokenIndex] = current - uint256(-delta);
        }
    }

    function _selectedEpoch(uint8 poolIndex, uint256 seed) private view returns (uint256 epoch) {
        epoch = expectedEpochs[poolIndex];
        if (epoch != 0 && seed % 4 == 0) --epoch;
    }

    function _fillParams(uint8 poolIndex, uint256 epoch, int32 tick, uint160 quantity, bool isBid, bool noRest)
        private
        view
        returns (DeepstateV1.FillParams memory params)
    {
        (address lower, address upper,,) = _pair(poolIndex);
        params = DeepstateV1.FillParams({
            token0: lower,
            token1: upper,
            epoch: epoch,
            order: _pack(tick, quantity, 0),
            isBid: isBid,
            noRest: noRest,
            fillOrKill: false
        });
    }

    function _pair(uint8 poolIndex)
        private
        view
        returns (address lower, address upper, uint8 lowerIndex, uint8 upperIndex)
    {
        if (poolIndex == 0) return (address(TOKEN0), address(TOKEN1), 0, 1);
        if (poolIndex == 1) return (address(TOKEN1), address(TOKEN2), 1, 2);
        return (address(TOKEN0), address(TOKEN2), 0, 2);
    }

    function _poolIndex(address lower, address upper) private view returns (uint8) {
        if (lower == address(TOKEN0) && upper == address(TOKEN1)) return 0;
        if (lower == address(TOKEN1) && upper == address(TOKEN2)) return 1;
        assertEq(lower, address(TOKEN0), "pool lower");
        assertEq(upper, address(TOKEN2), "pool upper");
        return 2;
    }

    function _token(uint8 tokenIndex) private view returns (MultiPoolInvariantERC20) {
        if (tokenIndex == 0) return TOKEN0;
        if (tokenIndex == 1) return TOKEN1;
        return TOKEN2;
    }

    function _rememberBook(bytes32 id, uint8 poolIndex) private {
        if (isKnownBook[id]) return;
        isKnownBook[id] = true;
        knownBookPool[id] = poolIndex;
        knownBooks.push(id);
    }

    function _recordUnexpected(bytes memory reason) private {
        if (reason.length >= 4) {
            // forge-lint: disable-next-line(unsafe-typecast)
            lastUnexpectedRevert = bytes4(reason);
        }
    }

    function _feeAmount(uint256 amount, uint16 bps) private pure returns (uint256) {
        // Mirrors production's overflow-safe quotient/remainder decomposition exactly.
        // forge-lint: disable-next-line(divide-before-multiply)
        return (amount / 10_000) * uint256(bps) + ((amount % 10_000) * uint256(bps)) / 10_000;
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) private pure returns (uint256) {
        return QuoteMath.quoteValue(tick, quantity, roundUp);
    }

    function _orderId(bytes32 id, bytes32 order) private pure returns (bytes32) {
        return keccak256(abi.encode(id, order));
    }

    function _pack(int32 tick, uint160 quantity, uint32 nonce) private pure returns (bytes32) {
        // Reinterpreting the signed tick preserves its exact two's-complement field bits.
        // forge-lint: disable-next-line(unsafe-typecast)
        return bytes32((uint256(uint32(tick)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }

    function _tick(bytes32 order) private pure returns (int32) {
        return int32(uint32(uint256(order) >> 224));
    }

    function _quantity(bytes32 order) private pure returns (uint160) {
        return uint160((uint256(order) >> 64) & ((uint256(1) << 160) - 1));
    }

    function _nonce(bytes32 order) private pure returns (uint32) {
        return uint32(uint256(order));
    }
}

contract DeepstateV1MultiPoolInvariantTest is StdInvariant, Test {
    DeepstateV1MultiPoolHarness internal engine;
    DeepstateV1MultiPoolHandler internal handler;
    MultiPoolRecordingHook internal recordingHook;
    MultiPoolRevertingHook internal revertingHook;
    MultiPoolInvariantERC20 internal token0;
    MultiPoolInvariantERC20 internal token1;
    MultiPoolInvariantERC20 internal token2;

    function setUp() public {
        MultiPoolInvariantERC20 a = new MultiPoolInvariantERC20("A");
        MultiPoolInvariantERC20 b = new MultiPoolInvariantERC20("B");
        MultiPoolInvariantERC20 c = new MultiPoolInvariantERC20("C");
        address[3] memory sorted = [address(a), address(b), address(c)];
        for (uint256 i; i < 2; ++i) {
            for (uint256 j = i + 1; j < 3; ++j) {
                if (sorted[j] < sorted[i]) (sorted[i], sorted[j]) = (sorted[j], sorted[i]);
            }
        }
        token0 = MultiPoolInvariantERC20(sorted[0]);
        token1 = MultiPoolInvariantERC20(sorted[1]);
        token2 = MultiPoolInvariantERC20(sorted[2]);

        engine = new DeepstateV1MultiPoolHarness();
        recordingHook = new MultiPoolRecordingHook(address(engine));
        revertingHook = new MultiPoolRevertingHook();
        handler = new DeepstateV1MultiPoolHandler(token0, token1, token2, engine, recordingHook, revertingHook);
        engine.transferOwnership(address(handler));

        excludeContract(address(engine));
        excludeContract(address(token0));
        excludeContract(address(token1));
        excludeContract(address(token2));
        excludeContract(address(recordingHook));
        excludeContract(address(revertingHook));

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = DeepstateV1MultiPoolHandler.placeBid.selector;
        selectors[1] = DeepstateV1MultiPoolHandler.placeAsk.selector;
        selectors[2] = DeepstateV1MultiPoolHandler.routeForward.selector;
        selectors[3] = DeepstateV1MultiPoolHandler.routeReverse.selector;
        selectors[4] = DeepstateV1MultiPoolHandler.cancel.selector;
        selectors[5] = DeepstateV1MultiPoolHandler.configureFee.selector;
        selectors[6] = DeepstateV1MultiPoolHandler.configureHook.selector;
        selectors[7] = DeepstateV1MultiPoolHandler.rotatePool.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_MultiPoolAccountingAndConservation() public view {
        for (uint256 actorIndex; actorIndex < handler.actorCount(); ++actorIndex) {
            address actor = handler.actorAt(actorIndex);
            for (uint256 tokenIndex; tokenIndex < 3; ++tokenIndex) {
                MultiPoolInvariantERC20 token = MultiPoolInvariantERC20(handler.tokenAt(tokenIndex));
                assertEq(
                    token.balanceOf(actor), handler.expectedActorBalance(actorIndex, tokenIndex), "actor balance model"
                );
            }
        }

        for (uint256 tokenIndex; tokenIndex < 3; ++tokenIndex) {
            MultiPoolInvariantERC20 token = MultiPoolInvariantERC20(handler.tokenAt(tokenIndex));
            assertEq(token.balanceOf(address(engine)), handler.expectedEngineBalance(tokenIndex), "engine collateral");
            assertEq(token.balanceOf(address(0xFEE)), handler.expectedFeeBalance(tokenIndex), "fee balance");
            assertEq(token.totalSupply(), handler.expectedSupply(tokenIndex), "token supply");
            assertEq(_trackedBalanceSum(token), token.totalSupply(), "tracked supply");
        }
    }

    function invariant_MultiPoolOrdersBooksAndPriority() public view {
        uint256 orderCount = handler.orderCount();
        uint256 bookCount = handler.knownBookCount();

        for (uint256 i; i < orderCount; ++i) {
            (bytes32 expectedBook, bytes32 order, address owner, uint160 remaining,,, bool isBid, bool active) =
                handler.orderAt(i);

            bytes32 expectedOrderId = keccak256(abi.encode(expectedBook, order));
            assertEq(engine.ownerOfOrder(expectedOrderId), active ? owner : address(0), "order owner state");
            if (active) assertEq(engine.isBidOrder(expectedOrderId), isBid, "order side state");

            (bytes32 askRoot, bytes32 bidRoot) = _rootsForBook(expectedBook, i);
            bytes32 found = _find(expectedBook, isBid ? bidRoot : askRoot, order, isBid);
            if (active && remaining != 0) {
                assertTrue(found != bytes32(0), "live order absent");
                assertEq(_quantity(found), remaining, "live remaining");
            } else {
                assertEq(found, bytes32(0), "dead order remains");
            }

            for (uint256 j; j < bookCount; ++j) {
                (bytes32 id,) = handler.knownBookAt(j);
                bytes32 orderId = keccak256(abi.encode(id, order));
                assertEq(engine.ownerOfOrder(orderId), handler.expectedOwnerAt(id, order), "book-scoped owner");
                if (handler.expectedOwnerAt(id, order) != address(0)) {
                    assertEq(engine.isBidOrder(orderId), handler.expectedSideAt(id, order), "book-scoped side");
                }
            }
        }

        for (uint256 i; i < bookCount; ++i) {
            (bytes32 id, uint8 poolIndex) = handler.knownBookAt(i);
            (bytes32 askRoot, bytes32 bidRoot) = _roots(id, poolIndex);
            _assertTop(id, bidRoot, true);
            _assertTop(id, askRoot, false);
            if (askRoot != bytes32(0) && bidRoot != bytes32(0)) {
                assertLt(_tick(_rightmostLeaf(id, bidRoot)), _tick(_rightmostLeaf(id, askRoot)), "crossed book");
            }
        }
    }

    function invariant_MultiPoolEpochFeeHookAndExecutionState() public view {
        for (uint8 poolIndex; poolIndex < 3; ++poolIndex) {
            (address lower, address upper) = _pair(poolIndex);
            bytes32 pid = engine.poolId(lower, upper);
            assertEq(engine.poolEpoch(pid), handler.expectedEpoch(poolIndex), "pool epoch model");
            (address expectedHook,) = handler.expectedPoolHook(poolIndex);
            assertEq(engine.poolHook(pid), expectedHook, "pool hook model");
        }

        (address expectedRecipient, uint16 expectedBps) = handler.expectedFeeConfig();
        (address recipient, uint16 bps) = engine.feeConfig();
        assertEq(recipient, expectedRecipient, "fee recipient model");
        assertEq(bps, expectedBps, "fee bps model");
        assertEq(recordingHook.callCount(), handler.validatedHookCalls(), "unvalidated hook call");
        assertEq(handler.unexpectedFillReverts(), 0, "unexpected fill revert");
        assertEq(handler.unexpectedRouteReverts(), 0, "unexpected route revert");
        assertEq(handler.unexpectedCancelReverts(), 0, "unexpected cancel revert");
        assertEq(handler.lastUnexpectedRevert(), bytes4(0), "unexpected revert selector");
    }

    function _trackedBalanceSum(MultiPoolInvariantERC20 token) private view returns (uint256 total) {
        for (uint256 i; i < handler.actorCount(); ++i) {
            total += token.balanceOf(handler.actorAt(i));
        }
        total += token.balanceOf(address(engine));
        total += token.balanceOf(address(0xFEE));
    }

    function _assertTop(bytes32 id, bytes32 root, bool isBid) private view {
        (bytes32 expectedOrder, uint160 expectedQuantity, uint32 expectedNonce, bool exists) =
            handler.modelTop(id, isBid);
        if (!exists) {
            assertEq(root, bytes32(0), "empty model root");
            return;
        }

        bytes32 leaf = _rightmostLeaf(id, root);
        assertEq(_tick(leaf), _tick(expectedOrder), "best tick");
        assertEq(_nonce(leaf), expectedNonce, "best nonce");
        assertEq(_quantity(leaf), expectedQuantity, "best quantity");
    }

    function _rootsForBook(bytes32 expectedBook, uint256 orderIndex)
        private
        view
        returns (bytes32 askRoot, bytes32 bidRoot)
    {
        (,,,, uint256 epoch, uint8 poolIndex,,) = handler.orderAt(orderIndex);
        (address lower, address upper) = _pair(poolIndex);
        assertEq(engine.bookId(lower, upper, epoch), expectedBook, "order book derivation");
        return engine.roots(lower, upper, epoch);
    }

    function _roots(bytes32 expectedBook, uint8 poolIndex) private view returns (bytes32 askRoot, bytes32 bidRoot) {
        (address lower, address upper) = _pair(poolIndex);
        uint256 maxEpoch = handler.expectedEpoch(poolIndex);
        for (uint256 epoch; epoch <= maxEpoch; ++epoch) {
            if (engine.bookId(lower, upper, epoch) == expectedBook) return engine.roots(lower, upper, epoch);
        }
        revert("unknown book epoch");
    }

    function _find(bytes32 id, bytes32 root, bytes32 order, bool isBid) private view returns (bytes32) {
        uint64 targetKey = _sortKey(order, isBid);
        while (root != bytes32(0)) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(id, root);
            if (leftNode == bytes32(0)) return _sortKey(root, isBid) == targetKey ? root : bytes32(0);

            uint64 leftKey = _sortKey(leftNode, isBid);
            uint8 depth = _commonPrefix(leftKey, _sortKey(rightNode, isBid));
            if (_commonPrefix(targetKey, leftKey) < depth) return bytes32(0);
            root = _bit(targetKey, depth) ? rightNode : leftNode;
        }
        return bytes32(0);
    }

    function _rightmostLeaf(bytes32 id, bytes32 root) private view returns (bytes32) {
        while (root != bytes32(0)) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(id, root);
            if (leftNode == bytes32(0)) return root;
            root = rightNode;
        }
        return bytes32(0);
    }

    function _pair(uint8 poolIndex) private view returns (address lower, address upper) {
        if (poolIndex == 0) return (address(token0), address(token1));
        if (poolIndex == 1) return (address(token1), address(token2));
        return (address(token0), address(token2));
    }

    function _sortKey(bytes32 order, bool isBid) private pure returns (uint64) {
        uint32 tickKey = uint32(_tick(order)) ^ 0x80000000;
        if (!isBid) tickKey = type(uint32).max - tickKey;
        return (uint64(tickKey) << 32) | uint64(_nonce(order));
    }

    function _commonPrefix(uint64 a, uint64 b) private pure returns (uint8 depth) {
        for (; depth < 64; ++depth) {
            if (_bit(a, depth) != _bit(b, depth)) return depth;
        }
    }

    function _bit(uint64 key, uint8 depth) private pure returns (bool) {
        return ((key >> (63 - depth)) & 1) != 0;
    }

    function _tick(bytes32 order) private pure returns (int32) {
        return int32(uint32(uint256(order) >> 224));
    }

    function _quantity(bytes32 order) private pure returns (uint160) {
        return uint160((uint256(order) >> 64) & ((uint256(1) << 160) - 1));
    }

    function _nonce(bytes32 order) private pure returns (uint32) {
        return uint32(uint256(order));
    }
}
