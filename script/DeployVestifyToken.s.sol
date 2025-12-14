// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {VestifyToken} from "src/VestifyToken.sol";

contract DeployMyToken is Script {
    uint16 private constant INITIAL_SUPPLY = 1000;
    VestifyToken public vestifyToken;

    function run() public {
        vm.startBroadcast();
        vestifyToken = new VestifyToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
    }
}
