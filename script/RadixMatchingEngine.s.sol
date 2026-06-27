// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {RadixMatchingEngine} from "../src/RadixMatchingEngine.sol";

contract RadixMatchingEngineScript is Script {
    function run() public returns (RadixMatchingEngine engine) {
        address baseToken = vm.envAddress("BASE_TOKEN");
        address quoteToken = vm.envAddress("QUOTE_TOKEN");

        vm.startBroadcast();
        engine = new RadixMatchingEngine(baseToken, quoteToken);
        vm.stopBroadcast();
    }
}
