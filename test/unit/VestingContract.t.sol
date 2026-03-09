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
    address BENEFICIARY = makeAddr("beneficiary");

    function setUp() external {
        vestingContractDeployer = new DeployVestingContract();
        (vestingContract, vestifyToken) = vestingContractDeployer.run();
    }

    function testThatCorrectTokenAddressIsStored() public view {
        assert(
            vestingContract.getVestifyTokenContract() == address(vestifyToken)
        );
    }

    function testThatScheduleIsCreatedCorrectly() public {
        uint256 startTimestamp = block.timestamp + (1 * 24 * 60 * 60); //start one day from now
        uint256 endTimestamp = block.timestamp + (14 * 24 * 60 * 60); //end 14 days from now
        uint256 cliffTimestamp = block.timestamp + (4 * 24 * 60 * 60); //start 4 days from now
        uint256 totalAmount = 50e18;

        vm.startPrank(DEFAULT_SENDER);
        vestifyToken.approve(address(vestingContract), totalAmount);
        vestingContract.createVestingSchedule(
            BENEFICIARY,
            startTimestamp,
            endTimestamp,
            cliffTimestamp,
            totalAmount
        );
        vm.stopPrank();

        VestingContract.VestingSchedule
            memory newVestingSchedule = vestingContract.getVestingSchedule(
                BENEFICIARY
            );

        assert(startTimestamp == newVestingSchedule.startTimestamp);
        assert(endTimestamp == newVestingSchedule.endTimestamp);
        assert(cliffTimestamp == newVestingSchedule.cliffTimestamp);
        assert(totalAmount == newVestingSchedule.totalAmount);
    }

    function testThatRevertHappensWithInvalidStartDate() public {
        vm.warp(10 days);
        vm.roll(block.number + 5);

        vm.startPrank(DEFAULT_SENDER);

        uint256 startTimestamp = block.timestamp - (1 * 24 * 60 * 60); //start one day ago
        uint256 endTimestamp = block.timestamp + (14 * 24 * 60 * 60); //end 14 days from now
        uint256 cliffTimestamp = block.timestamp + (4 * 24 * 60 * 60); //start 4 days from now
        uint256 totalAmount = 50e18;

        vestifyToken.approve(address(vestingContract), totalAmount);

        vm.expectRevert(
            VestingContract.VestingContract__InvalidVestingPeriod.selector
        );
        vestingContract.createVestingSchedule(
            BENEFICIARY,
            startTimestamp,
            endTimestamp,
            cliffTimestamp,
            totalAmount
        );
        vm.stopPrank();
    }

    function testThatRevertHappensWithInvalidEndDate() public {
        vm.warp(10 days);
        vm.roll(block.number + 5);

        vm.startPrank(DEFAULT_SENDER);

        uint256 startTimestamp = block.timestamp - (1 * 24 * 60 * 60); //start one day ago
        uint256 endTimestamp = block.timestamp; //end date is now
        uint256 cliffTimestamp = block.timestamp + (4 * 24 * 60 * 60); //start 4 days from now
        uint256 totalAmount = 50e18;

        vestifyToken.approve(address(vestingContract), totalAmount);

        vm.expectRevert(
            VestingContract.VestingContract__InvalidVestingPeriod.selector
        );
        vestingContract.createVestingSchedule(
            BENEFICIARY,
            startTimestamp,
            endTimestamp,
            cliffTimestamp,
            totalAmount
        );
        vm.stopPrank();
    }

    function testThatRevertHappensWithInvalidCliffDate() public {
        vm.warp(10 days);
        vm.roll(block.number + 5);

        vm.startPrank(DEFAULT_SENDER);

        uint256 startTimestamp = block.timestamp - (1 * 24 * 60 * 60); //start one day ago
        uint256 endTimestamp = block.timestamp + (14 * 24 * 60 * 60); //end 14 days from now
        uint256 cliffTimestamp = block.timestamp; //start now
        uint256 totalAmount = 50e18;

        vestifyToken.approve(address(vestingContract), totalAmount);

        vm.expectRevert(
            VestingContract.VestingContract__InvalidVestingPeriod.selector
        );
        vestingContract.createVestingSchedule(
            BENEFICIARY,
            startTimestamp,
            endTimestamp,
            cliffTimestamp,
            totalAmount
        );
        vm.stopPrank();
    }

    function testThatRevertHappensWithInvalidVestingDuration() public {
        vm.warp(10 days);
        vm.roll(block.number + 5);

        vm.startPrank(DEFAULT_SENDER);

        uint256 startTimestamp = block.timestamp - (1 * 24 * 60 * 60); //start one day ago
        uint256 endTimestamp = block.timestamp + (6 * 24 * 60 * 60); //end 6 days from now
        uint256 cliffTimestamp = block.timestamp + (4 * 24 * 60 * 60); //start 4 days from now
        uint256 totalAmount = 50e18;

        vestifyToken.approve(address(vestingContract), totalAmount);

        vm.expectRevert(
            VestingContract.VestingContract__InvalidVestingPeriod.selector
        );
        vestingContract.createVestingSchedule(
            BENEFICIARY,
            startTimestamp,
            endTimestamp,
            cliffTimestamp,
            totalAmount
        );
        vm.stopPrank();
    }
}
