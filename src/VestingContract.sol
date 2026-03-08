// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
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
    using SafeERC20 for IERC20;

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
    address private immutable s_tokenContract;
    uint256 private s_tokenBalance;
    uint256 private s_nextIndexToProcess;
    uint256 private constant BATCH_SIZE = 10;
    uint256 private constant ONE_DAY_IN_SECONDS = 24 * 60 * 60;
    uint256 private constant MIN_VESTING_PERIOD = 7 * ONE_DAY_IN_SECONDS;
    mapping(address beneficiary => uint256 vestingScheduleIndex)
        private s_beneficiaryToVestingScheduleIndexPlusOne;
    VestingSchedule[] private s_vestingScheduleList;

    // Errors
    error VestingContract__AmountNotGreaterThanZero();
    error VestingContract__InvalidVestingPeriod();
    error VestingContract__InsufficientFunds();
    error VestingContract__CliffPeriodNotReached();
    error VestingContract__BeneficiaryDoesNotExist();
    error VestingContract__InvalidPerformData();

    //Events
    event VestingScheduleCreated(address indexed beneficiary);
    event WithdrawalCompleted(address indexed beneficiary);

    constructor(address tokenContract) Ownable(msg.sender) {
        s_tokenContract = tokenContract;
    }

    /**
     * @notice Creates a new vesting schedule for a user
     * @param beneficiary The address of the user receiving the vested tokens
     * @param startTimestamp The timestamp when vesting begins
     * @param endTimestamp The timestamp when vesting ends
     * @param cliffTimestamp The timestamp before which no tokens can be withdrawn
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

        if (
            startTimestamp < block.timestamp ||
            startTimestamp > cliffTimestamp ||
            cliffTimestamp > endTimestamp ||
            endTimestamp - startTimestamp < MIN_VESTING_PERIOD
        ) revert VestingContract__InvalidVestingPeriod();

        // Transfer vestify tokens from caller to this contract
        IERC20(s_tokenContract).safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount
        );

        s_tokenBalance += totalAmount;

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
            lastTimestamp: startTimestamp,
            amountPerDay: amountPerDay
        });

        s_vestingScheduleList.push(newVestingSchedule);
        s_beneficiaryToVestingScheduleIndexPlusOne[
            beneficiary
        ] = s_vestingScheduleList.length; //we index + 1 becuase default mapping value is 0

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
        uint256 startIndex = s_nextIndexToProcess;
        uint256 idsToProcessCount = 0;

        //Get count of ids that need to be processed
        for (
            uint256 i = startIndex;
            i < s_vestingScheduleList.length && idsToProcessCount < BATCH_SIZE;
            i++
        ) {
            bool shouldProcessSchedule = (block.timestamp -
                s_vestingScheduleList[i].lastTimestamp >
                ONE_DAY_IN_SECONDS) &&
                (s_vestingScheduleList[i].releasedAmount <
                    s_vestingScheduleList[i].totalAmount);
            // (block.timestamp < s_vestingScheduleList[i].endTimestamp);

            if (shouldProcessSchedule) {
                idsToProcessCount++;
            }
        }

        uint256[] memory idsToProcess = new uint256[](idsToProcessCount);
        uint256 count = 0;

        //Determine ids to process, and the new values for released amount and last time stamp
        for (
            uint256 i = startIndex;
            i < s_vestingScheduleList.length && count < BATCH_SIZE;
            i++
        ) {
            bool shouldProcessSchedule = (block.timestamp -
                s_vestingScheduleList[i].lastTimestamp >
                ONE_DAY_IN_SECONDS) &&
                (s_vestingScheduleList[i].releasedAmount <
                    s_vestingScheduleList[i].totalAmount);
            // (block.timestamp < s_vestingScheduleList[i].endTimestamp);

            if (shouldProcessSchedule) {
                idsToProcess[count] = i;
                count++;
            }
        }

        if (idsToProcess.length > 0) {
            return (true, abi.encode(idsToProcess));
        } else {
            return (false, "");
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        (uint256[] memory idsToProcess) = abi.decode(performData, (uint256[]));

        for (uint256 i = 0; i < idsToProcess.length; i++) {
            uint256 index = idsToProcess[i];

            bool shouldProcessSchedule = (block.timestamp -
                s_vestingScheduleList[index].lastTimestamp >
                ONE_DAY_IN_SECONDS) &&
                (s_vestingScheduleList[index].releasedAmount <
                    s_vestingScheduleList[index].totalAmount);

            if (!shouldProcessSchedule) {
                revert VestingContract__InvalidPerformData();
            }

            uint256 amountToRelease = s_vestingScheduleList[index].amountPerDay;

            if (
                s_vestingScheduleList[index].releasedAmount + amountToRelease >
                s_vestingScheduleList[index].totalAmount
            ) {
                amountToRelease =
                    s_vestingScheduleList[index].totalAmount -
                    s_vestingScheduleList[index].releasedAmount;
            }

            s_vestingScheduleList[index].releasedAmount += amountToRelease;
            s_vestingScheduleList[index].lastTimestamp = block.timestamp;
        }

        uint256 lastProcessedIndex = idsToProcess[idsToProcess.length - 1];

        if (lastProcessedIndex == s_vestingScheduleList.length - 1) {
            s_nextIndexToProcess = 0;
        } else {
            s_nextIndexToProcess = lastProcessedIndex + 1;
        }
    }

    function withdrawFunds(uint256 amount) external {
        uint256 vestingScheduleIndexPlusOne = s_beneficiaryToVestingScheduleIndexPlusOne[
                msg.sender
            ];

        if (vestingScheduleIndexPlusOne == 0)
            revert VestingContract__BeneficiaryDoesNotExist();
        if (
            s_vestingScheduleList[vestingScheduleIndexPlusOne - 1]
                .cliffTimestamp > block.timestamp
        ) revert VestingContract__CliffPeriodNotReached();

        uint256 amountAvailable = s_vestingScheduleList[
            vestingScheduleIndexPlusOne - 1
        ].releasedAmount -
            s_vestingScheduleList[vestingScheduleIndexPlusOne - 1]
                .withdrawnAmount;

        if (amount > amountAvailable) {
            revert VestingContract__InsufficientFunds();
        }

        s_vestingScheduleList[vestingScheduleIndexPlusOne - 1]
            .withdrawnAmount += amount;

        // Transfer vestify tokens from this contract to beneficiary
        IERC20(s_tokenContract).safeTransfer(msg.sender, amount);

        s_tokenBalance = s_tokenBalance - amount;

        emit WithdrawalCompleted(msg.sender);
    }

    function getVestifyTokenBalance() public view returns (uint256) {
        return s_tokenBalance;
    }

    function getVestifyTokenContract() public view returns (address) {
        return s_tokenContract;
    }
}
