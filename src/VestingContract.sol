// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {
    AutomationCompatibleInterface
} from "@chainlink-contracts/automation/AutomationCompatible.sol";
import {
    AutomationBase
} from "@chainlink-contracts/automation/AutomationBase.sol";

/**
 * @title Vesting Contract
 * @notice Manages locked and released Vestify tokens
 */
contract VestingContract is
    Ownable,
    AutomationCompatibleInterface,
    AutomationBase
{
    // Types
    struct VestingSchedule {
        address beneficiaryAddress;
        uint256 startTimestamp;
        uint256 lastTimestamp;
        uint256 endTimestamp;
        uint256 cliffTimestamp;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 withdrawnAmount;
        uint256 amountPerDay;
    }

    // State variables
    uint256 private vestifyTokenBalance;
    uint256 private s_nextIndexToProcess;
    uint256 private constant BATCH_SIZE = 10;
    uint256 private constant ONE_DAY_IN_SECONDS = 24 * 60 * 60;
    mapping(address beneficiary => uint256 vestingScheduleIndex) private s_beneficiaryToVestingScheduleIndexPlusOne;
    VestingSchedule[] private s_vestingScheduleList;

    // Errors
    error VestingContract__AmountNotGreaterThanZero();
    error VestingContract__InvalidVestingPeriod();
    error VestingContract__InsufficientFunds();
    error VestingContract__CliffPeriodNotReached();
    error VestingContract__BeneficiaryDoesNotExist();

    //Events
    event VestingScheduleCreated(address indexed beneficiary);
    event WithdrawalCompleted(address indexed beneficiary);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Creates a new vesting schedule for a user
     * @param beneficiaryAddress The address of the user receiving the vested tokens
     * @param startTimestamp The timestamp when vesting begins
     * @param endTimestamp The timestamp when vesting ends
     * @param cliffTimestamp The timestamp before which no tokens can be released
     * @param totalAmount The total amount of tokens to be vested
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 cliffTimestamp,
        uint256 totalAmount
    ) external onlyOwner {
        if (totalAmount == 0)
            revert VestingContract__AmountNotGreaterThanZero();

        if (startTimestamp > cliffTimestamp || cliffTimestamp > endTimestamp)
            revert VestingContract__InvalidVestingPeriod();

        // Transfer vestify tokens from caller to this contract
        IERC20(address(0)).transferFrom(msg.sender, address(this), totalAmount);

        uint256 amountPerDay = totalAmount /
            ((endTimestamp - startTimestamp) / ONE_DAY_IN_SECONDS);

        VestingSchedule memory newVestingSchedule = VestingSchedule({
            beneficiaryAddress: beneficiary,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            cliffTimestamp: cliffTimestamp,
            totalAmount: totalAmount,
            releasedAmount: 0,
            withdrawnAmount: 0,
            lastTimestamp: block.timestamp,
            amountPerDay: amountPerDay
        });

        s_vestingScheduleList.push(newVestingSchedule);
        s_beneficiaryToVestingScheduleIndexPlusOne[beneficiary] = s_vestingScheduleList.length; //we index + 1 becuase default mapping value is 0

        emit VestingScheduleCreated(beneficiary);
    }

    function checkUpkeep(
        bytes calldata
        // checkData
    )
        external
        view
        override
        cannotExecute
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 count = 0;
        uint256 startIndex = s_nextIndexToProces;
        uint256 nextIndexToProcess;
        uint256[] memory idsToProcess = new uint256[](
            s_vestingScheduleList.length
        );

        for (
            uint256 i = startIndex;
            i < s_vestingScheduleList.length && count < BATCH_SIZE;
            i++
        ) {
            bool shouldProcessSchedule = (block.timestamp -
                s_vestingScheduleList[i].lastTimestamp >
                ONE_DAY_IN_SECONDS) &&
                (s_vestingScheduleList[i].releasedAmount <
                    s_vestingScheduleList[i].totalAmount) &&
                (block.timestamp < s_vestingScheduleList[i].endTimestamp);

            if (shouldProcessSchedule) {
                idsToProcess[count] = i;
                count = count + 1;
            }

            if(count == BATCH_SIZE - 1){
                nextIndexToProcess = i + 1;
            }

            //If we've run through all the schedules, reset to 0
            if(i == s_vestingScheduleList.length - 1){
                nextIndexToProcess = 0;
            }
        }

        if (count > 0) {
            //  resize array to match count to remvove empty spaces
            assembly {
                mstore(idsToProcess, count)
            }
        }

        if (idsToProcess.length > 0) {
            return (true, abi.encode(idsToProcess, nextIndexToProcess));
        } else {
            return (false, "");
        }
    }

//TODO: The Docs mentioned something about any body being able to call performUpkeep, so we need to do some checks, in this case someone could change the value of s_nextIndexToProcess or idsToProcess, to get rewards faster
    function performUpkeep(bytes calldata performData) external override {
        (uint256[] memory idsToProcess, uint256 nextIndexToProcess ) = abi.decode(performData, (uint256[], uint256));
        s_nextIndexToProcess = nextIndexToProcess;

        for (uint256 i = 0; i < idsToProcess.length; i++) {
            uint256 amountToRelease = s_vestingScheduleList[idsToProcess[i]].amountPerDay;

            if (
                s_vestingScheduleList[idsToProcess[i]].releasedAmount + amountToRelease >
                s_vestingScheduleList[idsToProcess[i]].totalAmount
            ) {
                amountToRelease =
                    s_vestingScheduleList[idsToProcess[i]].totalAmount -
                    s_vestingScheduleList[idsToProcess[i]].releasedAmount;
            }

            s_vestingScheduleList[idsToProcess[i]].releasedAmount += amountToRelease;
            s_vestingScheduleList[idsToProcess[i]].lastTimestamp = block.timestamp;
        }
    }

    function withdrawFunds(uint256 amount) external {
        uint256 vestingScheduleIndexPlusOne = s_beneficiaryToVestingScheduleIndexPlusOne[msg.sender];

        if(vestingScheduleIndexPlusOne == 0) revert VestingContract__BeneficiaryDoesNotExist();                
        if(s_vestingScheduleList[vestingScheduleIndexPlusOne - 1].cliffTimestamp > block.timestamp) revert VestingContract__CliffPeriodNotReached();

        uint256 amountAvailable = s_vestingScheduleList[vestingScheduleIndexPlusOne - 1].releasedAmount - s_vestingScheduleList[vestingScheduleIndexPlusOne - 1].withdrawnAmount;

        if(amount > amountAvailable){
            revert VestingContract__InsufficientFunds();
        }

        s_vestingScheduleList[vestingScheduleIndexPlusOne - 1].withdrawnAmount += amount;

        // Transfer vestify tokens from this contract to beneficiary
        IERC20(address(0)).transferFrom(address(this), msg.sender, amount);
        
        emit WithdrawalCompleted(msg.sender);
    }
}
