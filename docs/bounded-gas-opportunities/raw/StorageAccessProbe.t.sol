// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {RadixMatchingEngineGasTest} from "./RadixMatchingEngineGas.t.sol";

contract StorageAccessProbe is RadixMatchingEngineGasTest {
    function testStorage_DeepBidCancellation() public {
        vm.pauseGasMetering();
        bytes32 order = _buildFullDepthBidNonceComb();
        vm.resumeGasMetering();
        vm.startStateDiffRecording();
        vm.prank(alice);
        _cancel(order);
        _report();
    }

    function testStorage_DeepBidFill() public {
        vm.pauseGasMetering();
        _buildFullDepthBidNonceComb();
        vm.resumeGasMetering();
        vm.startStateDiffRecording();
        vm.prank(bob);
        _fill(_order(type(int32).min, 1, 0), false);
        _report();
    }

    function testStorage_LargeBookMatch() public {
        vm.pauseGasMetering();
        LargeRandomBook memory book = _buildLargeRandomBook();
        vm.resumeGasMetering();
        vm.startStateDiffRecording();
        vm.prank(carol);
        _fill(_order(book.bestAskPrice, book.bestAskQuantity, 0), true);
        _report();
    }

    function testStorage_ZeroQuoteAskCancellation() public {
        vm.pauseGasMetering();
        bytes32 order;
        for (uint256 i; i < 8; ++i) {
            vm.prank(bob);
            bytes32 added = _fill(_order(-1000 - int32(uint32(i * 1000)), 1, 0), false);
            if (i == 3) order = added;
        }
        vm.resumeGasMetering();
        vm.startStateDiffRecording();
        vm.prank(bob);
        _cancel(order);
        _report();
    }

    function testStorage_DeepAskCancellation() public {
        vm.pauseGasMetering();
        bytes32 order = _buildMaxValidDepthAskNonceComb();
        vm.resumeGasMetering();
        vm.startStateDiffRecording();
        vm.prank(alice);
        _cancel(order);
        _report();
    }

    function _report() private {
        Vm.AccountAccess[] memory accounts = vm.stopAndReturnStateDiff();
        uint256 reads;
        uint256 writes;
        uint256 unchangedWrites;
        for (uint256 i; i < accounts.length; ++i) {
            for (uint256 j; j < accounts[i].storageAccesses.length; ++j) {
                Vm.StorageAccess memory access = accounts[i].storageAccesses[j];
                if (access.account != address(engine) || access.reverted) continue;
                if (access.isWrite) {
                    ++writes;
                    if (access.previousValue == access.newValue) ++unchangedWrites;
                } else {
                    ++reads;
                }
            }
        }
        emit log_named_uint("engine recorded reads", reads);
        emit log_named_uint("engine recorded writes", writes);
        emit log_named_uint("unchanged engine writes", unchangedWrites);
    }
}
