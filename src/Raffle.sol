// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Raffle contract with provably fair random number generation
 * @author c0 | X: @c0mmanderZero
 * @notice This contract is a work in progress and is not yet ready for deployment.
 * @dev Implements Chainlink VRFv2 for random number generation
 */

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    /* Error Codes */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOver();

    /* Constants */
    uint256 private constant i_interval = 1 weeks;

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private s_lastRaffleTimestamp;

    /* Chainlink VRF Variables */
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    // Chainlink VRF parameters - Avalanche Fuji Testnet
    address immutable i_vrfCoordinator = 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE;
    address immutable i_link_token_contract = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    bytes32 immutable i_keyHash = 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887;
    // A reasonable default is 100000, but this value could be different on other networks.
    uint32 immutable i_callbackGasLimit = 100000;
    uint16 immutable i_requestConfirmations = 3;
    uint32 immutable i_numWords = 1;

    // Storage parameters
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint64 public s_subscriptionId;
    address s_owner;

    /* Events */
    event RaffleEntered(address indexed player);

    /* Constructor */
    constructor(uint256 entranceFee) VRFConsumerBaseV2(i_vrfCoordinator)  {
        i_entranceFee = entranceFee;
        COORDINATOR = VRFCoordinatorV2Interface(i_vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(i_link_token_contract);
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
        if (block.timestamp - s_lastRaffleTimestamp < i_interval) {
            revert Raffle__RaffleNotOver();
        }

    }

    /* Chainlink Functions */
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
    }
    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() external {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            i_keyHash,
            s_subscriptionId,
            i_requestConfirmations,
            i_callbackGasLimit,
            i_numWords
        );
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
