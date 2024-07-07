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
    error Raffle__OnlyOwnerCanCallThisFunction();

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
    address private s_owner;
    
    /* Events */
    event RaffleEntered(address indexed player);

    /* Modifiers */
    modifier onlyOwner() {
        if(msg.sender != s_owner) 
            revert Raffle__OnlyOwnerCanCallThisFunction();
        _;
    }

    /* Constructor */
    constructor(uint256 entranceFee_, address owner_) VRFConsumerBaseV2(i_vrfCoordinator)  {
        i_entranceFee = entranceFee_;
        COORDINATOR = VRFCoordinatorV2Interface(i_vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(i_link_token_contract);

        s_owner = owner_;
        // Create a new subscription when you deploy the contract.
        createNewSubscription();
    }   
    // Create a new subscription when the contract is initially deployed.
    function createNewSubscription() private onlyOwner {
        s_subscriptionId = COORDINATOR.createSubscription();
        // Add this contract as a consumer of its own subscription.
        COORDINATOR.addConsumer(s_subscriptionId, address(this));
    }

    /* External Functions */
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Raffle: Not enough ETH sent to enter.");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender); 
    }

    function pickWinner() external onlyOwner {
        // 1. Get random number from Chainlink VRF
        // 2. Pick winner based on random number (automatically done by Chainlink VRF)
        // 3. Transfer winnings to winner and reset raffle
        if (block.timestamp - s_lastRaffleTimestamp < i_interval) {
            revert Raffle__RaffleNotOver();
        }

    }

    // Chainlink maintenance fuction: Assumes this contract owns link.
    // 1000000000000000000 = 1 LINK
    function topUpSubscription(uint256 amount) external onlyOwner {
        LINKTOKEN.transferAndCall(
            address(COORDINATOR),
            amount,
            abi.encode(s_subscriptionId)
        );
    }
    // Chainlink automation subscription maintenance fuction
    function addConsumer(address consumerAddress) external onlyOwner {
        // Add a consumer contract to the subscription.
        COORDINATOR.addConsumer(s_subscriptionId, consumerAddress);
    }
    // Chainlink automation subscription maintenance fuction
    function removeConsumer(address consumerAddress) external onlyOwner {
        // Remove a consumer contract from the subscription.
        COORDINATOR.removeConsumer(s_subscriptionId, consumerAddress);
    }
    // Chainlink automation subscription maintenance fuction
    function cancelSubscription(address receivingWallet) external onlyOwner {
        // Cancel the subscription and send the remaining LINK to a wallet address.
        COORDINATOR.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

    // Transfer this contract's funds to an address.
    // 1000000000000000000 = 1 LINK
    function withdrawLinkTokens(uint256 amount, address to) external onlyOwner {
        LINKTOKEN.transfer(to, amount);
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
