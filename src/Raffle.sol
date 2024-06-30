// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Raffle contract with provably fair random number generation
 * @author c0 | X: @c0mmanderZero
 * @notice This contract is a work in progress and is not yet ready for deployment.
 * @dev Implements Chainlink VRFv2 for random number generation
 */

contract Raffle {
    /* Error Codes */
    error Raffle__SendMoreToEnterRaffle();

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Events */
    event RaffleEntered(address indexed player);

    /* Constructor */
    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }   

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Raffle: Not enough ETH sent to enter.");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender); 
    }

    function pickWinner() external {
        // 1. Get random number from Chainlink VRF
        // 2. Pick winner based on random number (automatically done by Chainlink VRF)
        // 3. Transfer winnings to winner and reset raffle
        block.timestamp -


    }

    /* Getter Functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
