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
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* Error Codes */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOver();
    error Raffle__onlyRaffleOwnerCanCallThisFunction();

    /* Constants */
    uint256 private immutable i_interval;

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private s_lastRaffleTimestamp;

    /* Chainlink VRF Variables */
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    // Chainlink VRF parameters - Avalanche Fuji Testnet
    // address immutable i_vrfCoordinator = 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE;
    // address immutable i_link_token_contract = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    // bytes32 immutable i_keyHash = 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887;
    // address private immutable i_vrfCoordinator;
    address private immutable i_link_token_contract;
    bytes32 private immutable i_keyHash;

    // Misc Chainlink VRF parameters
    uint16 constant REQUEST_CONFIRMATION = 3;
    uint32 constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;

    // Storage parameters
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint64 public s_subscriptionId;
    address private s_owner;

    /* Events */
    event RaffleEntered(address indexed player);

    /* Modifiers */
    modifier onlyRaffleOwner() {
        if (msg.sender != s_owner) {
            revert Raffle__onlyRaffleOwnerCanCallThisFunction();
        }
        _;
    }

    /* Constructor */
    constructor(uint256 entranceFee_, uint256 interval_, address owner_, uint32 callbackGasLimit_, address vrfCoordinator_)
        VRFConsumerBaseV2Plus(vrfCoordinator_)
    {
        i_entranceFee = entranceFee_;
        i_interval = interval_;
        s_owner = owner_;
        
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator_);
        LINKTOKEN = LinkTokenInterface(i_link_token_contract);

        s_lastRaffleTimestamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit_;

        // Create a new subscription when you deploy the contract.
        createNewSubscription();
    }
    // Create a new subscription when the contract is initially deployed.

    function createNewSubscription() private onlyRaffleOwner {
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

    function pickWinner() external onlyRaffleOwner {
        // 1. Get random number from Chainlink VRF
        // 2. Pick winner based on random number (automatically done by Chainlink VRF)
        // 3. Transfer winnings to winner and reset raffle
        if (block.timestamp - s_lastRaffleTimestamp < i_interval) {
            revert Raffle__RaffleNotOver();
        }

        // Request random number from Chainlink VRF
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: s_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1(false))
        });
    }

    // Chainlink maintenance fuction: Assumes this contract owns link.
    // 1000000000000000000 = 1 LINK
    function topUpSubscription(uint256 amount) external onlyRaffleOwner {
        LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subscriptionId));
    }
    // Chainlink automation subscription maintenance fuction

    function addConsumer(address consumerAddress) external onlyRaffleOwner {
        // Add a consumer contract to the subscription.
        COORDINATOR.addConsumer(s_subscriptionId, consumerAddress);
    }
    // Chainlink automation subscription maintenance fuction

    function removeConsumer(address consumerAddress) external onlyRaffleOwner {
        // Remove a consumer contract from the subscription.
        COORDINATOR.removeConsumer(s_subscriptionId, consumerAddress);
    }
    // Chainlink automation subscription maintenance fuction

    function cancelSubscription(address receivingWallet) external onlyRaffleOwner {
        // Cancel the subscription and send the remaining LINK to a wallet address.
        COORDINATOR.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

    // Transfer this contract's funds to an address.
    // 1000000000000000000 = 1 LINK
    function withdrawLinkTokens(uint256 amount, address to) external onlyRaffleOwner {
        LINKTOKEN.transfer(to, amount);
    }

    /* Chainlink Functions */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        s_randomWords = randomWords;
    }
    // Assumes the subscription is funded sufficiently.

    function requestRandomWords() external {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            i_keyHash, s_subscriptionId, REQUEST_CONFIRMATION, i_callbackGasLimit, NUM_WORDS
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
