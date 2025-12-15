// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/**
* @title Vesting Contract
* @notice Manages locked and released Vestify tokens
 */
contract VestingContract is Ownable {
    // Types
    struct VestingSchedule {
        address user;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 cliffTimestamp;
        uint256 totalAmount;
        uint256 releasedAmount;
    }

    // State variables
    uint256 vestifyTokenBalance;
    VestingSchedule[] private s_vestingScheduleList;
    mapping(address => uint256) s_addressToVestingIdxPlusOne;

    constructor() Ownable(msg.sender) {}

    /**
    * @notice Creates a new vesting schedule for a user
    * @param user The address of the user receiving the vested tokens
    * @param startTimestamp The timestamp when vesting begins
    * @param endTimestamp The timestamp when vesting ends
    * @param cliffTimestamp The timestamp before which no tokens can be released
    * @param totalAmount The total amount of tokens to be vested
    * @param releasedAmount The amount of tokens already released
     */
    function createVestingSchedule(
        address user,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 cliffTimestamp,
        uint256 totalAmount,
        uint256 releasedAmount
    ) external onlyOwner {
        // Transfer vestify tokens from caller to this contract
        IERC20(address(0)).transferFrom(msg.sender, address(this), totalAmount);

        VestingSchedule newVestingSchedule = VestingSchedule({
            user,
            startTimestamp, 
            endTimestamp,
            cliffTimestamp,
            totalAmount,
            releasedAmount
        });

       s_addressToVestingIdxPlusOne[user] = s_vestingScheduleList.length + 1;
       s_vestingScheduleList.push(newVestingSchedule);
    }
}
