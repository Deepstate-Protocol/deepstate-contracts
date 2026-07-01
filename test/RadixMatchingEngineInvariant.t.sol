// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {RadixMatchingEngine} from "../src/RadixMatchingEngine.sol";
import {TestERC20} from "./RadixMatchingEngine.t.sol";

contract RadixMatchingEngineHandler is Test {
    struct TrackedOrder {
        bytes32 order;
        address owner;
        uint256 ownerIndex;
        bool isBid;
        bool active;
        uint192 remainingQuantity;
    }

    struct FillLogState {
        uint256 matchedEventCount;
        uint192 matchedQuantity;
        uint256 matchedQuoteAmount;
        uint256 restedEventCount;
        bool sawMatchedPrice;
        uint24 previousMatchedPrice;
    }

    TestERC20 internal immutable BASE;
    TestERC20 internal immutable QUOTE;
    RadixMatchingEngine internal immutable ENGINE;

    uint256 internal constant MAX_TRACKED_ORDERS = 96;
    uint192 internal constant MAX_ORDER_QUANTITY = type(uint192).max / 96;
    uint256 internal constant INITIAL_BALANCE = type(uint216).max;
    uint24 internal constant SAME_PRICE = 777_777;
    bytes32 internal constant ORDER_RESTED_TOPIC = keccak256("OrderRested(bytes32,address,bool)");
    bytes32 internal constant ORDER_MATCHED_TOPIC = keccak256("OrderMatched(bytes32,bool,uint192,uint256)");
    bytes32 internal constant ORDER_CANCELLED_TOPIC = keccak256("OrderCancelled(bytes32,address,uint256,uint256)");

    address[] internal actors;
    TrackedOrder[] internal trackedOrders;
    uint256[] internal expectedBaseBalances;
    uint256[] internal expectedQuoteBalances;

    uint256 public unexpectedFillReverts;
    uint256 public unexpectedCancelReverts;
    uint256 public unexpectedInvalidFillSuccesses;
    uint256 public unexpectedInvalidCancelSuccesses;
    uint256 public unexpectedInvalidFillReverts;
    uint256 public unexpectedInvalidCancelReverts;
    bytes4 public lastFillRevertSelector;
    bytes4 public lastCancelRevertSelector;
    bytes4 public lastInvalidFillRevertSelector;
    bytes4 public lastInvalidCancelRevertSelector;

    constructor(TestERC20 base_, TestERC20 quote_, RadixMatchingEngine engine_) {
        BASE = base_;
        QUOTE = quote_;
        ENGINE = engine_;

        actors.push(address(1));
        actors.push(address(2));
        actors.push(address(0xA11CE));
        actors.push(address(0xB0B));
        actors.push(address(0xCA201));
        actors.push(address(0xD00D));
        actors.push(address(0xE1EE));
        actors.push(address(0xF00D));

        for (uint256 i; i < actors.length; ++i) {
            BASE.mint(actors[i], INITIAL_BALANCE);
            QUOTE.mint(actors[i], INITIAL_BALANCE);
            expectedBaseBalances.push(INITIAL_BALANCE);
            expectedQuoteBalances.push(INITIAL_BALANCE);

            vm.startPrank(actors[i]);
            BASE.approve(address(ENGINE), type(uint256).max);
            QUOTE.approve(address(ENGINE), type(uint256).max);
            vm.stopPrank();
        }
    }

    function placeBid(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed) external {
        _place(actorSeed, priceSeed, quantitySeed, true);
    }

    function placeAsk(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed) external {
        _place(actorSeed, priceSeed, quantitySeed, false);
    }

    function placeMaxBid(uint256 actorSeed, uint24 priceSeed) external {
        _place(actorSeed, priceSeed, MAX_ORDER_QUANTITY, true);
    }

    function placeMaxAsk(uint256 actorSeed, uint24 priceSeed) external {
        _place(actorSeed, priceSeed, MAX_ORDER_QUANTITY, false);
    }

    function placeSamePriceBid(uint256 actorSeed, uint192 quantitySeed) external {
        _placeAtPrice(actorSeed, SAME_PRICE, quantitySeed, true);
    }

    function placeSamePriceAsk(uint256 actorSeed, uint192 quantitySeed) external {
        _placeAtPrice(actorSeed, SAME_PRICE, quantitySeed, false);
    }

    function cancel(uint256 orderSeed) external {
        if (trackedOrders.length == 0) return;

        uint256 index = bound(orderSeed, 0, trackedOrders.length - 1);
        TrackedOrder storage tracked = trackedOrders[index];
        if (!tracked.active) return;

        bytes32 order = tracked.order;
        address owner = tracked.owner;

        vm.recordLogs();
        vm.prank(owner);
        try ENGINE.cancel(tracked.order) returns (uint256 baseAmount, uint256 quoteAmount) {
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 expectedBaseAmount, uint256 expectedQuoteAmount) = _cancelAmounts(index);
            assertEq(baseAmount, expectedBaseAmount, "cancel base amount");
            assertEq(quoteAmount, expectedQuoteAmount, "cancel quote amount");
            _assertCancelLogs(entries, order, owner, baseAmount, quoteAmount);
            _applyCancel(index);
        } catch (bytes memory reason) {
            vm.getRecordedLogs();
            ++unexpectedCancelReverts;
            if (reason.length >= 4) {
                // forge-lint: disable-next-line(unsafe-typecast)
                lastCancelRevertSelector = bytes4(reason);
            }
        }
    }

    function invalidFill(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed, uint40 nonceSeed, bool isBid)
        external
    {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint256 mode = uint256(nonceSeed) % 3;
        uint24 price = uint24(bound(priceSeed, 1, type(uint24).max));
        uint192 quantity = uint192(bound(quantitySeed, 1, uint256(MAX_ORDER_QUANTITY)));
        uint40 nonce;

        if (mode == 0) {
            price = 0;
        } else if (mode == 1) {
            quantity = 0;
        } else {
            nonce = uint40(bound(nonceSeed, 1, type(uint40).max));
        }

        vm.prank(actor);
        try ENGINE.fill(_pack(price, quantity, nonce), isBid) {
            ++unexpectedInvalidFillSuccesses;
        } catch (bytes memory reason) {
            bytes4 selector;
            if (reason.length >= 4) {
                // forge-lint: disable-next-line(unsafe-typecast)
                selector = bytes4(reason);
            }

            if (selector != RadixMatchingEngine.InvalidOrder.selector) {
                ++unexpectedInvalidFillReverts;
                if (reason.length >= 4) {
                    lastInvalidFillRevertSelector = selector;
                }
            }
        }
    }

    function invalidCancel(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed, uint256 orderSeed) external {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        bytes32 order;
        uint256 mode = orderSeed % 3;

        if (trackedOrders.length != 0 && mode == 0) {
            uint256 index = bound(orderSeed, 0, trackedOrders.length - 1);
            bytes32 trackedOrder = trackedOrders[index].order;
            order = _pack(_price(trackedOrder), 0, _nonce(trackedOrder));
        } else if (trackedOrders.length != 0 && mode == 1) {
            uint256 index = bound(orderSeed, 0, trackedOrders.length - 1);
            TrackedOrder storage tracked = trackedOrders[index];
            actor = actors[(tracked.ownerIndex + 1) % actors.length];
            order = tracked.order;
        } else {
            uint24 price = uint24(bound(priceSeed, 1, type(uint24).max));
            uint192 quantity = uint192(bound(quantitySeed, 1, uint256(MAX_ORDER_QUANTITY)));
            order = _pack(price, quantity, 0);
        }

        vm.prank(actor);
        try ENGINE.cancel(order) {
            ++unexpectedInvalidCancelSuccesses;
        } catch (bytes memory reason) {
            if (!_isExpectedInvalidCancelRevert(order, reason)) {
                ++unexpectedInvalidCancelReverts;
                if (reason.length >= 4) {
                    // forge-lint: disable-next-line(unsafe-typecast)
                    lastInvalidCancelRevertSelector = bytes4(reason);
                }
            }
        }
    }

    function invalidReducedLeafCancel(uint256 orderSeed) external {
        (uint256 index, bool found) = _partialOrderIndex(orderSeed);
        if (!found) return;

        TrackedOrder storage tracked = trackedOrders[index];
        bytes32 reducedOrder = _pack(_price(tracked.order), tracked.remainingQuantity, _nonce(tracked.order));

        vm.prank(tracked.owner);
        try ENGINE.cancel(reducedOrder) {
            ++unexpectedInvalidCancelSuccesses;
        } catch (bytes memory reason) {
            if (!_isExpectedInvalidCancelRevert(reducedOrder, reason)) {
                ++unexpectedInvalidCancelReverts;
                if (reason.length >= 4) {
                    // forge-lint: disable-next-line(unsafe-typecast)
                    lastInvalidCancelRevertSelector = bytes4(reason);
                }
            }
        }
    }

    function orderCount() external view returns (uint256) {
        return trackedOrders.length;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 index) external view returns (address) {
        return actors[index];
    }

    function expectedBaseBalanceAt(uint256 index) external view returns (uint256) {
        return expectedBaseBalances[index];
    }

    function expectedQuoteBalanceAt(uint256 index) external view returns (uint256) {
        return expectedQuoteBalances[index];
    }

    function orderAt(uint256 index) external view returns (bytes32 order, address owner, bool isBid, bool active) {
        TrackedOrder storage tracked = trackedOrders[index];
        return (tracked.order, tracked.owner, tracked.isBid, tracked.active);
    }

    function remainingQuantityAt(uint256 index) external view returns (uint192) {
        return trackedOrders[index].remainingQuantity;
    }

    function _place(uint256 actorSeed, uint24 priceSeed, uint192 quantitySeed, bool isBid) private {
        uint24 price = uint24(bound(priceSeed, 1, type(uint24).max));
        _placeAtPrice(actorSeed, price, quantitySeed, isBid);
    }

    function _placeAtPrice(uint256 actorSeed, uint24 price, uint192 quantitySeed, bool isBid) private {
        if (trackedOrders.length >= MAX_TRACKED_ORDERS) return;

        uint256 actorIndex = bound(actorSeed, 0, actors.length - 1);
        address actor = actors[actorIndex];
        uint192 quantity = uint192(bound(quantitySeed, 1, uint256(MAX_ORDER_QUANTITY)));
        bytes32 order = bytes32((uint256(price) << 232) | (uint256(quantity) << 40));

        vm.recordLogs();
        vm.prank(actor);
        try ENGINE.fill(order, isBid) returns (bytes32 restingOrder) {
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint192 remaining, uint192 baseFilled, uint256 quoteAmount) =
                _applyFill(actorIndex, price, quantity, isBid, restingOrder);
            _assertFillLogs(entries, actor, isBid, restingOrder, remaining, baseFilled, quoteAmount);
        } catch (bytes memory reason) {
            vm.getRecordedLogs();
            ++unexpectedFillReverts;
            if (reason.length >= 4) {
                // forge-lint: disable-next-line(unsafe-typecast)
                lastFillRevertSelector = bytes4(reason);
            }
        }
    }

    function _applyFill(uint256 actorIndex, uint24 price, uint192 quantity, bool isBid, bytes32 restingOrder)
        private
        returns (uint192 remaining, uint192 baseFilled, uint256 quoteAmount)
    {
        remaining = quantity;

        while (remaining != 0) {
            (uint256 matchIndex, bool found) = _bestMatchIndex(price, isBid);
            if (!found) break;

            TrackedOrder storage resting = trackedOrders[matchIndex];
            uint192 fillQuantity = remaining < resting.remainingQuantity ? remaining : resting.remainingQuantity;
            uint256 fillQuoteAmount = _quoteValue(_price(resting.order), fillQuantity);

            remaining -= fillQuantity;
            resting.remainingQuantity -= fillQuantity;
            baseFilled += fillQuantity;
            quoteAmount += fillQuoteAmount;
        }

        if (isBid) {
            expectedBaseBalances[actorIndex] += baseFilled;
            expectedQuoteBalances[actorIndex] -= quoteAmount;
            if (remaining != 0) expectedQuoteBalances[actorIndex] -= _quoteValue(price, remaining);
        } else {
            expectedBaseBalances[actorIndex] -= baseFilled;
            expectedQuoteBalances[actorIndex] += quoteAmount;
            if (remaining != 0) expectedBaseBalances[actorIndex] -= remaining;
        }

        if (remaining == 0) {
            assertEq(restingOrder, bytes32(0), "unexpected resting order");
            return (remaining, baseFilled, quoteAmount);
        }

        uint40 nonce = uint40(uint256(type(uint40).max) - trackedOrders.length);
        bytes32 expectedRestingOrder = _pack(price, remaining, nonce);
        assertEq(restingOrder, expectedRestingOrder, "resting order");

        trackedOrders.push(
            TrackedOrder({
                order: restingOrder,
                owner: actors[actorIndex],
                ownerIndex: actorIndex,
                isBid: isBid,
                active: true,
                remainingQuantity: remaining
            })
        );
        return (remaining, baseFilled, quoteAmount);
    }

    function _assertFillLogs(
        Vm.Log[] memory entries,
        address actor,
        bool isBid,
        bytes32 restingOrder,
        uint192 remaining,
        uint192 baseFilled,
        uint256 quoteAmount
    ) private {
        FillLogState memory state;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];
            if (entry.emitter != address(ENGINE)) continue;
            assertTrue(entry.topics.length != 0, "engine anonymous event");

            bytes32 topic = entry.topics[0];
            if (topic == ORDER_RESTED_TOPIC) {
                ++state.restedEventCount;
                assertEq(entry.topics.length, 4, "rested topic count");
                assertEq(entry.topics[1], restingOrder, "rested order log");
                assertEq(entry.topics[2], _addressTopic(actor), "rested owner log");
                assertEq(entry.topics[3], _boolTopic(isBid), "rested side log");
                assertEq(entry.data.length, 0, "rested data");
            } else if (topic == ORDER_MATCHED_TOPIC) {
                ++state.matchedEventCount;
                assertEq(entry.topics.length, 3, "matched topic count");
                bytes32 restingNode = entry.topics[1];
                assertTrue(restingNode != bytes32(0), "matched node log");
                assertEq(entry.topics[2], _boolTopic(!isBid), "matched side log");

                (uint192 eventQuantity, uint256 eventQuoteAmount) = abi.decode(entry.data, (uint192, uint256));
                uint24 eventPrice = _price(restingNode);
                assertGt(eventQuantity, 0, "matched quantity log");
                assertLe(eventQuantity, _quantity(restingNode), "matched node quantity log");
                assertEq(eventQuoteAmount, _quoteValue(eventPrice, eventQuantity), "matched quote price log");
                if (state.sawMatchedPrice) {
                    if (isBid) {
                        assertGe(eventPrice, state.previousMatchedPrice, "matched ask price order");
                    } else {
                        assertLe(eventPrice, state.previousMatchedPrice, "matched bid price order");
                    }
                }
                state.sawMatchedPrice = true;
                state.previousMatchedPrice = eventPrice;
                state.matchedQuantity += eventQuantity;
                state.matchedQuoteAmount += eventQuoteAmount;
            } else if (topic == ORDER_CANCELLED_TOPIC) {
                fail("cancel event during fill");
            } else {
                fail("unknown engine event during fill");
            }
        }

        assertEq(state.restedEventCount, restingOrder == bytes32(0) ? 0 : 1, "rested event count");
        assertEq(state.matchedQuantity, baseFilled, "matched quantity sum");
        assertEq(state.matchedQuoteAmount, quoteAmount, "matched quote sum");
        assertEq(state.matchedEventCount == 0, baseFilled == 0, "matched event count");
        assertEq(remaining == 0, restingOrder == bytes32(0), "resting event remainder");
        assertTrue(state.restedEventCount != 0 || state.matchedEventCount != 0, "fill event count");
    }

    function _assertCancelLogs(
        Vm.Log[] memory entries,
        bytes32 order,
        address owner,
        uint256 baseAmount,
        uint256 quoteAmount
    ) private {
        uint256 cancelledEventCount;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];
            if (entry.emitter != address(ENGINE)) continue;
            assertTrue(entry.topics.length != 0, "engine anonymous event");

            bytes32 topic = entry.topics[0];
            if (topic == ORDER_CANCELLED_TOPIC) {
                ++cancelledEventCount;
                assertEq(entry.topics.length, 3, "cancel topic count");
                assertEq(entry.topics[1], order, "cancel order log");
                assertEq(entry.topics[2], _addressTopic(owner), "cancel owner log");

                (uint256 eventBaseAmount, uint256 eventQuoteAmount) = abi.decode(entry.data, (uint256, uint256));
                assertEq(eventBaseAmount, baseAmount, "cancel base log");
                assertEq(eventQuoteAmount, quoteAmount, "cancel quote log");
                assertTrue(eventBaseAmount != 0 || eventQuoteAmount != 0, "cancel empty log");
            } else if (topic == ORDER_RESTED_TOPIC || topic == ORDER_MATCHED_TOPIC) {
                fail("fill event during cancel");
            } else {
                fail("unknown engine event during cancel");
            }
        }

        assertEq(cancelledEventCount, 1, "cancel event count");
    }

    function _applyCancel(uint256 index) private {
        (uint256 baseAmount, uint256 quoteAmount) = _cancelAmounts(index);
        TrackedOrder storage tracked = trackedOrders[index];

        expectedBaseBalances[tracked.ownerIndex] += baseAmount;
        expectedQuoteBalances[tracked.ownerIndex] += quoteAmount;
        tracked.active = false;
        tracked.remainingQuantity = 0;
    }

    function _cancelAmounts(uint256 index) private view returns (uint256 baseAmount, uint256 quoteAmount) {
        TrackedOrder storage tracked = trackedOrders[index];
        uint192 originalQuantity = _quantity(tracked.order);
        uint192 remainingQuantity = tracked.remainingQuantity;
        uint192 filledQuantity = originalQuantity - remainingQuantity;
        uint24 price = _price(tracked.order);

        if (tracked.isBid) {
            baseAmount = filledQuantity;
            quoteAmount = _quoteValue(price, remainingQuantity);
        } else {
            baseAmount = remainingQuantity;
            quoteAmount = _quoteValue(price, filledQuantity);
        }
    }

    function _bestMatchIndex(uint24 limitPrice, bool incomingIsBid)
        private
        view
        returns (uint256 bestIndex, bool found)
    {
        uint24 bestPrice;
        uint40 bestNonce;

        for (uint256 i; i < trackedOrders.length; ++i) {
            TrackedOrder storage candidate = trackedOrders[i];
            if (!candidate.active || candidate.isBid == incomingIsBid || candidate.remainingQuantity == 0) continue;

            uint24 candidatePrice = _price(candidate.order);
            if (incomingIsBid) {
                if (candidatePrice > limitPrice) continue;
                if (
                    found
                        && (candidatePrice > bestPrice
                            || candidatePrice == bestPrice
                            && _nonce(candidate.order) <= bestNonce)
                ) {
                    continue;
                }
            } else {
                if (candidatePrice < limitPrice) continue;
                if (
                    found
                        && (candidatePrice < bestPrice
                            || candidatePrice == bestPrice
                            && _nonce(candidate.order) <= bestNonce)
                ) {
                    continue;
                }
            }

            found = true;
            bestIndex = i;
            bestPrice = candidatePrice;
            bestNonce = _nonce(candidate.order);
        }
    }

    function _partialOrderIndex(uint256 orderSeed) private view returns (uint256 index, bool found) {
        uint256 length = trackedOrders.length;
        if (length == 0) return (0, false);

        uint256 start = bound(orderSeed, 0, length - 1);
        for (uint256 offset; offset < length; ++offset) {
            index = (start + offset) % length;
            TrackedOrder storage tracked = trackedOrders[index];
            if (
                tracked.active && tracked.remainingQuantity != 0 && tracked.remainingQuantity < _quantity(tracked.order)
            ) {
                return (index, true);
            }
        }

        return (0, false);
    }

    function _isExpectedInvalidCancelRevert(bytes32 order, bytes memory reason) private pure returns (bool) {
        if (reason.length < 4) return false;

        bytes4 selector;
        // forge-lint: disable-next-line(unsafe-typecast)
        selector = bytes4(reason);
        if (_quantity(order) == 0) return selector == RadixMatchingEngine.InvalidOrder.selector;
        return selector == RadixMatchingEngine.NotOrderOwner.selector;
    }

    function _pack(uint24 price, uint192 quantity, uint40 nonce) private pure returns (bytes32) {
        return bytes32((uint256(price) << 232) | (uint256(quantity) << 40) | uint256(nonce));
    }

    function _price(bytes32 order) private pure returns (uint24) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(order) >> 232);
    }

    function _quantity(bytes32 order) private pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192((uint256(order) >> 40) & ((uint256(1) << 192) - 1));
    }

    function _quoteValue(uint24 price, uint192 quantity) private pure returns (uint256) {
        return uint256(price) * uint256(quantity);
    }

    function _addressTopic(address account) private pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }

    function _boolTopic(bool value) private pure returns (bytes32) {
        return bytes32(uint256(value ? 1 : 0));
    }

    function _nonce(bytes32 order) private pure returns (uint40) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint40(uint256(order));
    }
}

