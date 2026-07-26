// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";
import {QuoteMath} from "./QuoteMath.sol";

contract NativeInvariantERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Native Invariant Quote";
    }

    function symbol() public pure override returns (string memory) {
        return "NIQ";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Stateful reference model for one `ETH / ERC20` pool.
contract DeepstateV1NativeETHHandler is Test {
    struct TrackedOrder {
        bytes32 order;
        address owner;
        uint160 remaining;
        uint8 actorIndex;
        bool isBid;
        bool active;
    }

    DeepstateV1 internal immutable ENGINE;
    NativeInvariantERC20 internal immutable QUOTE;
    bytes32 internal immutable BOOK_ID;

    uint256 internal constant INITIAL_NATIVE_BALANCE = 1e30;
    uint256 internal constant INITIAL_QUOTE_BALANCE = type(uint216).max;
    uint160 internal constant MAX_ORDER_QUANTITY = 1e18;
    uint256 internal constant NATIVE_OVERPAYMENT = 777;
    uint256 internal constant MAX_TRACKED_ORDERS = 96;
    int32 internal constant MIN_FUZZ_TICK = -100_000_000;
    int32 internal constant MAX_FUZZ_TICK = 100_000_000;
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;
    address internal constant FEE_RECIPIENT = address(0xFEE);

    address[6] internal actors;
    uint256[6] internal expectedNativeBalances;
    uint256[6] internal expectedQuoteBalances;
    TrackedOrder[] internal trackedOrders;

    uint256 internal expectedNativeFees;
    uint256 internal expectedQuoteFees;
    address internal expectedFeeRecipient;
    uint16 internal expectedFeeBps;

    uint256 public restingFillCalls;
    uint256 public noRestFillCalls;
    uint256 public cancelCalls;
    uint256 public feeConfigCalls;

    constructor(DeepstateV1 engine_, NativeInvariantERC20 quote_) {
        ENGINE = engine_;
        QUOTE = quote_;
        BOOK_ID = ENGINE.bookId(address(0), address(quote_), 0);

        actors = [address(0xA11CE), address(0xB0B), address(0xCA201), address(0xD00D), address(0xE1EE), address(0xF00D)];
        vm.deal(FEE_RECIPIENT, 0);

        for (uint256 i; i < actors.length; ++i) {
            address actor = actors[i];
            vm.deal(actor, INITIAL_NATIVE_BALANCE);
            expectedNativeBalances[i] = INITIAL_NATIVE_BALANCE;

            QUOTE.mint(actor, INITIAL_QUOTE_BALANCE);
            expectedQuoteBalances[i] = INITIAL_QUOTE_BALANCE;
            vm.prank(actor);
            QUOTE.approve(address(ENGINE), type(uint256).max);
        }
    }

    /// @notice Submit a bid that may match asks and rests any unmatched quantity.
    function placeBid(uint256 actorSeed, int32 tickSeed, uint256 quantitySeed) external {
        if (trackedOrders.length >= MAX_TRACKED_ORDERS) return;
        _performFill(
            uint8(bound(actorSeed, 0, actors.length - 1)),
            int32(bound(tickSeed, MIN_FUZZ_TICK, MAX_FUZZ_TICK)),
            uint160(bound(quantitySeed, 1, uint256(MAX_ORDER_QUANTITY))),
            true,
            false
        );
        ++restingFillCalls;
    }

    /// @notice Submit an ask that may match bids and rests any unmatched quantity.
    function placeAsk(uint256 actorSeed, int32 tickSeed, uint256 quantitySeed) external {
        if (trackedOrders.length >= MAX_TRACKED_ORDERS) return;
        _performFill(
            uint8(bound(actorSeed, 0, actors.length - 1)),
            int32(bound(tickSeed, MIN_FUZZ_TICK, MAX_FUZZ_TICK)),
            uint160(bound(quantitySeed, 1, uint256(MAX_ORDER_QUANTITY))),
            false,
            false
        );
        ++restingFillCalls;
    }

    /// @notice Consume existing asks without creating a new maker order.
    function takeAsBid(uint256 actorSeed, uint256 quantitySeed) external {
        uint256 available = _totalRemaining(false);
        if (available == 0) return;

        uint256 maximum = available < MAX_ORDER_QUANTITY ? available : MAX_ORDER_QUANTITY;
        _performFill(
            uint8(bound(actorSeed, 0, actors.length - 1)),
            type(int32).max,
            uint160(bound(quantitySeed, 1, maximum)),
            true,
            true
        );
        ++noRestFillCalls;
    }

    /// @notice Consume existing bids without creating a new maker order.
    function takeAsAsk(uint256 actorSeed, uint256 quantitySeed) external {
        uint256 available = _totalRemaining(true);
        if (available == 0) return;

        uint256 maximum = available < MAX_ORDER_QUANTITY ? available : MAX_ORDER_QUANTITY;
        _performFill(
            uint8(bound(actorSeed, 0, actors.length - 1)),
            type(int32).min,
            uint160(bound(quantitySeed, 1, maximum)),
            false,
            true
        );
        ++noRestFillCalls;
    }

    /// @notice Cancel one open maker order or claim its filled proceeds.
    function cancel(uint256 orderSeed) external {
        uint256 length = trackedOrders.length;
        if (length == 0) return;

        uint256 start = bound(orderSeed, 0, length - 1);
        for (uint256 offset; offset < length; ++offset) {
            uint256 index = (start + offset) % length;
            if (!trackedOrders[index].active) continue;
            _cancel(index);
            ++cancelCalls;
            return;
        }
    }

    /// @notice Toggle fees and vary the configured basis-point rate.
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
        ++feeConfigCalls;
    }

    function actorCount() external pure returns (uint256) {
        return 6;
    }

    function actorAt(uint256 index) external view returns (address) {
        return actors[index];
    }

    function expectedNativeBalance(uint256 actorIndex) external view returns (uint256) {
        return expectedNativeBalances[actorIndex];
    }

    function expectedQuoteBalance(uint256 actorIndex) external view returns (uint256) {
        return expectedQuoteBalances[actorIndex];
    }

    function expectedNativeFeeBalance() external view returns (uint256) {
        return expectedNativeFees;
    }

    function expectedQuoteFeeBalance() external view returns (uint256) {
        return expectedQuoteFees;
    }

    function initialNativeSupply() external pure returns (uint256) {
        return INITIAL_NATIVE_BALANCE * 6;
    }

    function initialQuoteSupply() external pure returns (uint256) {
        return INITIAL_QUOTE_BALANCE * 6;
    }

    function expectedEngineNativeBalance() external view returns (uint256 amount) {
        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage tracked = trackedOrders[i];
            if (!tracked.active) continue;

            uint160 original = _quantity(tracked.order);
            amount += tracked.isBid ? original - tracked.remaining : tracked.remaining;
        }
    }

    function expectedEngineQuoteBalance() external view returns (uint256 amount) {
        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage tracked = trackedOrders[i];
            if (!tracked.active) continue;

            uint160 original = _quantity(tracked.order);
            int32 tick = _tick(tracked.order);
            if (tracked.isBid) {
                amount += _quoteValue(tick, tracked.remaining, true);
            } else {
                amount += _quoteValue(tick, original, false) - _quoteValue(tick, tracked.remaining, false);
            }
        }
    }

    function orderCount() external view returns (uint256) {
        return trackedOrders.length;
    }

    function orderAt(uint256 index)
        external
        view
        returns (bytes32 order, address owner, uint160 remaining, bool isBid, bool active)
    {
        TrackedOrder storage tracked = trackedOrders[index];
        return (tracked.order, tracked.owner, tracked.remaining, tracked.isBid, tracked.active);
    }

    function bookId() external view returns (bytes32) {
        return BOOK_ID;
    }

    function expectedFeeConfig() external view returns (address recipient, uint16 bps) {
        return (expectedFeeRecipient, expectedFeeBps);
    }

    function _performFill(uint8 actorIndex, int32 tick, uint160 quantity, bool isBid, bool noRest) private {
        address actor = actors[actorIndex];
        uint32 nonceBefore = ENGINE.nextNonce(address(0), address(QUOTE), 0);
        uint256 nativeValue = (isBid ? 0 : quantity) + NATIVE_OVERPAYMENT;

        vm.prank(actor);
        bytes32 restingOrder = ENGINE.fill{value: nativeValue}(_fillParams(tick, quantity, isBid, noRest));

        (uint160 remaining, uint160 baseFilled, uint256 quoteAmount) = _matchModel(isBid, tick, quantity);
        uint32 nonceAfter = ENGINE.nextNonce(address(0), address(QUOTE), 0);

        bool didRest = remaining != 0 && !noRest;
        if (didRest) {
            uint32 assignedNonce = nonceBefore == 0 ? MAX_ORDER_NONCE : nonceBefore;
            assertEq(_tick(restingOrder), tick, "rest tick");
            assertEq(_quantity(restingOrder), remaining, "rest quantity");
            assertEq(_nonce(restingOrder), assignedNonce, "rest nonce");
            assertEq(nonceAfter, assignedNonce - 1, "next nonce after rest");
            _trackRest(restingOrder, actor, actorIndex, isBid);
        } else {
            assertEq(restingOrder, bytes32(0), "unexpected rest");
            assertEq(nonceAfter, nonceBefore, "nonce changed without rest");
            if (noRest) assertEq(remaining, 0, "no-rest taker not fully matched");
        }

        uint256 feeAmount;
        if (expectedFeeRecipient != address(0) && expectedFeeBps != 0) {
            feeAmount = _feeAmount(isBid ? baseFilled : quoteAmount, expectedFeeBps);
        }

        if (isBid) {
            expectedNativeBalances[actorIndex] += uint256(baseFilled) - feeAmount;
            expectedQuoteBalances[actorIndex] -= quoteAmount;
            if (didRest) expectedQuoteBalances[actorIndex] -= _quoteValue(tick, remaining, true);
            expectedNativeFees += feeAmount;
        } else {
            expectedNativeBalances[actorIndex] -= uint256(baseFilled) + (didRest ? uint256(remaining) : 0);
            expectedQuoteBalances[actorIndex] += quoteAmount - feeAmount;
            expectedQuoteFees += feeAmount;
        }
    }

    function _cancel(uint256 index) private {
        TrackedOrder storage tracked = trackedOrders[index];
        uint160 original = _quantity(tracked.order);
        uint160 remaining = tracked.remaining;
        uint256 expectedBase;
        uint256 expectedQuote;

        if (tracked.isBid) {
            expectedBase = original - remaining;
            expectedQuote = _quoteValue(_tick(tracked.order), remaining, true);
        } else {
            expectedBase = remaining;
            expectedQuote = _quoteValue(_tick(tracked.order), original, false)
                - _quoteValue(_tick(tracked.order), remaining, false);
        }

        vm.prank(tracked.owner);
        (uint256 baseAmount, uint256 quoteAmount) = ENGINE.cancel(address(0), address(QUOTE), 0, tracked.order);
        assertEq(baseAmount, expectedBase, "cancel native amount");
        assertEq(quoteAmount, expectedQuote, "cancel quote amount");

        expectedNativeBalances[tracked.actorIndex] += baseAmount;
        expectedQuoteBalances[tracked.actorIndex] += quoteAmount;
        tracked.remaining = 0;
        tracked.active = false;
    }

    function _matchModel(bool incomingIsBid, int32 limitTick, uint160 quantity)
        private
        returns (uint160 remaining, uint160 baseFilled, uint256 quoteAmount)
    {
        remaining = quantity;
        while (remaining != 0) {
            (uint256 index, bool found) = _bestMatch(incomingIsBid, limitTick);
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

    function _bestMatch(bool incomingIsBid, int32 limitTick) private view returns (uint256 bestIndex, bool found) {
        int32 bestTick;
        uint32 bestNonce;

        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage candidate = trackedOrders[i];
            if (!candidate.active || candidate.isBid == incomingIsBid || candidate.remaining == 0) continue;

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

    function _trackRest(bytes32 order, address owner, uint8 actorIndex, bool isBid) private {
        trackedOrders.push(
            TrackedOrder({
                order: order,
                owner: owner,
                remaining: _quantity(order),
                actorIndex: actorIndex,
                isBid: isBid,
                active: true
            })
        );
    }

    function _totalRemaining(bool isBid) private view returns (uint256 total) {
        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage tracked = trackedOrders[i];
            if (tracked.active && tracked.isBid == isBid) total += tracked.remaining;
        }
    }

    function _fillParams(int32 tick, uint160 quantity, bool isBid, bool noRest)
        private
        view
        returns (DeepstateV1.FillParams memory params)
    {
        params = DeepstateV1.FillParams({
            token0: address(0),
            token1: address(QUOTE),
            epoch: 0,
            order: _pack(tick, quantity, 0),
            isBid: isBid,
            noRest: noRest,
            fillOrKill: false
        });
    }

    function _feeAmount(uint256 amount, uint16 bps) private pure returns (uint256) {
        // Mirrors production's overflow-safe quotient/remainder decomposition.
        // forge-lint: disable-next-line(divide-before-multiply)
        return (amount / 10_000) * uint256(bps) + ((amount % 10_000) * uint256(bps)) / 10_000;
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) private pure returns (uint256) {
        return QuoteMath.quoteValue(tick, quantity, roundUp);
    }

    function _pack(int32 tick, uint160 quantity, uint32 nonce) private pure returns (bytes32) {
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

contract DeepstateV1NativeETHInvariantTest is StdInvariant, Test {
    DeepstateV1 internal engine;
    NativeInvariantERC20 internal quote;
    DeepstateV1NativeETHHandler internal handler;

    address internal constant FEE_RECIPIENT = address(0xFEE);

    function setUp() public {
        engine = new DeepstateV1();
        quote = new NativeInvariantERC20();
        handler = new DeepstateV1NativeETHHandler(engine, quote);
        engine.transferOwnership(address(handler));

        excludeContract(address(engine));
        excludeContract(address(quote));

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = DeepstateV1NativeETHHandler.placeBid.selector;
        selectors[1] = DeepstateV1NativeETHHandler.placeAsk.selector;
        selectors[2] = DeepstateV1NativeETHHandler.takeAsBid.selector;
        selectors[3] = DeepstateV1NativeETHHandler.takeAsAsk.selector;
        selectors[4] = DeepstateV1NativeETHHandler.cancel.selector;
        selectors[5] = DeepstateV1NativeETHHandler.configureFee.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /// @notice In modeled protocol-only histories, engine ETH exactly equals native maker claims.
    function invariant_NativeCollateralEqualsOutstandingClaims() public view {
        assertEq(address(engine).balance, handler.expectedEngineNativeBalance(), "native engine collateral");
        assertEq(quote.balanceOf(address(engine)), handler.expectedEngineQuoteBalance(), "quote engine collateral");
    }

    /// @notice Every actor and fee balance must match the independent settlement model.
    function invariant_NativeActorFeeAndSupplyAccounting() public view {
        uint256 nativeTotal = address(engine).balance + FEE_RECIPIENT.balance;
        uint256 quoteTotal = quote.balanceOf(address(engine)) + quote.balanceOf(FEE_RECIPIENT);

        for (uint256 i; i < handler.actorCount(); ++i) {
            address actor = handler.actorAt(i);
            assertEq(actor.balance, handler.expectedNativeBalance(i), "actor native balance");
            assertEq(quote.balanceOf(actor), handler.expectedQuoteBalance(i), "actor quote balance");
            nativeTotal += actor.balance;
            quoteTotal += quote.balanceOf(actor);
        }

        assertEq(FEE_RECIPIENT.balance, handler.expectedNativeFeeBalance(), "native fee balance");
        assertEq(quote.balanceOf(FEE_RECIPIENT), handler.expectedQuoteFeeBalance(), "quote fee balance");
        assertEq(nativeTotal, handler.initialNativeSupply(), "native conservation");
        assertEq(quoteTotal, handler.initialQuoteSupply(), "quote conservation");
        assertEq(quote.totalSupply(), handler.initialQuoteSupply(), "quote total supply");
    }

    /// @notice The reference model, owner mapping, and concrete radix leaves must agree.
    function invariant_NativeOrdersMatchReferenceModel() public view {
        bytes32 id = handler.bookId();
        (bytes32 askRoot, bytes32 bidRoot) = engine.roots(address(0), address(quote), 0);

        for (uint256 i; i < handler.orderCount(); ++i) {
            (bytes32 order, address owner, uint160 remaining, bool isBid, bool active) = handler.orderAt(i);
            bytes32 orderKey = keccak256(abi.encode(id, order));
            assertEq(engine.ownerOfOrder(orderKey), active ? owner : address(0), "native order owner");
            if (active) assertEq(engine.isBidOrder(orderKey), isBid, "native order side");

            bytes32 found = _find(id, isBid ? bidRoot : askRoot, order, isBid);
            if (active && remaining != 0) {
                assertTrue(found != bytes32(0), "native live order absent");
                assertEq(_quantity(found), remaining, "native live remaining");
            } else {
                assertEq(found, bytes32(0), "native inactive order remains");
            }
        }

        (address recipient, uint16 bps) = engine.feeConfig();
        (address expectedRecipient, uint16 expectedBps) = handler.expectedFeeConfig();
        assertEq(recipient, expectedRecipient, "native fee recipient");
        assertEq(bps, expectedBps, "native fee bps");
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
