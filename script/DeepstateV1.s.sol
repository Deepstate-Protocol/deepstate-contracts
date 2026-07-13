// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {DeepstateV1} from "../src/DeepstateV1.sol";

contract DeepstateV1Script is Script {
    function run() public returns (DeepstateV1 engine) {
        vm.startBroadcast();
        engine = new DeepstateV1();
        vm.stopBroadcast();
    }
}
