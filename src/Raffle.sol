// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle contract with provably fair random number generation
 * @author c0 | X: @c0mmanderZero
 * @notice This contract is a work in progress and is not yet ready for deployment.
 * @dev Implements Chainlink VRFv2 for random number generation
 */
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* Error Codes */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);
    error Raffle__RaffleNotOpen();
    error Raffle__onlyRaffleOwnerCanCallThisFunction();
    error Raffle__TransferToWinnerFailed();

    /* Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* Constants and Immutable Variables (set in constructor)*/
    uint256 private immutable i_interval;
    // Misc Chainlink VRF parameters
    uint16 constant REQUEST_CONFIRMATION = 3;
    uint32 constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    bool private immutable i_nativePayment;
    // Chainlink VRF parameters - Avalanche Fuji Testnet
    // address fuji_Link_token_contract_address = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    // bytes32 fuji_keyHash = 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887;
    // address fuji_vrfCoordinator = 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE;
    bytes32 private immutable i_keyHash4GasLane;

    /* Link token contract interface */
    LinkTokenInterface s_LinkToken;

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private s_lastRaffleTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Storage parameters
    uint256[] public s_randomWords;
    uint256 public s_subscriptionId;
    address private s_owner;

    /* Events */
    event RaffleEntered(address indexed player);
    event RaffleWinnerPicked(address indexed winner, uint256 winnings);

    /* Modifiers */
    modifier onlyRaffleOwner() {
        if (msg.sender != s_owner) {
            revert Raffle__onlyRaffleOwnerCanCallThisFunction();
        }
        _;
    }

    /* Constructor */
    constructor(
        uint256 entranceFee_,
        uint256 interval_,
        bool nativePayment_,
        uint32 callbackGasLimit_,
        address owner_,
        address linkTokenAddress,
        bytes32 keyHash4GasLane_,
        uint256 subscriptionId_,
        address vrfCoordinator_
    ) VRFConsumerBaseV2Plus(vrfCoordinator_) {
        // set Immutable Entrance fee
        i_entranceFee = entranceFee_;
        // set Raffle time interval - Weekly, Monthly, etc...
        i_interval = interval_;
        // if Native Payments is true, VRF services are paid in native currency instead of Link token
        i_nativePayment = nativePayment_;
        i_callbackGasLimit = callbackGasLimit_;
        s_owner = owner_;

        s_LinkToken = LinkTokenInterface(linkTokenAddress);
        i_keyHash4GasLane = keyHash4GasLane_;

        // Set initial Raffle starting parameters
        s_lastRaffleTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;

        // Create a new subscription when you deploy the contract.
        s_subscriptionId = subscriptionId_;
        // createNewSubscription();
    }

    // Create a new subscription when the contract is initially deployed.
    function createNewSubscription() internal {
        s_subscriptionId = s_vrfCoordinator.createSubscription();
        // Add this contract as a consumer of its own subscription.
        s_vrfCoordinator.addConsumer(s_subscriptionId, address(this));
    }

    /* External Functions */
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Raffle: Not enough ETH sent to enter.");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState == RaffleState.CALCULATING) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true for for upkeepNeeded to be true:
     * 1. The time interval has passed between raffles.
     * 2. The raffle must be open.
     * 3. The contract has ETH in it.
     * 4. Implicitly, your subscription has Link in it.
     * @param - ignore checkData
     * @return upkeepNeeded - true if the raffle is ready to be picked
     * @return performData  - empty string - it is not used in this contract
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastRaffleTimestamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        bool upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        // 1. Get random number from Chainlink VRF
        // 2. Pick winner based on random number (automatically done by Chainlink VRF)
        // 3. Transfer winnings to winner and reset raffle
        (bool upKeepNeeded,) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        // Close the raffle to prevent more entries
        s_raffleState = RaffleState.CALCULATING;

        // Request random number from Chainlink VRF
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash4GasLane,
            subId: s_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay the fee in native currency instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: i_nativePayment}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        requestId;
    }

    /* Chainlink Random Number Callback Override Function */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        // s_randomWords = randomWords;
        // Pick winner based on random number
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];

        // Reset raffle
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastRaffleTimestamp = block.timestamp;

        uint256 winnings = address(this).balance;
        emit RaffleWinnerPicked(s_recentWinner, winnings);

        // Transfer winnings to winner and reset raffle
        (bool success,) = s_recentWinner.call{value: winnings}("");
        if (!success) {
            revert Raffle__TransferToWinnerFailed();
        }

        // Emit event - winner picked!
    }

    // Chainlink maintenance fuction: Assumes this contract owns link.
    // 1000000000000000000 = 1 LINK
    function topUpSubscription(uint256 amount) external onlyRaffleOwner {
        s_LinkToken.transferAndCall(address(s_vrfCoordinator), amount, abi.encode(s_subscriptionId));
    }

    // Chainlink automation subscription maintenance fuction
    function addConsumer(address consumerAddress) external onlyRaffleOwner {
        // Add a consumer contract to the subscription.
        s_vrfCoordinator.addConsumer(s_subscriptionId, consumerAddress);
    }

    // Chainlink automation subscription maintenance fuction
    function removeConsumer(address consumerAddress) external onlyRaffleOwner {
        // Remove a consumer contract from the subscription.
        s_vrfCoordinator.removeConsumer(s_subscriptionId, consumerAddress);
    }

    // Chainlink automation subscription maintenance fuction
    function cancelSubscription(address receivingWallet) external onlyRaffleOwner {
        // Cancel the subscription and send the remaining LINK to a wallet address.
        s_vrfCoordinator.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

    // Transfer this contract's funds to an address.
    // 1000000000000000000 = 1 LINK
    function withdrawLinkTokens(uint256 amount, address to) external onlyRaffleOwner {
        s_LinkToken.transfer(to, amount);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            GETTER FUNCTIONS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }
    
    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }
}

