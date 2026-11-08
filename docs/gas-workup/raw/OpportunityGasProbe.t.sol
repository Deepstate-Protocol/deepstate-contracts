// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {RadixMatchingEngineGasTest} from "./RadixMatchingEngineGas.t.sol";

contract OpportunityGasProbe is RadixMatchingEngineGasTest {
    function testOpportunity_RestAsk16Orders() public {
        _rest(false, 16, false, false);
    }

    function testOpportunity_RestAsk64Orders() public {
        _rest(false, 64, false, false);
    }

    function testOpportunity_RestBid16Orders() public {
        _rest(true, 16, false, false);
    }

    function testOpportunity_RestBid64Orders() public {
        _rest(true, 64, false, false);
    }

    function testOpportunity_RestAskLeftNonceComb() public {
        _rest(false, 27, true, false);
    }

    function testOpportunity_RestBidLeftNonceComb() public {
        _rest(true, 27, true, false);
    }

    function testOpportunity_RestAskDirtyLeftNonceComb() public {
        _rest(false, 27, true, true);
    }

    function testOpportunity_RestBidDirtyLeftNonceComb() public {
        _rest(true, 27, true, true);
    }

    function testOpportunity_RestAskDifferentTickLeftNonceComb() public {
        _restAt(false, 27, true, false, 40);
    }

    function testOpportunity_RestBidDifferentTickLeftNonceComb() public {
        _restAt(true, 27, true, false, 60);
    }

    function testOpportunity_RestAskWorseTickLeftNonceComb() public {
        _restAt(false, 27, true, false, 60);
    }

    function testOpportunity_RestBidWorseTickLeftNonceComb() public {
        _restAt(true, 27, true, false, 40);
    }

    function _rest(bool isBid, uint256 count, bool comb, bool dirty) private {
        _restAt(isBid, count, comb, dirty, 50);
    }

    function _restAt(bool isBid, uint256 count, bool comb, bool dirty, int32 tick) private {
        vm.pauseGasMetering();
        for (uint256 i; i < count; ++i) {
            if (comb && i != 0) _forceNextOrderNonce(type(uint32).max >> uint32(i));
            vm.prank(alice);
            _fill(_order(50, 10, 0), isBid);
        }
        if (dirty) {
            vm.prank(carol);
            _fill(_order(50, 1, 0), !isBid);
        }
        vm.prank(bob);
        vm.resumeGasMetering();
        bytes32 order = _fill(_order(tick, 5, 0), isBid);
        vm.pauseGasMetering();
        assertEq(_quantity(order), 5);
        assertEq(engine.ownerOfOrder(engine.orderId(_bookId(), order)), bob);
        bytes32 root = isBid ? _bidRoot() : _askRoot();
        assertEq(_quantity(root), count * 10 + 5 - (dirty ? 1 : 0));
        vm.resumeGasMetering();
    }
}
