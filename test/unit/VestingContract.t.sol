// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployVestingContract} from "script/DeployVestingContract.s.sol";
import {VestifyToken} from "src/VestifyToken.sol";
import {VestingContract} from "src/VestingContract.sol";

contract VestingContractTest is Test {
    DeployVestingContract vestingContractDeployer;
    VestingContract vestingContract;
    VestifyToken vestifyToken;

    function setUp() external {
        vestingContractDeployer = new DeployVestingContract();
        (vestingContract, vestifyToken) = vestingContractDeployer.run();
    }

    function testThatCorrectTokenAddressIsStored() public view {
        assert(
            vestingContract.getVestifyTokenContract() == address(vestifyToken)
        );
    }
}
