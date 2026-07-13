// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeepstateV1Script} from "../script/DeepstateV1.s.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";

contract DeepstateV1ScriptTest is Test {
    function test_RunDeploysDeepstateV1() public {
        DeepstateV1 engine = new DeepstateV1Script().run();

        assertEq(engine.poolEpoch(bytes32(0)), 0);
    }
}
