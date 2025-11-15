// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "src/MyToken.sol";

contract DeployMyToken is Script {
    uint16 private constant INITIAL_SUPPLY = 1000;
    MyToken public myToken;

    function run() public {
        vm.startBroadcast();
        myToken = new MyToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
    }
}
