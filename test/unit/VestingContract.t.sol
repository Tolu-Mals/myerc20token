// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
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

    modifier timePassed() {
        vm.warp(10 days);
        vm.roll(block.number + 5);
        _;
    }

    function testThatRevertHappensWithInvalidStartDate() public timePassed {
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

    function testThatRevertHappensWithInvalidEndDate() public timePassed {
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

    function testThatRevertHappensWithInvalidCliffDate() public timePassed {
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

    function testThatRevertHappensWithInvalidVestingDuration()
        public
        timePassed
    {
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

    function testThatCheckupkeepReturnsFalseBeforeCliff() public {
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

        vm.prank(address(0), address(0));
        (bool checkUpkeep, ) = vestingContract.checkUpkeep("");

        assert(checkUpkeep == false);
    }

    modifier timePassedCliff() {
        vm.warp(10 days);
        vm.roll(block.number + 5);
        _;
    }

    function testThatCheckupkeepReturnsTrueAfterCliff() public timePassedCliff {
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
        vm.warp(block.timestamp + 5 days);

        vm.prank(address(0), address(0));
        (bool checkUpkeep, ) = vestingContract.checkUpkeep("");

        assert(checkUpkeep == true);
    }

    function testThatPerformUpkeepRevertsWithInvalidCallData() public {
        uint256 startTimestamp = block.timestamp + (1 * 24 * 60 * 60); //start one day from now
        uint256 endTimestamp = block.timestamp + (14 * 24 * 60 * 60); //end 14 days from now
        uint256 cliffTimestamp = block.timestamp + (4 * 24 * 60 * 60); //start 4 days from now
        uint256 totalAmount = 50e18;

        vm.startPrank(DEFAULT_SENDER);
        vestifyToken.approve(address(vestingContract), totalAmount * 5);
        for (uint256 i = 0; i < 5; i++) {
            vestingContract.createVestingSchedule(
                makeAddr(string.concat("beneficiary", vm.toString(i))),
                startTimestamp,
                endTimestamp,
                cliffTimestamp,
                totalAmount
            );
        }
        vm.stopPrank();

        vm.prank(address(0), address(0));
        uint256[] memory idsToProcess = new uint256[](5);
        for (uint256 i = 0; i < idsToProcess.length; i++) {
            idsToProcess[i] = 1;
        }
        bytes memory callData = abi.encode(idsToProcess);
        vm.expectRevert(
            VestingContract.VestingContract__InvalidPerformData.selector
        );
        vestingContract.performUpkeep(callData);
    }

    function testThatPerformUpkeepWorksCorrectly() public {
        uint256 startTimestamp = block.timestamp + (1 * 24 * 60 * 60); //start one day from now
        uint256 endTimestamp = block.timestamp + (14 * 24 * 60 * 60); //end 14 days from now
        uint256 cliffTimestamp = block.timestamp + (4 * 24 * 60 * 60); //start 4 days from now
        uint256 totalAmount = 50e18;

        vm.startPrank(DEFAULT_SENDER);
        vestifyToken.approve(address(vestingContract), totalAmount * 5);
        for (uint256 i = 0; i < 5; i++) {
            vestingContract.createVestingSchedule(
                makeAddr(string.concat("beneficiary", vm.toString(i))),
                startTimestamp,
                endTimestamp,
                cliffTimestamp,
                totalAmount
            );
        }
        vm.stopPrank();

        vm.warp(10 days);
        vm.roll(block.number + 5);

        vm.prank(address(0), address(0));
        (bool upkeepNeeded, bytes memory performData) = vestingContract
            .checkUpkeep("");
        assert(upkeepNeeded == true);

        vm.recordLogs();
        vestingContract.performUpkeep(performData);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 5);

        uint256 expectedAmount = totalAmount / 13;
        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                entries[i].topics[0],
                keccak256("TokensReleased(address,uint256)")
            );
            assertEq(
                address(uint160(uint256(entries[i].topics[1]))),
                makeAddr(string.concat("beneficiary", vm.toString(i)))
            );
            uint256 amount = abi.decode(entries[i].data, (uint256));
            assertEq(amount, expectedAmount);
        }
    }
}
