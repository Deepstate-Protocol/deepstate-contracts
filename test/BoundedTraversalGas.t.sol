// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {DeepstateV1} from "../src/DeepstateV1.sol";
import {RadixMatchingEngineGasTest} from "./RadixMatchingEngineGas.t.sol";

contract WorstCaseBurningHook {
    function execute(bytes32, bytes32, address, uint160, uint32) external pure {
        assembly { for {} 1 {} {} }
    }
}

contract RadixMatchingEngineGasTestWideSweep is RadixMatchingEngineGasTest {
    address internal constant SWEEPER = address(0x5AEE9);
    address internal constant FEE_RECIPIENT = address(0xFEE1);

    function testGas_MixedSweep64() public {
        _sweep(64, 0, false);
    }

    function testGas_MixedSweep256() public {
        _sweep(256, 0, false);
    }

    function testGas_MixedSweep1024() public {
        _sweep(1024, 0, false);
    }

    function testGas_MixedSweep4096() public {
        _sweep(4096, 0, false);
    }

    function testGas_MixedSweep1024AndRest() public {
        _sweep(1024, 5, false);
    }

    function testGas_MixedSweep1024BurningHookAndFees() public {
        _sweep(1024, 0, true);
    }

    function testGas_MixedSweep1024RestBurningHooksAndFees() public {
        _sweep(1024, 5, true);
    }

    function testGas_MixedSweep4096RestBurningHooksAndFees() public {
        _sweep(4096, 5, true);
    }

    function testGas_MixedSweep1024FitsOneMillionGas() public {
        vm.pauseGasMetering();
        (, uint256 quoteAmount) = _seed(1024);
        bytes memory data = abi.encodeCall(engine.fill, (_params(1024, 0)));
        uint256 input = quote.balanceOf(SWEEPER);
        vm.prank(SWEEPER);
        vm.resumeGasMetering();
        (bool success,) = address(engine).call{gas: 1_000_000}(data);
        vm.pauseGasMetering();
        assertTrue(success, "cached sweep must fit one million gas");
        assertEq(_askRoot(), bytes32(0));
        assertEq(base.balanceOf(SWEEPER), 1024);
        assertEq(quote.balanceOf(SWEEPER), input - quoteAmount);
        vm.resumeGasMetering();
    }

    function _sweep(uint256 count, uint160 remainder, bool expensiveHookAndFees) private {
        vm.pauseGasMetering();
        (bytes32[] memory orders, uint256 quoteAmount) = _seed(count);
        if (expensiveHookAndFees) {
            WorstCaseBurningHook hook = new WorstCaseBurningHook();
            engine.setPoolHookConfig(address(base), address(quote), address(hook), true, true);
            engine.setFeeConfig(FEE_RECIPIENT, 100);
        }
        uint256 collateral = _quoteValue(type(int32).max, remainder, true);
        uint256 input = quote.balanceOf(SWEEPER);
        DeepstateV1.FillParams memory params = _params(count, remainder);
        vm.prank(SWEEPER);
        vm.resumeGasMetering();
        bytes32 rested = engine.fill(params);
        vm.pauseGasMetering();
        if (expensiveHookAndFees) {
            // Cleanup runs unmetered; disable the deliberately gas-exhausting callback first.
            engine.setPoolHookConfig(address(base), address(quote), address(0), false, false);
        }

        uint256 fee = expensiveHookAndFees ? count / 100 : 0;
        assertEq(_askRoot(), bytes32(0));
        assertEq(base.balanceOf(SWEEPER), count - fee);
        assertEq(base.balanceOf(FEE_RECIPIENT), fee);
        assertEq(quote.balanceOf(SWEEPER), input - quoteAmount - collateral);
        assertEq(_quantity(rested), remainder);
        if (remainder != 0) assertEq(_ownerOfOrder(rested), SWEEPER);
        for (uint256 i; i < orders.length; ++i) {
            vm.prank(bob);
            _cancel(orders[i]);
        }
        assertEq(quote.balanceOf(address(engine)), collateral);
        assertEq(base.balanceOf(address(engine)), 0);
        if (rested != bytes32(0)) {
            vm.prank(SWEEPER);
            _cancel(rested);
        }
        assertEq(quote.balanceOf(address(engine)), 0);
        assertEq(_bidRoot(), bytes32(0));
        vm.resumeGasMetering();
    }

    function _seed(uint256 count) private returns (bytes32[] memory orders, uint256 quoteAmount) {
        quote.mint(SWEEPER, uint256(1) << 220);
        vm.prank(SWEEPER);
        quote.approve(address(engine), type(uint256).max);
        orders = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            // Odd multiplication permutes the positive int32 ticks: every price is distinct.
            int32 tick = int32(uint32(i * 0x1e3779b9 + 0x01765431) & 0x7fffffff);
            quoteAmount += _quoteValue(tick, 1, false);
            vm.prank(bob);
            orders[i] = _fill(_order(tick, 1, 0), false);
        }
    }

    function _params(uint256 count, uint160 remainder) private view returns (DeepstateV1.FillParams memory) {
        return DeepstateV1.FillParams({
            token0: address(base),
            token1: address(quote),
            epoch: 0,
            order: _order(type(int32).max, uint160(count) + remainder, 0),
            isBid: true,
            noRest: remainder == 0,
            fillOrKill: false
        });
    }
}