contract RadixMatchingEngineInvariantTest is StdInvariant, Test {
    struct SubtreeStats {
        uint192 quantity;
        uint64 minKey;
        uint64 maxKey;
        uint64 maxPathKey;
        uint192 maxPathLeafQuantity;
        uint24 bestPrice;
        uint24 leftmostPrice;
        uint24 rightmostPrice;
        bool exists;
    }

    TestERC20 internal base;
    TestERC20 internal quote;
    RadixMatchingEngine internal engine;
    RadixMatchingEngineHandler internal handler;

    uint256 private constant _PRICE_SHIFT = 232;
    uint256 private constant _QUANTITY_SHIFT = 40;
    uint256 private constant _QUANTITY_MASK = (uint256(1) << 192) - 1;
    uint40 private constant _MAX_ORDER_NONCE = type(uint40).max;
    uint24 private constant _MAX_PRICE = type(uint24).max;
    address private constant _BID_SENTINEL = address(uint160(1));
    address private constant _ASK_SENTINEL = address(uint160(2));

    function setUp() public {
        base = new TestERC20("Base", "BASE");
        quote = new TestERC20("Quote", "QUOTE");
        engine = new RadixMatchingEngine(address(base), address(quote));
        handler = new RadixMatchingEngineHandler(base, quote, engine);

        excludeContract(address(base));
        excludeContract(address(quote));
        excludeContract(address(engine));

        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = RadixMatchingEngineHandler.placeBid.selector;
        selectors[1] = RadixMatchingEngineHandler.placeAsk.selector;
        selectors[2] = RadixMatchingEngineHandler.placeMaxBid.selector;
        selectors[3] = RadixMatchingEngineHandler.placeMaxAsk.selector;
        selectors[4] = RadixMatchingEngineHandler.placeSamePriceBid.selector;
        selectors[5] = RadixMatchingEngineHandler.placeSamePriceAsk.selector;
        selectors[6] = RadixMatchingEngineHandler.cancel.selector;
        selectors[7] = RadixMatchingEngineHandler.invalidFill.selector;
        selectors[8] = RadixMatchingEngineHandler.invalidCancel.selector;
        selectors[9] = RadixMatchingEngineHandler.invalidReducedLeafCancel.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function test_ReplayIndirectBranchReuseKeepsLeavesBacked() public {
        handler.placeBid(270, 19576, 21123);
        handler.placeAsk(
            1002581022359336199078931974153934207457820454872615861, 3878, 53889295735608799266297081645648985990
        );
        handler.placeAsk(4000000000000000000000000000000, 7863, 3541);
        handler.placeBid(
            3059624943739379967374470270119672381169875874, 36485, 11645564289716989261400939689070552422709859780
        );
        handler.placeBid(666, 438, 3406);
        handler.placeAsk(1000002, 4457, 1928);
        handler.placeBid(4794550167836438011709433744303238, 46, 5678188);
        handler.placeBid(100, 16777174, 1779);
        handler.placeAsk(160429806044680488525166673785873168943952911781, 462100, 2387389365671260155253);
        handler.placeBid(729681749473481788557566957887, 165, 18611313675409404108229000821686780002);
        handler.placeAsk(30024828595563579209659148688417099986366163774490779226412118460315859943431, 1060, 748);
        handler.cancel(137055674322412288);
        handler.placeBid(2722, 1, 2296279256026075824659376772768396023403);
        handler.placeBid(28272784690565, 16777213, 18893256241734755177516134773133022029);
        handler.cancel(16544887995648023521142448936955165983041841155778278801766831224);
        handler.placeAsk(
            4099465225284685352911376835959935251529073758556160716,
            18,
            12697070510775694770772339393737442326823279672089489625
        );
        handler.placeAsk(2044, 5651, 8680);
        handler.placeAsk(3, 3, 280131318836084949503077086354525171);
        handler.placeAsk(18026610164084466690527283060317127377886, 2, 56021389468481031900328884657986);
        handler.placeBid(
            97371405490926153959535763367711722299205905765411566708783824218598899321,
            59460,
            25326457943050859515433210047280695747037556560844142878
        );
        handler.placeAsk(3, 2864, 1000000000000000000000000000075);
        handler.placeBid(85017259195378, 11, 266372082697647893014796410456847401);
        handler.placeBid(34408638515464300, 5308, 17592638990193929870302860670814);
        handler.placeAsk(417, 1595, 9428);
        handler.placeAsk(185483, 258, 2);
        handler.placeBid(
            108734278369728762803170239352420494748482585739391612092497832276861621190, 1412321, 160653504766890313679
        );
        handler.placeBid(35684, 2726, 584837);
        handler.placeAsk(
            301314131358404010522233968430262676501474730931246311150272177659,
            354,
            17757342861422200353999004658617667434440
        );
        handler.placeBid(975351301372804233232436111493935254, 14921, 4860291612095042748318693556795101);
        handler.placeBid(166, 50564, 64);
        handler.placeAsk(659918, 8071, 21792);
        handler.placeAsk(9093, 2583, 8419);
        handler.placeAsk(0, 636, 0);
        handler.placeAsk(308, 7396, 25284);

        _assertLeavesBackedByActiveOrders(engine.bidRoot(), true);
        _assertLeavesBackedByActiveOrders(engine.askRoot(), false);
        invariant_CollateralEqualsOutstandingClaims();
    }

    function invariant_CollateralEqualsOutstandingClaims() public view {
        uint256 expectedBase;
        uint256 expectedQuote;
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            uint192 originalQuantity = _quantity(order);
            uint192 remainingQuantity = handler.remainingQuantityAt(i);
            assertLe(remainingQuantity, originalQuantity, "remaining over original");
            uint192 filledQuantity = originalQuantity - remainingQuantity;
            uint24 limitPrice = _price(order);

            if (isBid) {
                expectedBase += filledQuantity;
                expectedQuote += _quoteValue(limitPrice, remainingQuantity);
            } else {
                expectedBase += remainingQuantity;
                expectedQuote += _quoteValue(limitPrice, filledQuantity);
            }
        }

        assertEq(base.balanceOf(address(engine)), expectedBase, "base collateral");
        assertEq(quote.balanceOf(address(engine)), expectedQuote, "quote collateral");
    }

    function invariant_EachActiveOrderClaimIsIndividuallyCollateralized() public view {
        uint256 engineBase = base.balanceOf(address(engine));
        uint256 engineQuote = quote.balanceOf(address(engine));
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (,, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            (uint256 baseAmount, uint256 quoteAmount) = _expectedCancelAmounts(i, isBid);
            assertLe(baseAmount, engineBase, "individual base claim");
            assertLe(quoteAmount, engineQuote, "individual quote claim");
        }
    }

    function invariant_RepresentativeActiveOrdersCanCancelAndClaim() public {
        uint256 length = handler.orderCount();
        bool checkedOpen;
        bool checkedPartial;
        bool checkedFilled;

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            uint192 remainingQuantity = handler.remainingQuantityAt(i);
            uint192 originalQuantity = _quantity(order);
            assertLe(remainingQuantity, originalQuantity, "representative remaining");
            if (remainingQuantity == originalQuantity && !checkedOpen) {
                _assertActiveOrderCanCancelAndClaim(i, isBid);
                checkedOpen = true;
            }
            if (remainingQuantity != 0 && remainingQuantity < originalQuantity && !checkedPartial) {
                _assertActiveOrderCanCancelAndClaim(i, isBid);
                checkedPartial = true;
            }
            if (remainingQuantity == 0 && !checkedFilled) {
                _assertActiveOrderCanCancelAndClaim(i, isBid);
                checkedFilled = true;
            }

            if (checkedOpen && checkedPartial && checkedFilled) break;
        }
    }

    function invariant_AllActiveOrdersCanCancelAndClaimSequentially() public {
        uint256 snapshotId = vm.snapshotState();
        _assertAllActiveOrdersCanCancelAndClaimSequentially();
        assertTrue(vm.revertToState(snapshotId), "restore after sequential cancel simulation");
    }

    function invariant_TotalTokenSupplyConserved() public view {
        assertEq(_trackedBalanceSum(base), base.totalSupply(), "base supply");
        assertEq(_trackedBalanceSum(quote), quote.totalSupply(), "quote supply");
    }

    function invariant_ActorBalancesMatchModel() public view {
        uint256 length = handler.actorCount();

        for (uint256 i; i < length; ++i) {
            address actor = handler.actorAt(i);
            assertEq(base.balanceOf(actor), handler.expectedBaseBalanceAt(i), "actor base");
            assertEq(quote.balanceOf(actor), handler.expectedQuoteBalanceAt(i), "actor quote");
        }
    }

    function invariant_NoUnexpectedHandlerReverts() public view {
        assertEq(handler.unexpectedFillReverts(), 0, "unexpected fill revert");
        assertEq(handler.unexpectedCancelReverts(), 0, "unexpected cancel revert");
        assertEq(handler.unexpectedInvalidFillSuccesses(), 0, "invalid fill success");
        assertEq(handler.unexpectedInvalidCancelSuccesses(), 0, "invalid cancel success");
        assertEq(handler.unexpectedInvalidFillReverts(), 0, "unexpected invalid fill revert");
        assertEq(handler.unexpectedInvalidCancelReverts(), 0, "unexpected invalid cancel revert");
    }

    function invariant_TreeAggregatesAndBranchShape() public view {
        _assertSubtree(engine.bidRoot(), 0, true);
        _assertSubtree(engine.askRoot(), 0, false);
    }

    function invariant_TreeQuantitiesMatchTrackedRemaining() public view {
        SubtreeStats memory bidStats = _assertSubtree(engine.bidRoot(), 0, true);
        SubtreeStats memory askStats = _assertSubtree(engine.askRoot(), 0, false);
        (uint256 expectedBidQuantity, uint256 expectedAskQuantity) = _trackedRemainingQuantities();

        assertEq(bidStats.quantity, expectedBidQuantity, "bid root quantity");
        assertEq(askStats.quantity, expectedAskQuantity, "ask root quantity");
    }

    function invariant_RightSpineQuantitiesNeverUnderstateLiveLeaves() public view {
        _assertRightSpineQuantityUpperBounds(engine.bidRoot());
        _assertRightSpineQuantityUpperBounds(engine.askRoot());
    }

    function invariant_ModelRemainingQuantitiesMatchBook() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            uint192 expectedRemaining = active ? handler.remainingQuantityAt(i) : 0;
            assertEq(_remainingQuantity(order, isBid), expectedRemaining, "model remaining");
        }
    }

    function invariant_TrackedOrdersAppearOnlyOnExpectedSide() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            bytes32 sameSideRoot = isBid ? engine.bidRoot() : engine.askRoot();
            bytes32 oppositeSideRoot = isBid ? engine.askRoot() : engine.bidRoot();
            bytes32 sameSideNode = _find(sameSideRoot, order, isBid);

            assertEq(_find(oppositeSideRoot, order, !isBid), bytes32(0), "opposite-side order");

            if (!active || handler.remainingQuantityAt(i) == 0) {
                assertEq(sameSideNode, bytes32(0), "inactive-or-filled same-side order");
            } else {
                assertTrue(sameSideNode != bytes32(0), "active same-side order");
                assertEq(_quantity(sameSideNode), handler.remainingQuantityAt(i), "active same-side remaining");
            }
        }
    }

    function invariant_NonceAccountingMatchesRestedOrders() public view {
        assertEq(uint256(engine.nextNonce()), uint256(_MAX_ORDER_NONCE) - handler.orderCount(), "next nonce");
    }

    function invariant_TrackedOrderNoncesAreStrictlyDecrementing() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,,,) = handler.orderAt(i);
            assertEq(uint256(_nonce(order)), uint256(_MAX_ORDER_NONCE) - i, "tracked nonce");
            assertGt(_nonce(order), engine.nextNonce(), "allocated nonce");

            for (uint256 j = i + 1; j < length; ++j) {
                (bytes32 otherOrder,,,) = handler.orderAt(j);
                assertTrue(_nonce(order) != _nonce(otherOrder), "duplicate tracked nonce");
            }
        }
    }

    function invariant_BidAskBranchesDoNotShareStorage() public view {
        _assertNoSharedBranches(engine.bidRoot(), engine.askRoot());
    }

    function invariant_LiveBookNodesAreUnique() public view {
        bytes32[] memory seenNodes = new bytes32[](handler.orderCount() * 2 + 2);
        uint256 seenCount = _assertUniqueLiveNodes(engine.bidRoot(), seenNodes, 0);
        _assertUniqueLiveNodes(engine.askRoot(), seenNodes, seenCount);
    }

    function invariant_LiveBranchesAreReachableByContractRouting() public view {
        _assertBranchesReachableByContractRouting(engine.bidRoot(), engine.bidRoot(), true);
        _assertBranchesReachableByContractRouting(engine.askRoot(), engine.askRoot(), false);
    }

    function invariant_OwnedLiveBranchesAreBackedByPartialOrders() public view {
        _assertOwnedLiveBranchesBackedByPartialOrders(engine.bidRoot(), true);
        _assertOwnedLiveBranchesBackedByPartialOrders(engine.askRoot(), false);
    }

    function invariant_LiveLeafSideKeysAreUnique() public view {
        bytes32[] memory seenSideKeys = new bytes32[](handler.orderCount() + 2);
        uint256 seenCount = _assertUniqueLiveLeafSideKeys(engine.bidRoot(), seenSideKeys, 0);
        _assertUniqueLiveLeafSideKeys(engine.askRoot(), seenSideKeys, seenCount);
    }

    function invariant_ActiveOrderSideKeysAreUnique() public view {
        uint256 length = handler.orderCount();
        bytes32[] memory seenSideKeys = new bytes32[](length);
        uint256 seenCount;

        for (uint256 i; i < length; ++i) {
            (bytes32 order,,, bool active) = handler.orderAt(i);
            if (!active) continue;

            bytes32 sideKey = _sideKey(order);
            for (uint256 j; j < seenCount; ++j) {
                assertTrue(seenSideKeys[j] != sideKey, "duplicate active side key");
            }
            seenSideKeys[seenCount++] = sideKey;
        }
    }

    function invariant_BooksAreNotCrossed() public view {
        SubtreeStats memory bidStats = _assertSubtree(engine.bidRoot(), 0, true);
        SubtreeStats memory askStats = _assertSubtree(engine.askRoot(), 0, false);

        if (bidStats.exists && askStats.exists) assertLt(bidStats.bestPrice, askStats.bestPrice, "crossed book");
    }

    function invariant_BestPricesMatchTrackedOrders() public view {
        (bool hasBid, uint24 bestBid, bool hasAsk, uint24 bestAsk) = _trackedBestPrices();

        if (hasBid) {
            assertEq(_rightmostLeafPrice(engine.bidRoot()), bestBid, "best bid price");
        } else {
            assertEq(engine.bidRoot(), bytes32(0), "empty bid root");
        }

        if (hasAsk) {
            assertEq(_rightmostLeafPrice(engine.askRoot()), bestAsk, "best ask price");
        } else {
            assertEq(engine.askRoot(), bytes32(0), "empty ask root");
        }
    }

    function invariant_BestOrdersMatchTrackedPriority() public view {
        (bool hasBid, bytes32 bestBid, bool hasAsk, bytes32 bestAsk) = _trackedBestOrders();

        if (hasBid) {
            assertEq(_sideKey(_rightmostLeaf(engine.bidRoot())), _sideKey(bestBid), "best bid order");
        } else {
            assertEq(engine.bidRoot(), bytes32(0), "empty bid root");
        }

        if (hasAsk) {
            assertEq(_sideKey(_rightmostLeaf(engine.askRoot())), _sideKey(bestAsk), "best ask order");
        } else {
            assertEq(engine.askRoot(), bytes32(0), "empty ask root");
        }
    }

    function invariant_OwnerMappingMatchesTrackedOrders() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order, address owner,, bool active) = handler.orderAt(i);
            assertEq(engine.ownerOfOrder(order), active ? owner : address(0), "tracked owner");
        }
    }

    function invariant_ReducedLiveLeafKeysAreNotOwnedOrders() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,,, bool active) = handler.orderAt(i);
            if (!active) continue;

            uint192 remainingQuantity = handler.remainingQuantityAt(i);
            if (remainingQuantity == 0 || remainingQuantity == _quantity(order)) continue;

            bytes32 reducedOrder = _pack(_price(order), remainingQuantity, _nonce(order));
            assertEq(engine.ownerOfOrder(reducedOrder), address(0), "reduced leaf owner");
        }
    }

    function invariant_SideMetadataMatchesTrackedOrders() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            address expectedMarker = active ? (isBid ? _BID_SENTINEL : _ASK_SENTINEL) : address(0);
            assertEq(engine.ownerOfOrder(_sideKey(order)), expectedMarker, "side marker");
        }
    }

    function invariant_SideMetadataKeysHaveNoBranchStorage() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,,,) = handler.orderAt(i);
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(_sideKey(order));
            assertEq(leftNode, bytes32(0), "side key left child");
            assertEq(rightNode, bytes32(0), "side key right child");
        }
    }

    function invariant_ActiveOrderBookStateMatchesRemainingQuantity() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            uint192 remainingQuantity = handler.remainingQuantityAt(i);
            bytes32 sameSideRoot = isBid ? engine.bidRoot() : engine.askRoot();
            bytes32 oppositeSideRoot = isBid ? engine.askRoot() : engine.bidRoot();
            bytes32 liveLeaf = _find(sameSideRoot, order, isBid);

            assertEq(_find(oppositeSideRoot, order, !isBid), bytes32(0), "active opposite-side order");

            if (remainingQuantity == 0) {
                assertEq(liveLeaf, bytes32(0), "filled active order still live");
                continue;
            }

            assertTrue(liveLeaf != bytes32(0), "open active order missing live leaf");
            assertEq(_sideKey(liveLeaf), _sideKey(order), "open active leaf side key");
            assertEq(_quantity(liveLeaf), remainingQuantity, "open active leaf quantity");
        }
    }

    function invariant_ActiveOrdersHaveExpectedCancelRouting() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            bytes32 root = isBid ? engine.bidRoot() : engine.askRoot();
            bytes32 liveLeaf = _findByContractRouting(root, order, isBid);
            uint192 remainingQuantity = handler.remainingQuantityAt(i);

            if (remainingQuantity == 0) {
                assertEq(liveLeaf, bytes32(0), "filled order cancel route");
                continue;
            }

            assertTrue(liveLeaf != bytes32(0), "cancel route missing order");
            assertEq(_sideKey(liveLeaf), _sideKey(order), "cancel route side key");
            assertEq(_quantity(liveLeaf), remainingQuantity, "cancel route quantity");
        }
    }

    function invariant_LiveLeavesAreBackedByActiveOrders() public view {
        _assertLeavesBackedByActiveOrders(engine.bidRoot(), true);
        _assertLeavesBackedByActiveOrders(engine.askRoot(), false);
    }

    function invariant_OpenTrackedLeavesHaveNoBranchStorage() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,,, bool active) = handler.orderAt(i);
            uint192 remainingQuantity = handler.remainingQuantityAt(i);
            if (!active || remainingQuantity == 0) continue;

            bytes32 liveLeaf = _pack(_price(order), remainingQuantity, _nonce(order));
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(liveLeaf);
            assertEq(leftNode, bytes32(0), "live leaf left child");
            assertEq(rightNode, bytes32(0), "live leaf right child");
        }
    }

    function invariant_InactiveTrackedOrdersAreAbsentFromBooks() public view {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (active) continue;

            bytes32 sameSideRoot = isBid ? engine.bidRoot() : engine.askRoot();
            bytes32 oppositeSideRoot = isBid ? engine.askRoot() : engine.bidRoot();
            assertEq(_find(sameSideRoot, order, isBid), bytes32(0), "inactive same-side order");
            assertEq(_find(oppositeSideRoot, order, !isBid), bytes32(0), "inactive opposite-side order");
        }
    }

    function _remainingQuantity(bytes32 order, bool isBid) private view returns (uint192) {
        bytes32 root = isBid ? engine.bidRoot() : engine.askRoot();
        bytes32 current = _find(root, order, isBid);
        return current == bytes32(0) ? 0 : _quantity(current);
    }

    function _expectedCancelAmounts(uint256 index, bool isBid)
        private
        view
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        (bytes32 order,,,) = handler.orderAt(index);
        uint192 originalQuantity = _quantity(order);
        uint192 remainingQuantity = handler.remainingQuantityAt(index);
        assertLe(remainingQuantity, originalQuantity, "expected cancel remaining");
        uint192 filledQuantity = originalQuantity - remainingQuantity;
        uint24 price = _price(order);

        if (isBid) {
            baseAmount = filledQuantity;
            quoteAmount = _quoteValue(price, remainingQuantity);
        } else {
            baseAmount = remainingQuantity;
            quoteAmount = _quoteValue(price, filledQuantity);
        }
    }

    function _assertActiveOrderCanCancelAndClaim(uint256 index, bool isBid) private {
        (bytes32 order, address owner,, bool active) = handler.orderAt(index);
        assertTrue(active, "cancelable active order");

        (uint256 expectedBaseAmount, uint256 expectedQuoteAmount) = _expectedCancelAmounts(index, isBid);
        uint256 ownerBaseBefore = base.balanceOf(owner);
        uint256 ownerQuoteBefore = quote.balanceOf(owner);
        uint256 engineBaseBefore = base.balanceOf(address(engine));
        uint256 engineQuoteBefore = quote.balanceOf(address(engine));

        uint256 snapshotId = vm.snapshotState();
        vm.prank(owner);
        try engine.cancel(order) returns (uint256 baseAmount, uint256 quoteAmount) {
            assertEq(baseAmount, expectedBaseAmount, "simulated cancel base amount");
            assertEq(quoteAmount, expectedQuoteAmount, "simulated cancel quote amount");
            assertEq(base.balanceOf(owner), ownerBaseBefore + expectedBaseAmount, "simulated owner base");
            assertEq(quote.balanceOf(owner), ownerQuoteBefore + expectedQuoteAmount, "simulated owner quote");
            assertEq(base.balanceOf(address(engine)), engineBaseBefore - expectedBaseAmount, "simulated engine base");
            assertEq(
                quote.balanceOf(address(engine)), engineQuoteBefore - expectedQuoteAmount, "simulated engine quote"
            );
            assertEq(engine.ownerOfOrder(order), address(0), "simulated owner delete");
            assertEq(engine.ownerOfOrder(_sideKey(order)), address(0), "simulated marker delete");
        } catch {
            assertTrue(vm.revertToState(snapshotId), "restore after cancel revert");
            fail("active order cancel reverted");
        }

        assertTrue(vm.revertToState(snapshotId), "restore after cancel simulation");
    }

    function _assertAllActiveOrdersCanCancelAndClaimSequentially() private {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order, address owner, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            (uint256 expectedBaseAmount, uint256 expectedQuoteAmount) = _expectedCancelAmounts(i, isBid);
            uint256 ownerBaseBefore = base.balanceOf(owner);
            uint256 ownerQuoteBefore = quote.balanceOf(owner);
            uint256 engineBaseBefore = base.balanceOf(address(engine));
            uint256 engineQuoteBefore = quote.balanceOf(address(engine));

            vm.prank(owner);
            try engine.cancel(order) returns (uint256 baseAmount, uint256 quoteAmount) {
                assertEq(baseAmount, expectedBaseAmount, "sequential cancel base amount");
                assertEq(quoteAmount, expectedQuoteAmount, "sequential cancel quote amount");
                assertEq(base.balanceOf(owner), ownerBaseBefore + expectedBaseAmount, "sequential owner base");
                assertEq(quote.balanceOf(owner), ownerQuoteBefore + expectedQuoteAmount, "sequential owner quote");
                assertEq(
                    base.balanceOf(address(engine)), engineBaseBefore - expectedBaseAmount, "sequential engine base"
                );
                assertEq(
                    quote.balanceOf(address(engine)), engineQuoteBefore - expectedQuoteAmount, "sequential engine quote"
                );
                assertEq(engine.ownerOfOrder(order), address(0), "sequential owner delete");
                assertEq(engine.ownerOfOrder(_sideKey(order)), address(0), "sequential marker delete");
            } catch {
                fail("active order sequential cancel reverted");
            }
        }

        assertEq(engine.bidRoot(), bytes32(0), "sequential empty bid root");
        assertEq(engine.askRoot(), bytes32(0), "sequential empty ask root");
        assertEq(base.balanceOf(address(engine)), 0, "sequential empty base collateral");
        assertEq(quote.balanceOf(address(engine)), 0, "sequential empty quote collateral");
    }

    function _trackedBalanceSum(TestERC20 token) private view returns (uint256 sum) {
        sum = token.balanceOf(address(engine));
        uint256 length = handler.actorCount();
        for (uint256 i; i < length; ++i) {
            sum += token.balanceOf(handler.actorAt(i));
        }
    }

    function _trackedRemainingQuantities()
        private
        view
        returns (uint256 expectedBidQuantity, uint256 expectedAskQuantity)
    {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (,, bool isBid, bool active) = handler.orderAt(i);
            if (!active) continue;

            uint192 remainingQuantity = handler.remainingQuantityAt(i);
            if (isBid) {
                expectedBidQuantity += remainingQuantity;
            } else {
                expectedAskQuantity += remainingQuantity;
            }
        }
    }

    function _trackedBestPrices() private view returns (bool hasBid, uint24 bestBid, bool hasAsk, uint24 bestAsk) {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (!active || handler.remainingQuantityAt(i) == 0) continue;

            uint24 price = _price(order);
            if (isBid) {
                if (!hasBid || price > bestBid) {
                    hasBid = true;
                    bestBid = price;
                }
            } else if (!hasAsk || price < bestAsk) {
                hasAsk = true;
                bestAsk = price;
            }
        }
    }

    function _trackedBestOrders() private view returns (bool hasBid, bytes32 bestBid, bool hasAsk, bytes32 bestAsk) {
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order,, bool isBid, bool active) = handler.orderAt(i);
            if (!active || handler.remainingQuantityAt(i) == 0) continue;

            if (isBid) {
                if (!hasBid || _isBetterBid(order, bestBid)) {
                    hasBid = true;
                    bestBid = order;
                }
            } else if (!hasAsk || _isBetterAsk(order, bestAsk)) {
                hasAsk = true;
                bestAsk = order;
            }
        }
    }

    function _assertSubtree(bytes32 node, uint256 depth, bool isBidTree)
        private
        view
        returns (SubtreeStats memory stats)
    {
        return _assertSubtree(node, depth, isBidTree, true);
    }

    function _assertSubtree(bytes32 node, uint256 depth, bool isBidTree, bool rightmost)
        private
        view
        returns (SubtreeStats memory stats)
    {
        if (node == bytes32(0)) return stats;
        assertLe(depth, 64, "radix depth");

        if (!_isBranch(node)) {
            assertGt(_quantity(node), 0, "leaf quantity");
            uint64 key = _sortKey(node, isBidTree);
            stats.quantity = _quantity(node);
            stats.minKey = key;
            stats.maxKey = key;
            stats.maxPathKey = _pathKey(node);
            stats.maxPathLeafQuantity = stats.quantity;
            stats.bestPrice = _price(node);
            stats.leftmostPrice = stats.bestPrice;
            stats.rightmostPrice = stats.bestPrice;
            stats.exists = true;
            return stats;
        }

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        assertTrue(leftNode != bytes32(0), "left child");
        assertTrue(rightNode != bytes32(0), "right child");

        uint8 branchDepth = _branchDepth(node, isBidTree);
        SubtreeStats memory leftStats = _assertSubtree(leftNode, depth + 1, isBidTree, false);
        SubtreeStats memory rightStats = _assertSubtree(rightNode, depth + 1, isBidTree, rightmost);

        _assertBranchOrder(branchDepth, leftStats, rightStats);
        _assertStoredBranchOrder(leftNode, rightNode, leftStats, rightStats, isBidTree);

        stats.quantity = leftStats.quantity + rightStats.quantity;
        stats.minKey = leftStats.minKey;
        stats.maxKey = rightStats.maxKey;
        stats.maxPathKey = leftStats.maxPathKey > rightStats.maxPathKey ? leftStats.maxPathKey : rightStats.maxPathKey;
        stats.maxPathLeafQuantity = leftStats.maxPathKey > rightStats.maxPathKey
            ? leftStats.maxPathLeafQuantity
            : rightStats.maxPathLeafQuantity;
        stats.bestPrice = rightStats.bestPrice;
        stats.leftmostPrice = leftStats.leftmostPrice;
        stats.rightmostPrice = rightStats.rightmostPrice;
        stats.exists = true;
        if (!rightmost) {
            assertEq(node, _branchNodeForChildren(leftNode, rightNode), "branch address");
            assertEq(_quantity(node), stats.quantity, "branch quantity");
            assertEq(_pathKey(node), stats.maxPathKey, "branch max path");
            assertGt(_quantity(node), stats.maxPathLeafQuantity, "branch quantity over max leaf");
            _assertStoredNodeKeyRepresentsSubtree(node, stats, isBidTree);
        }
        _assertSubtreePricePriority(stats, isBidTree);
        _assertSinglePriceFastPathCoversSubtree(stats, leftStats, rightStats);
        _assertRightSpineSamePriceFastPathPrecondition(rightmost, node, leftNode, rightNode, stats);
        if (stats.leftmostPrice == stats.rightmostPrice) {
            assertEq(_price(node), stats.leftmostPrice, "single-price branch node price");
        }
    }

    function _assertRightSpineQuantityUpperBounds(bytes32 node) private view {
        while (node != bytes32(0) && _isBranch(node)) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
            uint192 actualQuantity = _actualSubtreeQuantity(node);

            assertGe(uint256(_quantity(node)), uint256(actualQuantity), "right spine quantity bound");
            assertTrue(leftNode != node, "right spine left self-cycle");
            assertTrue(rightNode != node, "right spine right self-cycle");
            assertTrue(leftNode != rightNode, "right spine duplicate children");

            node = rightNode;
        }
    }

    function _actualSubtreeQuantity(bytes32 node) private view returns (uint192 quantity) {
        if (node == bytes32(0)) return 0;

        if (!_isBranch(node)) return _quantity(node);

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        quantity = _actualSubtreeQuantity(leftNode);
        quantity += _actualSubtreeQuantity(rightNode);
    }

    function _assertBranchOrder(uint8 branchDepth, SubtreeStats memory leftStats, SubtreeStats memory rightStats)
        private
        pure
    {
        assertTrue(leftStats.exists, "left subtree");
        assertTrue(rightStats.exists, "right subtree");
        assertLt(leftStats.maxKey, rightStats.minKey, "branch order");
        assertFalse(_bit(leftStats.minKey, branchDepth), "left min bit");
        assertFalse(_bit(leftStats.maxKey, branchDepth), "left max bit");
        assertTrue(_bit(rightStats.minKey, branchDepth), "right min bit");
        assertTrue(_bit(rightStats.maxKey, branchDepth), "right max bit");
        assertEq(_commonPrefix(leftStats.minKey, rightStats.minKey), branchDepth, "branch min split");
        assertEq(_commonPrefix(leftStats.minKey, rightStats.maxKey), branchDepth, "branch outer split");
        assertEq(_commonPrefix(leftStats.maxKey, rightStats.minKey), branchDepth, "branch inner split");
        assertEq(_commonPrefix(leftStats.maxKey, rightStats.maxKey), branchDepth, "branch max split");
        if (leftStats.minKey != leftStats.maxKey) {
            assertGe(_commonPrefix(leftStats.minKey, leftStats.maxKey), branchDepth + 1, "left prefix");
        }
        if (rightStats.minKey != rightStats.maxKey) {
            assertGe(_commonPrefix(rightStats.minKey, rightStats.maxKey), branchDepth + 1, "right prefix");
        }
    }

    function _assertStoredBranchOrder(
        bytes32 leftNode,
        bytes32 rightNode,
        SubtreeStats memory leftStats,
        SubtreeStats memory rightStats,
        bool isBidTree
    ) private pure {
        uint8 storedBranchDepth = _commonPrefix(
            _storedNodeKey(leftNode, isBidTree), _storedNodeKey(rightNode, isBidTree)
        );
        _assertBranchOrder(storedBranchDepth, leftStats, rightStats);
    }

    function _assertStoredNodeKeyRepresentsSubtree(bytes32 node, SubtreeStats memory stats, bool isBidTree)
        private
        pure
    {
        uint64 storedKey = _storedNodeKey(node, isBidTree);
        assertGe(storedKey, stats.minKey, "node key below subtree");
        assertLe(storedKey, stats.maxKey, "node key above subtree");
    }

    function _assertSubtreePricePriority(SubtreeStats memory stats, bool isBidTree) private pure {
        if (isBidTree) {
            assertLe(stats.leftmostPrice, stats.rightmostPrice, "bid subtree price priority");
        } else {
            assertGe(stats.leftmostPrice, stats.rightmostPrice, "ask subtree price priority");
        }
    }

    function _assertSinglePriceFastPathCoversSubtree(
        SubtreeStats memory stats,
        SubtreeStats memory leftStats,
        SubtreeStats memory rightStats
    ) private pure {
        if (stats.leftmostPrice != stats.rightmostPrice) return;

        uint24 price = stats.leftmostPrice;
        assertEq(leftStats.leftmostPrice, price, "single-price left min");
        assertEq(leftStats.rightmostPrice, price, "single-price left max");
        assertEq(rightStats.leftmostPrice, price, "single-price right min");
        assertEq(rightStats.rightmostPrice, price, "single-price right max");
    }

    function _assertRightSpineSamePriceFastPathPrecondition(
        bool rightmost,
        bytes32 node,
        bytes32 leftNode,
        bytes32 rightNode,
        SubtreeStats memory stats
    ) private pure {
        if (!rightmost || _price(leftNode) != _price(rightNode)) return;

        assertEq(stats.leftmostPrice, stats.rightmostPrice, "right-spine same-price check mixed subtree");
        assertEq(_price(node), stats.leftmostPrice, "right-spine same-price node price");
    }

    function _assertNoSharedBranches(bytes32 bidNode, bytes32 askRoot) private view {
        if (bidNode == bytes32(0) || !_isBranch(bidNode)) return;

        _assertBranchAbsentFromSubtree(bidNode, askRoot);
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(bidNode);
        _assertNoSharedBranches(leftNode, askRoot);
        _assertNoSharedBranches(rightNode, askRoot);
    }

    function _assertBranchAbsentFromSubtree(bytes32 targetBranch, bytes32 node) private view {
        if (node == bytes32(0) || !_isBranch(node)) return;

        assertTrue(targetBranch != node, "shared branch");
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        _assertBranchAbsentFromSubtree(targetBranch, leftNode);
        _assertBranchAbsentFromSubtree(targetBranch, rightNode);
    }

    function _assertUniqueLiveNodes(bytes32 node, bytes32[] memory seenNodes, uint256 seenCount)
        private
        view
        returns (uint256)
    {
        if (node == bytes32(0)) return seenCount;

        for (uint256 i; i < seenCount; ++i) {
            assertTrue(seenNodes[i] != node, "duplicate live node");
        }
        assertLt(seenCount, seenNodes.length, "seen node capacity");
        seenNodes[seenCount++] = node;

        if (!_isBranch(node)) return seenCount;

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        seenCount = _assertUniqueLiveNodes(leftNode, seenNodes, seenCount);
        return _assertUniqueLiveNodes(rightNode, seenNodes, seenCount);
    }

    function _assertBranchesReachableByContractRouting(bytes32 root, bytes32 node, bool isBidTree) private view {
        if (node == bytes32(0) || !_isBranch(node)) return;

        assertTrue(_containsBranchByContractRouting(root, node, isBidTree), "unreachable live branch");

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        _assertBranchesReachableByContractRouting(root, leftNode, isBidTree);
        _assertBranchesReachableByContractRouting(root, rightNode, isBidTree);
    }

    function _assertOwnedLiveBranchesBackedByPartialOrders(bytes32 node, bool isBidTree) private view {
        if (node == bytes32(0) || !_isBranch(node)) return;

        address owner = engine.ownerOfOrder(node);
        if (owner != address(0)) _assertOwnedBranchBackedByPartialOrder(node, owner, isBidTree);

        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        _assertOwnedLiveBranchesBackedByPartialOrders(leftNode, isBidTree);
        _assertOwnedLiveBranchesBackedByPartialOrders(rightNode, isBidTree);
    }

    function _assertOwnedBranchBackedByPartialOrder(bytes32 branchNode, address owner, bool isBidTree) private view {
        uint256 matches;
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order, address trackedOwner, bool trackedIsBid, bool active) = handler.orderAt(i);
            if (order != branchNode) continue;

            assertTrue(active, "owned branch inactive order");
            assertEq(trackedOwner, owner, "owned branch owner");
            assertEq(trackedIsBid, isBidTree, "owned branch side");
            assertGt(handler.remainingQuantityAt(i), 0, "owned branch filled order");
            assertLt(handler.remainingQuantityAt(i), _quantity(order), "owned branch unfilled order");
            ++matches;
        }

        assertEq(matches, 1, "owned branch backing");
    }

    function _containsBranchByContractRouting(bytes32 root, bytes32 target, bool isBidTree)
        private
        view
        returns (bool)
    {
        uint64 targetKey = _storedNodeKey(target, isBidTree);

        while (root != bytes32(0)) {
            if (root == target) return true;

            (bytes32 leftNode, bytes32 rightNode) = engine.tree(root);
            if (leftNode == bytes32(0) && rightNode == bytes32(0)) return false;

            uint64 leftKey = _storedNodeKey(leftNode, isBidTree);
            uint8 branchDepth = _commonPrefix(leftKey, _storedNodeKey(rightNode, isBidTree));
            if (_commonPrefix(targetKey, leftKey) < branchDepth) return false;

            root = _bit(targetKey, branchDepth) ? rightNode : leftNode;
        }

        return false;
    }

    function _assertUniqueLiveLeafSideKeys(bytes32 node, bytes32[] memory seenSideKeys, uint256 seenCount)
        private
        view
        returns (uint256)
    {
        if (node == bytes32(0)) return seenCount;

        if (_isBranch(node)) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
            seenCount = _assertUniqueLiveLeafSideKeys(leftNode, seenSideKeys, seenCount);
            return _assertUniqueLiveLeafSideKeys(rightNode, seenSideKeys, seenCount);
        }

        bytes32 sideKey = _sideKey(node);
        for (uint256 i; i < seenCount; ++i) {
            assertTrue(seenSideKeys[i] != sideKey, "duplicate live side key");
        }
        assertLt(seenCount, seenSideKeys.length, "seen side key capacity");
        seenSideKeys[seenCount++] = sideKey;
        return seenCount;
    }

    function _assertLeavesBackedByActiveOrders(bytes32 node, bool isBidTree) private view {
        if (node == bytes32(0)) return;

        if (_isBranch(node)) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
            _assertLeavesBackedByActiveOrders(leftNode, isBidTree);
            _assertLeavesBackedByActiveOrders(rightNode, isBidTree);
            return;
        }

        uint256 matches;
        bytes32 leafSideKey = _sideKey(node);
        uint192 leafQuantity = _quantity(node);
        uint256 length = handler.orderCount();

        for (uint256 i; i < length; ++i) {
            (bytes32 order, address owner, bool trackedIsBid, bool active) = handler.orderAt(i);
            if (!active || trackedIsBid != isBidTree || _sideKey(order) != leafSideKey) continue;

            assertGe(_quantity(order), leafQuantity, "leaf over original quantity");
            assertEq(handler.remainingQuantityAt(i), leafQuantity, "leaf remaining");
            assertEq(engine.ownerOfOrder(order), owner, "leaf owner");
            if (leafQuantity == _quantity(order)) {
                assertEq(engine.ownerOfOrder(node), owner, "unfilled leaf owner");
            } else {
                assertEq(engine.ownerOfOrder(node), address(0), "partial leaf owner");
            }
            ++matches;
        }

        assertEq(matches, 1, "leaf backing");
    }

    function _rightmostLeafPrice(bytes32 node) private view returns (uint24) {
        return _price(_rightmostLeaf(node));
    }

    function _rightmostLeaf(bytes32 node) private view returns (bytes32) {
        assertTrue(node != bytes32(0), "best price root");

        while (_isBranch(node)) {
            (, bytes32 rightNode) = engine.tree(node);
            node = rightNode;
        }

        return node;
    }

    function _find(bytes32 root, bytes32 order, bool isBidTree) private view returns (bytes32) {
        uint64 targetKey = _sortKey(order, isBidTree);

        while (root != bytes32(0) && _isBranch(root)) {
            uint8 branchDepth = _branchDepth(root, isBidTree);
            if (_commonPrefix(targetKey, _nodeKey(root, isBidTree)) < branchDepth) return bytes32(0);

            (bytes32 leftNode, bytes32 rightNode) = engine.tree(root);
            root = _bit(targetKey, branchDepth) ? rightNode : leftNode;
        }

        return root != bytes32(0) && _sortKey(root, isBidTree) == targetKey ? root : bytes32(0);
    }

    function _findByContractRouting(bytes32 root, bytes32 order, bool isBidTree) private view returns (bytes32) {
        uint64 targetKey = _sortKey(order, isBidTree);

        while (root != bytes32(0)) {
            (bytes32 leftNode, bytes32 rightNode) = engine.tree(root);
            if (leftNode == bytes32(0)) return _sortKey(root, isBidTree) == targetKey ? root : bytes32(0);

            uint64 leftKey = _sortKey(leftNode, isBidTree);
            uint8 branchDepth = _commonPrefix(leftKey, _sortKey(rightNode, isBidTree));
            if (_commonPrefix(targetKey, leftKey) < branchDepth) return bytes32(0);

            root = _bit(targetKey, branchDepth) ? rightNode : leftNode;
        }

        return bytes32(0);
    }

    function _isBranch(bytes32 node) private view returns (bool) {
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        return leftNode != bytes32(0) || rightNode != bytes32(0);
    }

    function _branchDepth(bytes32 branchNode, bool isBidTree) private view returns (uint8) {
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(branchNode);
        return _commonPrefix(_nodeKey(leftNode, isBidTree), _nodeKey(rightNode, isBidTree));
    }

    function _nodeKey(bytes32 node, bool isBidTree) private view returns (uint64) {
        if (!_isBranch(node)) return _sortKey(node, isBidTree);
        (bytes32 leftNode, bytes32 rightNode) = engine.tree(node);
        return _nodeKey(leftNode != bytes32(0) ? leftNode : rightNode, isBidTree);
    }

    function _storedNodeKey(bytes32 node, bool isBidTree) private pure returns (uint64) {
        return _sortKey(node, isBidTree);
    }

    function _branchNodeForChildren(bytes32 leftNode, bytes32 rightNode) private pure returns (bytes32) {
        uint64 leftAddressKey = _nodeAddressKey(leftNode);
        uint64 rightAddressKey = _nodeAddressKey(rightNode);
        assertTrue(leftAddressKey != rightAddressKey, "branch address key");

        uint192 quantity = _quantity(leftNode) + _quantity(rightNode);
        uint64 prefix = leftAddressKey > rightAddressKey ? leftAddressKey : rightAddressKey;
        // forge-lint: disable-next-line(unsafe-typecast)
        uint24 prefixPrice = uint24(prefix >> 40);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 prefixNonce = uint40(prefix);
        return _pack(prefixPrice, quantity, prefixNonce);
    }

    function _nodeAddressKey(bytes32 node) private pure returns (uint64) {
        return _pathKey(node);
    }

    function _sortKey(bytes32 order, bool isBidTree) private pure returns (uint64) {
        uint24 price = _price(order);
        uint40 nonce = _nonce(order);
        uint24 sortablePrice = isBidTree ? price : _MAX_PRICE - price;
        return (uint64(sortablePrice) << 40) | uint64(nonce);
    }

    function _isBetterBid(bytes32 candidate, bytes32 currentBest) private pure returns (bool) {
        uint24 candidatePrice = _price(candidate);
        uint24 bestPrice = _price(currentBest);
        return candidatePrice > bestPrice || candidatePrice == bestPrice && _nonce(candidate) > _nonce(currentBest);
    }

    function _isBetterAsk(bytes32 candidate, bytes32 currentBest) private pure returns (bool) {
        uint24 candidatePrice = _price(candidate);
        uint24 bestPrice = _price(currentBest);
        return candidatePrice < bestPrice || candidatePrice == bestPrice && _nonce(candidate) > _nonce(currentBest);
    }

    function _pathKey(bytes32 order) private pure returns (uint64) {
        return (uint64(_price(order)) << 40) | uint64(_nonce(order));
    }

    function _commonPrefix(uint64 a, uint64 b) private pure returns (uint8 prefixLength) {
        for (; prefixLength < 64; ++prefixLength) {
            if (_bit(a, prefixLength) != _bit(b, prefixLength)) return prefixLength;
        }
    }

    function _bit(uint64 key, uint8 depth) private pure returns (bool) {
        return ((key >> (63 - depth)) & 1) == 1;
    }

    function _quoteValue(uint24 price, uint192 quantity) private pure returns (uint256) {
        return uint256(price) * uint256(quantity);
    }

    function _sideKey(bytes32 order) private pure returns (bytes32) {
        return _pack(_price(order), 0, _nonce(order));
    }

    function _pack(uint24 price, uint192 quantity, uint40 nonce) private pure returns (bytes32) {
        return bytes32((uint256(price) << _PRICE_SHIFT) | (uint256(quantity) << _QUANTITY_SHIFT) | uint256(nonce));
    }

    function _price(bytes32 order) private pure returns (uint24) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint24(uint256(order) >> _PRICE_SHIFT);
    }

    function _quantity(bytes32 order) private pure returns (uint192) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint192((uint256(order) >> _QUANTITY_SHIFT) & _QUANTITY_MASK);
    }

    function _nonce(bytes32 order) private pure returns (uint40) {
        return uint40(uint256(order));
    }
}
