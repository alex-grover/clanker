// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ClankerTokenFactory} from "../src/ClankerTokenFactory.sol";

contract DeployScript is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        ClankerTokenFactory factory = new ClankerTokenFactory(
            address(0), // TODO
            60,
            100,
            payable(address(0)), // TODO
            1000000000e18,
            -138200
        );

        vm.stopBroadcast();

        return address(factory);
    }
}
