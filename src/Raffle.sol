// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Raffle contract with provably fair random number generation
 * @author c0 | X: @c0mmanderZero
 * @notice This contract is a work in progress and is not yet ready for deployment.
 * @dev Implements Chainlink VRFv2 for random number generation
 */

contract Raffle {
    uint256 private immutable i_entranceFee;

    error Raffle_InsufficientFunds();
    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }   

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Raffle: Not enough ETH sent to enter.");
        if (msg.value < i_entranceFee) {
            revert Raffle_InsufficientFunds();
        }
    }

    function pickWinner() public {

    }

    /* Getter Functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function revertWithError() public view {
        if (getEntranceFee() < 69){
        revert Raffle_InsufficientFunds();
        }
    }

    function revertWithRequire() public view {
        require((getEntranceFee() >= 69), "Raffle: Not enough ETH sent to enter.");
    }

}
