// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RadixMatchingEngineScript} from "../script/RadixMatchingEngine.s.sol";
import {RoutingEngine} from "../src/RoutingEngine.sol";

contract RadixMatchingEngineScriptTest is Test {
    function test_RunDeploysRoutingEngine() public {
        RoutingEngine engine = new RadixMatchingEngineScript().run();

        assertEq(engine.poolEpoch(bytes32(0)), 0);
    }
}
