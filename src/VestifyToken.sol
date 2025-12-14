// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

/**
 * @title Vestify token
 * @notice ERC20 token with time-locked vesting support
 * @dev Inherits from open zeppelin's ERC20 contract
 */
contract VestifyToken is ERC20, Ownable {
    constructor(
        uint256 initialSupply
    ) ERC20("Vestify", "VSF") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Only deployer can mint new tokens
     * @param address Destination address for minted tokens
     * @param value The amount of tokens to mint
     */
    function mint(address account, uint256 value) external onlyOwner {
        _mint(account, value);
    }

    /**
     * @dev Only deployer can burn tokens
     * @param address The address to destroy tokens from
     * @param value The amount of tokens to destroy
     */
    function burn(address account, uint256 value) external onlyOwner {
        _burn(account, value);
    }
}
