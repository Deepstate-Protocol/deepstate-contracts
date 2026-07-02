// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {RoutingEngine} from "../src/RoutingEngine.sol";

contract RadixMatchingEngineScript is Script {
    function run() public returns (RoutingEngine engine) {
        vm.startBroadcast();
        engine = new RoutingEngine();
        vm.stopBroadcast();
    }
}
