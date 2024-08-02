// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle Contract Tests
 * @author c0 | X: @c0mmanderZero
 * @notice This contract tests the Raffle contract and its functions, including interactions with Chainlink VRF
 * @notice The tests use the ARRANGE, ACT, ASSERT pattern
 * @dev This contract is configure to test on a local chain, Eth Sepolia, Arbitrum Sepolia and on the Avalanche Fuji Testnet
 */

import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
// special imports for testing
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract RaffleTest is Test, CodeConstants {
    // Contracts - Raffle and HelperConfig
    Raffle public raffle;
    HelperConfig public helperConfig;
    // Console log for debugging - console2.log("message", variable)

    using console2 for *;

    // Test Player
    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCE = 10 ether;

    // Helper Config values - will be used to setup the tests
    uint256 public entranceFee;
    uint256 public interval;
    bool public nativePayment; //extra variable - will probably require refactoring to implemnt if nativePayment is true
    uint32 public callbackGasLimit;
    address public linkTokenAddress; // thinking ahead
    bytes32 public keyHash4GasLane;
    uint256 public subscriptionId;
    address public vrfCoordinator;
    address public owner;

    // Other
    uint256 public INITIAL_RAFFLE_CONTRACT_ETH_DEPOSIT = 0.000055 ether;

    /* Events */
    event RaffleEntered(address indexed player);
    event RaffleWinnerPicked(address indexed winner, uint256 winnings);

    /* Modifiers */
    modifier playerEnteredRaffle() {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        // Setup: Player enters the raffle
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                        TEST INITIALIZATION SETUP
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

    // Setup: Setup will run before every test that follows - Deploying Raffle contract, VRF Mocks and get HelperConfig values
    function setUp() public {
        // ARRANGE
        if (TEST_CONSOLE_LOGS_TF) {
            console2.log("");
            console2.log("------------START OF SETUP------------");
            console2.log("");
            console2.log("");
            console2.log("+[0][0]-SETUP:B4-DEPLOYMENT-[0][0]+");
            console2.log("                    Owner address: ", owner);
            console2.log("                        tx.origin: ", tx.origin);
            console2.log("                       msg.sender: ", msg.sender);
            console2.log("+[0][0]-SETUP:B4-DEPLOYMENT-[0][0]+");
            // console2.log("");
        }
        // Setup: Deploy Raffle contract
        DeployRaffle deployRaffle = new DeployRaffle();
        // Setup: Get the Raffle contract and HelperConfig settings
        HelperConfig.NetworkConfig memory config;
        (raffle, config) = deployRaffle.deployContract();

        // Setup: Get the HelperConfig values for VRF setup and testing the Raffle contract
        entranceFee = config.entranceFee;
        interval = config.interval;
        nativePayment = config.nativePayment;
        callbackGasLimit = config.callbackGasLimit;
        linkTokenAddress = config.linkTokenAddress;
        keyHash4GasLane = config.keyHash4GasLane;
        subscriptionId = config.subscriptionId;
        vrfCoordinator = config.vrfCoordinator;
        owner = config.owner;   
        
        if (TEST_CONSOLE_LOGS_TF) {
            console2.log("               |                   ");
            console2.log("               V                   ");
            console2.log("+[0][0]-SETUP: AFTER-DEPLOY-[0][0]+");
            console2.log("                    Owner address: ", owner);
            console2.log("                        tx.origin: ", tx.origin);
            console2.log("                       msg.sender: ", msg.sender);
            console2.log("+[0][0]-SETUP: AFTER-DEPLOY-[0][0]+");
            console2.log("");
            console2.log(""); 
            console2.log("+[0][0]-SETUP:VRF-SUBSCRIBER_ID-[0][0]+");
            console2.log("        VRF Subscription ID in config: ", config.subscriptionId);
            console2.log("       Chain-Specific VRF Coordinator: ", config.vrfCoordinator);
            console2.log("             Chain ID - block.chainid: ", block.chainid);
            console2.log("+[0][0]-SETUP:VRF-SUBSCRIBER_ID-[0][0]+");
            console2.log("");
            console2.log("");
        }
        
        if (TEST_CONSOLE_LOGS_TF) {
            console2.log("+[0][0]-SETUP: B4-CALL-ETH-[0][0]+");
            console2.log(" B4::Raffle Contract Balance ETH: ", address(raffle).balance);
            console2.log(" B4::              Owner Address: ", owner);
            console2.log(" B4::          Owner Balance ETH: ", owner.balance);
            console2.log("+[0][0]-SETUP: B4-CALL-ETH-[0][0]+");
            console2.log("               |                  ");
            console2.log("               V                  ");
            // console2.log("+vvvvvvvvvvvvvvvvvvvvvvvvvvv+");
            // console2.log("+v v v v v v v v v v v v v v+");
            // console2.log("+ vv   vv    vvv    vv   vv +");
            // console2.log("    +   vv    v    vv  +     ");
            // console2.log("        +     v     +        ");
            // console2.log("           +  v  +           ");
            // console2.log("              v              ");
            // console2.log("");
        }
    
        // Setup: Fund the Raffle Contract with funds to pay the winner - 0.69 ether
        // Note that sending more than 1 ether will enter the sender into the lottery instead of providing funds for transactions 
        vm.prank(owner);
        (bool success,) = payable(raffle).call{value: INITIAL_RAFFLE_CONTRACT_ETH_DEPOSIT}("");
        require(success, "Failed to send funds to Raffle contract");

        // Setup: Fund player with STARTING_PLAYER_BALANCE = 10 ether; (for testing - subject to change)
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        // Setup: Get the player's balance
        if (TEST_CONSOLE_LOGS_TF) {
            console2.log("+[0][0]-SETUP: AFTER-CALL -[0][0]+");
            console2.log(" AF::Raffle Contract Balance ETH: ", address(raffle).balance);
            console2.log(" AF::              Owner Address: ", owner);
            console2.log(" AF::          Owner Balance ETH: ", owner.balance);
            console2.log("+[0][0]-SETUP: AFTER-CALL -[0][0]+");
            console2.log("");
            console2.log("+------------------------------+");
            console2.log("::               Player Address: ", PLAYER);
            console2.log("::           Player Balance ETH: ", PLAYER.balance);
            console2.log("::          Player Balance LINK: ", LinkTokenInterface(linkTokenAddress).balanceOf(address(PLAYER)));
            console2.log("::           Owner Balance LINK: ", LinkTokenInterface(linkTokenAddress).balanceOf(address(owner)));
            console2.log(":: Raffle Contract Balance LINK: ", LinkTokenInterface(linkTokenAddress).balanceOf(address(raffle)));
            console2.log("+------------------------------+");
            console2.log("");
            console2.log("------------END OF SETUP------------");
            console2.log("");
            console2.log("------------START OF TEST OUTPUT------------");
            console2.log("");
        }

    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            INITIAL BALANCE TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

    /**
     * TEST: Ensure the Raffle has and initial balance *
     */
    function test_InitialRaffleBalance() public view {
        // ASSERT
        // Verify: The Raffle contract has a balance of 0.69 ether
        assert(address(raffle).balance == INITIAL_RAFFLE_CONTRACT_ETH_DEPOSIT);
    }

    /**
     * TEST: Raffle state enum should Initialize In Open State
     */
    function test_RaffleInitializesInOpenState() public view {
        // ASSERT
        // Verify: The raffle is in the open state
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            ENTER RAFFLE TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

    /**
     * TEST: Player Can Enter Raffle When They Send Enough Funds Without Function Selector *
     */
    function test_RecieverCallsEnterRaffleFunctionWhenMoreThanEntranceFeeIsSent() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address

        // ACT
        // Execute: Player enters the raffle
        vm.startPrank(PLAYER);
        (bool success,) = payable(raffle).call{value: entranceFee*2}("");
        require(success, "Failed to send funds to Raffle contract");
        vm.stopPrank();        
        // ASSERT
        // Verify: The player is recorded in the raffle contract
        uint256 playerCount = raffle.getPlayerCount(); //Should be: playerCount = 1
        assert(playerCount == 1);
        //Should be: (playerCount - 1) = 0 = (1 - 1) = 0 index should return PLAYER address
        address playerRecorded = raffle.getPlayer(playerCount - 1);
        if (TEST_CONSOLE_LOGS_TF) {
            console2.log("Player recorded: ", playerRecorded);
            console2.log("Player expected: ", PLAYER);
        }
        // Assert the player is recorded in the raffle contract
        assert(playerRecorded == PLAYER);
    }

    /**
     * TEST: The Reciever Emits Event When MORE Than Entrance Fee Is Sent to the Raffle Contract without Function Selector *
     * Note: Player Can Enter Raffle When They Send Enough Funds without Specifying A Function Selector *
     */
    function test_ReceiverEmitsEventWhenMoreThanEntranceFeeIsSent() public {
        // ARRANGE
        // Setup: Send more than the entrance fee to the raffle contract
        uint256 amountSent = entranceFee * 2;
        // ACT
        // Execute: Prepare to record logs
        vm.recordLogs();
        // Execute: Player enters the raffle
        vm.startPrank(PLAYER);
        (bool success,) = payable(raffle).call{value: amountSent}("");
        require(success, "Failed to send funds to Raffle contract");
        vm.stopPrank();
        // Execute: Get the recorded logs -
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Note: the 0th log is the VRF contract events and 1st log is the Raffle contract logs with requestId being in the 1st log (index 0 reserved for VRF events)
        bytes32 playerInLogBytes = entries[1].topics[1];
        address playerInLogAddress = address(uint160(uint256(playerInLogBytes)));

        // ASSERT
        // Verify: The player is recorded in the raffle contract
        address playerRecorded = raffle.getPlayer(raffle.getPlayerCount() - 1);
        if (TEST_CONSOLE_LOGS_TF) {
            console2.log("Player recorded in Raffle Contract: ", playerRecorded);
            console2.log("            Player recorded in Log: ", playerInLogAddress);
            console2.log("                   Player expected: ", PLAYER);
        }   
        // Assert the player is recorded in the raffle contract
        assert(playerRecorded == PLAYER);
        // Assert the player is the sender of the transaction as recorded in the logs
        bytes32 playerRecordedBytes = bytes32(uint256(uint160(playerRecorded)));
        assert(playerInLogBytes == playerRecordedBytes);
    }

    /**
     * TEST: The Reciever Emits Event When LESS Than Entrance Fee Is Sent to the Raffle Contract without Function Selector *
     * Note: Player will Not be entered into the raffle when they send less than the entrance fee but will provide funds to the contract for 
     * VRF calls, transfers to winners and any other automatic transactions *
     */
    function test_ReceiverEmitsEventWhenLessThanEntranceFeeIsSent() public {
        // ARRANGE
        // Setup: Player will send 1 unit (wei) less than the entrance fee
        uint256 insufficientAmount = entranceFee - 1; 
        //ACT
        // Execute: Prepare to record logs
        vm.recordLogs();
        // Execute: Player enters the raffle
        vm.startPrank(PLAYER);
        (bool success,) = payable(raffle).call{value: insufficientAmount}("");
        require(success, "Failed to send funds to Raffle contract");
        vm.stopPrank();
        // Execute: Get the recorded logs -
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Note: the 0th log is the VRF contract events and 1st log is the Raffle contract logs with requestId being in the 1st log (index 0 reserved for VRF events)
        bytes32 playerInLogBytes = entries[0].topics[1];
        address playerInLogAddress = address(uint160(uint256(playerInLogBytes)));
        // ASSERT
        // Verify: Visually
        if (TEST_CONSOLE_LOGS_TF) {
            console2.log("Player recorded in Log: ", playerInLogAddress);
            console2.log("       Player expected: ", PLAYER);
        }
        // Assert the player is the sender of the transaction as recorded in the logs
        assert(playerInLogAddress == PLAYER);
    }

    /**
     * TEST: Raffle contract should Revert When a Player Does Not Send Enough To Enter *
     */
    function test_RaffleRevertsWhenPlayerDoesNotSendEnoughToEnter() public {
        // ARRANGE
        // Setup: Player will send 1 unit (wei) less than the entrance fee
        uint256 insufficientAmount = entranceFee - 1;
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);

        // ACT + ASSERT
        // Execute: Expect Specific Revert when player tries to enter the raffle with insufficient funds
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        // Execute: Player enters the raffle with insufficient funds
        raffle.enterRaffle{value: insufficientAmount}();
    }

    /**
     * TEST: Raffle contract should Revert When a Player Does Not Send Enough To Enter using Address of Player *
     */
    function test_RaffleRevertsWhenPlayerDoesNotSendEnoughToEnterUsingAddressFunction() public {
        // ARRANGE
        // Setup: Player will send 1 unit (wei) less than the entrance fee
        uint256 insufficientAmount = entranceFee - 1;
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);

        // ACT + ASSERT
        // Execute: Expect Specific Revert when player tries to enter the raffle with insufficient funds
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        // Execute: Player enters the raffle with insufficient funds
        raffle.enterRaffle{value: insufficientAmount}(PLAYER);
    }

    /**
     * TEST: Raffle contract should Record Players When Then Enter*
     */
    function test_RaffleRecordsPlayersWhenTheyEnter() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);

        // ACT
        // Execute: PLAYER Enters the raffle
        raffle.enterRaffle{value: entranceFee}();

        // ASSERT
        // Verify: The player is recorded in the raffle contract
        uint256 playerCount = raffle.getPlayerCount(); //Should be: playerCount = 1
        //Should be: (playerCount - 1) = 0 = (1 - 1) = 0 index should return PLAYER address
        address playerRecorded = raffle.getPlayer(playerCount - 1);
        assert(playerRecorded == PLAYER);
    }

    /**
     * TEST: Raffle contract should Emit Event When Player Enters *
     */
    function test_EnteringRaffleEmitsEvent() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);

        // ACT
        // Execute: Tell foundry the event to expect
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(address(PLAYER));

        // ASSERT
        // Verify: Enter the raffle and expect the event to be emitted
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * TEST: Contract should Not Allow Players To Enter Raffle When it Is in Calculating state *
     * Note: This test will fail on the Arbitrum Sepolia chain
     */
    function test_DoNotAllowPlayerToEnterWhenRaffleIsCalculating() public playerEnteredRaffle {
        // ARRANGE
        // Setup: Warp time + roll block number forward to when the raffle is ready to pick a winner
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 4);

        // ACT
        // Execute: Trigger Chainlink automated function to Use VRF to pick a winner and transfer funds
        raffle.performUpkeep("");

        // ASSERT
        // EXTRA TEST: Ensure the state of the raffle is calculating
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        // Execute + Verify: Expect Specific Revert when player tries to enter the raffle
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }
    
    /**
     * TEST: Contract should Not Allow Players To Enter Raffle When it Is in Calculating state use Address Function *
     * Note: This test will fail on the Arbitrum Sepolia chain
     */
    function test_DoNotAllowPlayerToEnterWhenRaffleIsCalculatingWhenUsingAddressEnterRaffle() public playerEnteredRaffle {
        // ARRANGE
        // Setup: Warp time + roll block number forward to when the raffle is ready to pick a winner
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 4);

        // ACT
        // Execute: Trigger Chainlink automated function to Use VRF to pick a winner and transfer funds
        raffle.performUpkeep("");

        // ASSERT
        // EXTRA TEST: Ensure the state of the raffle is calculating
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        // Execute + Verify: Expect Specific Revert when player tries to enter the raffle
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}(PLAYER);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            CHECK UPKEEP TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

    /**
     * TEST: Upkeep Needed should return true When it's Time to Pick a Winner*
     */
    function test_UpkeepNeededWhenTimeToPickWinner() public playerEnteredRaffle {
        // ARRANGE
        // Setup: Note that the player has entered the raffle - playerEnteredRaffle modifier
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // ACT
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // ASSERT
        // Verify: Expect upkeep to be needed
        assert(upKeepNeeded == true);
    }

    /**
     * TEST: Check Upkeep should Return False If It Has No Balance *
     */
    function test_CheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // ARRANGE
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // ACT
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // ASSERT
        // Verify: Expect upkeep to not be needed
        assert(upKeepNeeded == false);
    }

    /**
     * TEST: Check Upkeep should Return False If Raffle Isn't Open * ARB-SEPOLIA FAILS
     * Note: This test will fail on the Arbitrum Sepolia chain
     */
    function test_CheckUpkeepReturnsFalseIfRaffleIsntOpen() public playerEnteredRaffle {
        // ARRANGE
        // Setup: Note that the player has entered the raffle - playerEnteredRaffle modifier
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 4);

        // ACT
        // Execute: Trigger the Raffle to Use VRF to pick a winner, transfer funds and resets the raffle
        raffle.performUpkeep("");
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // ASSERT
        // Verify: Expect upkeep to not be needed
        assert(upKeepNeeded == false);
    }

    /**
     * TEST: Check Upkeep should Return False When Raffle Isn't Ready *
     */
    function test_CheckUpkeepReturnsFalseWhenRaffleIsNotReady() public playerEnteredRaffle {
        // ARRANGE
        // Setup: Note that the player has entered the raffle - playerEnteredRaffle modifier

        // ACT
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // ASSERT
        // Verify: Expect upkeep to not be needed
        assert(upKeepNeeded == false);
    }

    /**
     * TEST: Check Upkeep should Return False If Enough Time Has Passed With No Raffle Entries *
     */
    function test_CheckUpkeepReturnsFalseIfEnoughTimeHasPassedWithNoRaffleEntries() public {
        // ARRANGE
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // ACT
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // ASSERT
        // Verify: Expect upkeep to not be needed
        assert(upKeepNeeded == false);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            PERFORM UPKEEP TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

    /**
     * TEST: Perform Upkeep Should Revert When Raffle Is Not Ready *
     */
    function test_PerformUpkeepRevertsWhenRaffleIsNotReady() public {
        // ARRANGE
        // Setup: Set the current balance and number of players in the raffle
        uint256 currentBalance = address(raffle).balance;
        uint256 numPlayers = 0;
        // Setup: Get the current state of the raffle
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // ACT + ASSERT
        // Execute + Verify: Expect Specific Revert when trying to perform upkeep when upkeep is not needed
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        // Execute: Perform Upkeep and expect it to revert
        raffle.performUpkeep("");
    }

    /**
     * TEST: Perform Upkeep Should Revert With Specific Error When Upkeep Is Not Needed *
     */
    function test_PerformUpkeepRevertsWithSpecificErrorIfUpkeepNotNeeded() public {
        // ARRANGE
        // Setup: Set the current balance and number of players in the raffle
        uint256 currentBalance = address(raffle).balance;
        uint256 numPlayers = 0;
        // Setup: Get the current state of the raffle
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        // Setup: Player enters the raffle
        raffle.enterRaffle{value: entranceFee}();

        // Setup: Update the current balance and number of players in the raffle
        currentBalance = currentBalance + entranceFee;
        numPlayers = numPlayers + 1;

        // ACT + ASSERT
        // Execute + Verify: Expect Specific Revert when trying to perform upkeep when upkeep is not needed
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        // Execute: Perform Upkeep and expect it to revert
        raffle.performUpkeep("");
    }

    /**
     * TEST: Perform Upkeep Can Only Run If Check Upkeep Is True *
     * Note: This test will fail on the Arbitrum Sepolia chain
     */
    function test_PerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public playerEnteredRaffle {
        // ARRANGE
        // Setup: Note that the player has entered the raffle - playerEnteredRaffle modifier
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 4);

        // ACT + ASSERT
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        // Verify: Expect upkeep to be needed
        assert(upKeepNeeded == true);

        // Execute: Perform upkeep to see if it reverts
        raffle.performUpkeep("");
    }

    /**
     * TEST: Perform Upkeep Updates Raffle State And Emits Request Id *
     * Note: This test will fail on the Arbitrum Sepolia chain
     */
    function test_PerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public playerEnteredRaffle {
        // ARRANGE
        // Setup: Note that the player has entered the raffle - playerEnteredRaffle modifier
        // Setup: Move time + block number forward to when the raffle is ready to pick a winner
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 4);  

        // ACT
        // Execute: Prepare to record logs
        vm.recordLogs();
        // Execute: Perform upkeep to emit the request id
        raffle.performUpkeep("");
        // Execute: Get the recorded logs -
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Execute: Get the requestId from the logs
        // Note: the 0th log is the VRF contract events and 1st log is the Raffle contract logs with requestId being in the 1st log (index 0 reserved for VRF events)
        bytes32 requestId = entries[1].topics[1];

        // ASSERT
        // Verify: The requestId is emitted
        assert(uint256(requestId) > 0);
        // Verify: The raffle state is now calculating
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                        FULFILL RANDOMNESS TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

    // Skip calling these Chainlink functions on forks of live chains - only run Mock VRF function on the local chain
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAINID) {
            return;
        }
        _;
    }

    /**
     * TEST [FUZZ]: Fulfill Random Words function Can Only Be Called After Perform Upkeep *
     */
    function test_FulfillRandomWordsCanonlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        playerEnteredRaffle
        skipFork
    {
        // ARRANGE
        // Setup: Note that the player has entered the raffle - playerEnteredRaffle modifier
        // Setup: Nothing is done here - raffle is not ready to pick a winner

        // ACT + ASSERT
        // Execute + Verify: Expect Specific Revert when trying to fulfillRandomWords before performUpkeep
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    /**
     * TEST: Fulfill Random Words Picks A Winner, Resets And Sends Money *
     */
    function test_FulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public playerEnteredRaffle skipFork {
        // ARRANGE
        // Setup: Note that the player has entered the raffle - playerEnteredRaffle modifier
        // Setup: Add another 9 players to the raffle
        uint256 totalPlayers = 10;
        uint160 startingIndex = 1;
        // loop through the total players and add them to the raffle
        for (uint160 i = startingIndex; i < totalPlayers; i++) {
            // Setup: Convert the index to an address and fund each player
            hoax(address(i), STARTING_PLAYER_BALANCE);
            // Setup: Player enters the raffle
            raffle.enterRaffle{value: entranceFee}();
        }
        // Setup: Move time + block number forward to when the raffle is ready to pick a winner
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // ACT
        // Execute: Prepare to record logs
        vm.recordLogs();
        // Execute: Perform upkeep to emit the request id
        raffle.performUpkeep("");
        // Execute: Get the recorded logs -
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Execute: Get the requestId from the logs
        /**  
         * Note: the 0th log is the VRF contract events and 1st log is the Raffle contract logs 
         * with requestId being in the 1st log (index 0 reserved for VRF events)
        */
        bytes32 requestId = entries[1].topics[1];
        // EXTRA Test to Verify: The raffle state is Calculating
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        // Execute: Fulfill the random words
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // ASSERT
        // Verify: The raffle state is now open - reset and ready for the next round
        raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.OPEN);
        // Verify: The raffle has a new timestamp
        uint256 newTimeStamp = raffle.getLastTimeStamp();
        assert(newTimeStamp > startingTimeStamp);
        // Verify: The player has been paid
        address recentWinner = raffle.getRecentWinner();
        uint256 winnerBalance = recentWinner.balance;
        assert(winnerBalance > STARTING_PLAYER_BALANCE);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                        LINK TOKEN TOP UP TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

     modifier notOnAnvil() {
         if (block.chainid == LOCAL_CHAINID) {
             return;
         }
         _;
     }

     function test_Atleast1LinkTokenRequiredToTopUpSubscription() public {
         // ARRANGE
         uint256 linkTokenAmount = 0.5 ether;

         // ACT + ASSERT
         // Setup: Next transaction will be from the player's address
         vm.prank(PLAYER);
         // Execute + Verify: Expect Specific Revert when player tries to top up the subscription
         vm.expectRevert();
         // Execute: Player tries to top up the subscription
         raffle.topUpSubscriptionWithLink(linkTokenAmount);
     }

     function test_LinkAmountMustBeLessThanBalanceToTopUpSubscription() public {
        // ARRANGE
         //setup: Get the Raffle Contract's balance before the top up
         uint256 raffleBalance = LinkTokenInterface(linkTokenAddress).balanceOf(address(raffle)) ;

         // ACT + ASSERT
         // Setup: Next transaction will be from the player's address
         vm.prank(PLAYER);
         // Execute + Verify: Expect Specific Revert when player tries to top up the subscription
         vm.expectRevert(Raffle.Raffle__LinkAmountMustBe1orMoreAndLessThanRaffleBalance.selector);
         // Execute: Player tries to top up the subscription
         raffle.topUpSubscriptionWithLink(raffleBalance + 1);
     }
     
     function test_AnyoneCanTopUpSubscription() notOnAnvil public {
         // ARRANGE
         // Setup: Link token amount to top up the subscription
         uint256 linkTokenDepositAmount = 3 ether;
         uint256 topUpLinkAmount = 2 ether;
         // Visually check the balances
         uint256 balanceBefore = LinkToken(linkTokenAddress).balanceOf(address(raffle));
        // Visually check the balances
         if(TEST_CONSOLE_LOGS_TF) {   
            console2.log("");
            console2.log("+------------------|||||||||||||||||||||------------------+");
            console2.log("     Raffle Contract Balance B4 B4 LINK: ", balanceBefore);
            console2.log("         Link Topper Balance B4 B4 LINK: ", LinkToken(linkTokenAddress).balanceOf(owner));
            console2.log("+------------------|||||||||||||||||||||------------------+");
            console2.log("ACTION: Topper Transfers to Raffle LINK: ", linkTokenDepositAmount);

         }
         // Setup: Transfer Link tokens to the Raffle contract and the owner
         vm.startBroadcast(owner);
         LinkToken(linkTokenAddress).transfer(address(raffle), linkTokenDepositAmount);  
         vm.stopBroadcast();
        // Setup: Get the Raffle Contract's balance before and after the top up
         balanceBefore = LinkToken(linkTokenAddress).balanceOf(address(raffle));
        // Setup: Get the Raffle Funders's balance before and after the top up
         uint256 balanceTopper = LinkToken(linkTokenAddress).balanceOf(owner);

        // Visually check the balances
         if(TEST_CONSOLE_LOGS_TF) {   
            console2.log("+------------------|||||||||||||||||||||------------------+");
            console2.log("    Raffle Contract Balance Before LINK: ", balanceBefore);
            console2.log("             Topper Balance Before LINK: ", balanceTopper);
            console2.log("+------------------|||||||||||||||||||||------------------+");
         }
         // ACT + ASSERT
         // Execute + Verify: Expect Specific Revert when player tries to top up the subscription
         // Assert: The Raffle Contract's balance has increased by the link token amount
         assert(balanceBefore == linkTokenDepositAmount); 
         // Setup: Subscription should have been setup and funded

        // Execute: Get the subscription balance
        uint96 subscriptionBalance = raffle.getLinkBalanceOfVRFSubscription();
         // Verify: The subscription balance is greater than 0
        if(TEST_CONSOLE_LOGS_TF) {   
            console2.log("");
            console2.log("+[0][0][0][0][0][0][0][0][0][0][0]+");
            console2.log("B4:     Subscription Balance LINK: ", subscriptionBalance);
            console2.log("+[0][0][0][0][0][0][0][0][0][0][0]+");
        }
         // Setup: Next transaction will be from the player's address
         vm.prank(PLAYER);
         // Execute: Owner/linkTopper calls the Raffle Contract to top up the subscription
         raffle.topUpSubscriptionWithLink(topUpLinkAmount);
        //  Setup: Next transaction will be from the owner's address
         vm.prank(owner);
         // Execute: Get the subscription balance
         (subscriptionBalance) = raffle.getLinkBalanceOfVRFSubscription();
            // Verify: The subscription balance is greater than 0
        if(TEST_CONSOLE_LOGS_TF) { 
            console2.log("");
            console2.log("ACTION: Top Up VRF Subscription w/LINK (Anyone)");
            console2.log("");
            console2.log("+[0][0][0][0][0][0][0][0][0][0][0]+");
            console2.log("AFTER:  Subscription Balance LINK: ", subscriptionBalance);
            console2.log("+[0][0][0][0][0][0][0][0][0][0][0]+");
            console2.log("");
            console2.log("");
        }   
         // Execute: Get the owner's balance after the top up to...
         uint256 balanceAfter = LinkToken(linkTokenAddress).balanceOf(address(raffle));
         // Visually check the balances if TEST_CONSOLE_LOGS_TF is true
        if(TEST_CONSOLE_LOGS_TF) { 
            // Verify that the Consumer is the Raffle contract & not the owner
            console2.log("+-----------------|||||||||||||||||||||-------------------+");
            console2.log("+-----------------|||||||||||||||||||||-------------------+");
            console2.log("    Raffle Contract Balance After LINK: ", balanceAfter);
            // Check owner's balance
            balanceTopper = LinkToken(linkTokenAddress).balanceOf(owner);
            console2.log("             Topper Balance After LINK: ", balanceTopper);
            console2.log("+-----------------|||||||||||||||||||||-------------------+");
            console2.log("+-----------------|||||||||||||||||||||-------------------+");
            console2.log("");
        }
         // Verify: The owner's balance has decreased by the link token amount
         assert(balanceAfter == balanceBefore - topUpLinkAmount);
     }

     function test_SubscriptionIdIsfunded() public view {
         // ARRANGE
            // Setup: Subscription should have been setup and funded
            uint96 subscriptionBalance;
         // ACT + ASSERT
            // Execute: Get the subscription balance
            (subscriptionBalance) = raffle.getLinkBalanceOfVRFSubscription();
            // Display: The subscription balance if Test Console Logs is true
            if(TEST_CONSOLE_LOGS_TF) { 
            // Verify: The subscription balance is greater than 0
                console2.log("");
                console2.log("+[0][0][0][0][0][0][0]+");
                console2.log(" Subscription Balance: ", subscriptionBalance);
                console2.log("+[0][0][0][0][0][0][0]+");
                console2.log("");
            }
            // Verify: The subscription balance is greater than 0
            assert(subscriptionBalance > 0);
     }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            GETTER FUNCTION TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    
     function test_GetEntranceFee() public view {
         // ASSERT
         // Verify: The entrance fee is 1 ether
         assert(raffle.getEntranceFee() == entranceFee);
     }

        function test_GetInterval() public view {
            // ASSERT
            // Verify: The interval is 30 seconds
            assert(raffle.getInterval() == interval);
        }

        function test_GetSubscriptionId() public view {
            // ASSERT
            // Verify: The subscription id is 0
            if (TEST_CONSOLE_LOGS_TF) {
                console2.log("");
                console2.log("Subscription ID function: ", raffle.getSubscriptionId());
                console2.log("Subscription ID variable: ", subscriptionId);
                console2.log("");
            }
            // Verify: The subscription id is the same as the one in the HelperConfig
            assert(raffle.getSubscriptionId() == subscriptionId);
        }     

        function test_GetPlayerCount() public playerEnteredRaffle {
            // ASSERT
            // Verify: The player count is 1
            assert(raffle.getPlayerCount() == 1);

        }

        function test_GetVRFSubscriptionBalance() public view {
            // ARRANGE
            // Setup: Subscription should have been setup and funded
            // setup: Get the Owner of the subscription for the Console log
            address subOwner;
            ( , , , subOwner, ) = IVRFCoordinatorV2Plus(vrfCoordinator).getSubscription(subscriptionId);
            // ACT
            // Execute: Get the subscription balance
            uint96 subscriptionBalance = raffle.getLinkBalanceOfVRFSubscription();
            if (TEST_CONSOLE_LOGS_TF) {
                console2.log("");
                console2.log("VRF Subscription Balance LINK: ", subscriptionBalance);
                console2.log("       VRF Subscription Owner: ", subOwner);
                console2.log("");
            }   
            // ASSERT
            // Verify: The subscription balance is greater than 0
            assert(subscriptionBalance > 0);
            // assert(owner == raffle.getOwner());
        }

        function test_GetLinkBalanceOfRaffleContract() public {
            // Setup: Transfer Link tokens to the Raffle contract and the owner
            uint256 linkTokenDepositAmount = 3 ether;
            // Setup: Get the Raffle Contract's balance before and after the top up
            uint256 balanceBefore = raffle.getLinkBalanceOfRaffle();

            vm.startBroadcast(owner);
            LinkToken(linkTokenAddress).transfer(address(raffle), linkTokenDepositAmount);  
            vm.stopBroadcast();

            // ACT + ASSERT
            // Execute: Get the raffle balance
            uint256 balanceAfter = raffle.getLinkBalanceOfRaffle();
            // Verify: The raffle balance is greater than 0
            assert(balanceAfter == balanceBefore + linkTokenDepositAmount);

        }

        function test_GetLastTimeStamp() public view {
            // ASSERT
            // Verify: The last timestamp is greater than 0
            assert(raffle.getLastTimeStamp() > 0);
        }

        function test_GetTxFeeBalance() public view {
            // ASSERT
            // Verify: The transaction fee balance is 0
            assert(raffle.getTxFeeBalance() == INITIAL_RAFFLE_CONTRACT_ETH_DEPOSIT);
        } 
}