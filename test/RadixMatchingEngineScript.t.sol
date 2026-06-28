// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RadixMatchingEngineScript} from "../script/RadixMatchingEngine.s.sol";
import {RadixMatchingEngine} from "../src/RadixMatchingEngine.sol";
import {TestERC20} from "./RadixMatchingEngine.t.sol";

contract RadixMatchingEngineScriptTest is Test {
    function test_RunDeploysEngineWithConfiguredTokens() public {
        TestERC20 base = new TestERC20("Base", "BASE");
        TestERC20 quote = new TestERC20("Quote", "QUOTE");

        // forge-lint: disable-next-line(unsafe-cheatcode)
        vm.setEnv("BASE_TOKEN", vm.toString(address(base)));
        // forge-lint: disable-next-line(unsafe-cheatcode)
        vm.setEnv("QUOTE_TOKEN", vm.toString(address(quote)));

        RadixMatchingEngine engine = new RadixMatchingEngineScript().run();

        assertEq(engine.BASE_TOKEN(), address(base));
        assertEq(engine.QUOTE_TOKEN(), address(quote));
        assertEq(engine.bidRoot(), bytes32(0));
        assertEq(engine.askRoot(), bytes32(0));
        assertEq(engine.nextNonce(), type(uint40).max);
    }
}
