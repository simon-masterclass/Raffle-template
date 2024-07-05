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

    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    address link_token_contract = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 2;

    // Storage parameters
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint64 public s_subscriptionId;
    address s_owner;

    /* Events */
    event RaffleEntered(address indexed player);

    /* Constructor */
    constructor(uint256 entranceFee) VRFConsumerBaseV2(vrfCoordinator)  {
        i_entranceFee = entranceFee;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link_token_contract);
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
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
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
