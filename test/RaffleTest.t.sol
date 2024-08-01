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
import {LinkToken} from "test/mocks/LinkToken.sol";

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
        // Setup: Deploy Raffle contract
        DeployRaffle deployRaffle = new DeployRaffle();
        // Setup: Get the Raffle contract and HelperConfig contract
        (raffle, helperConfig) = deployRaffle.deployContract();

        // Setup: Get the HelperConfig values for VRF setup and testing the Raffle contract
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        nativePayment = config.nativePayment;
        callbackGasLimit = config.callbackGasLimit;
        linkTokenAddress = config.linkTokenAddress;
        keyHash4GasLane = config.keyHash4GasLane;
        subscriptionId = config.subscriptionId;
        vrfCoordinator = config.vrfCoordinator;
        owner = config.owner;

        // Setup: Fund the Raffle Contract with funds to pay the winner - 0.69 ether
        // Note that sending more than 1 ether will enter the sender into the lottery instead of providing funds for transactions
        // vm.deal(address(raffle), 0.69 ether);
        // vm.deal(owner, STARTING_PLAYER_BALANCE);

        (bool success,) = payable(raffle).call{value: 0.69 ether}("");
        require(success, "Failed to send funds to Raffle contract");

        // Setup: Fund player with STARTING_PLAYER_BALANCE = 10 ether; (for testing - subject to change)
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    /**
     * TEST: Ensure the Raffle has and initial balance *
     */
    function test_InitialRaffleBalance() public view {
        // ASSERT
        // Verify: The Raffle contract has a balance of 0.69 ether
        assert(address(raffle).balance == 0.69 ether);
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
                            LINK TOKEN FUNCTIONS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

     modifier notOnAnvil() {
         if (block.chainid == LOCAL_CHAINID) {
             return;
         }
         _;
     }

     function test_OnlyLinkTokenTopperCanTopUpSubscription() public {
         // ARRANGE
         // Setup: Next transaction will be from the player's address
         vm.prank(PLAYER);
         uint256 linkTokenAmount = 1 ether;

         // ACT + ASSERT
         // Execute + Verify: Expect Specific Revert when player tries to top up the subscription
         vm.expectRevert();
         // Execute: Player tries to top up the subscription
         raffle.topUpSubscription(linkTokenAmount);
     }

     function test_theLinkTokenTopperCanTopUpSubscription() public notOnAnvil {
         // ARRANGE
         // Setup: Link token amount to top up the subscription
         uint256 linkTokenAmount = 1 ether;
         // Setup: Transfer Link tokens to the Raffle contract and the owner
         vm.startBroadcast();
         LinkToken(linkTokenAddress).transfer(address(raffle), linkTokenAmount); 
        //  LinkToken(linkTokenAddress).transfer(owner, linkTokenAmount); 
         vm.stopBroadcast();
        // Setup: Get the owner's balance before and after the top up
         uint256 balanceBefore = LinkToken(linkTokenAddress).balanceOf(address(raffle));
         uint256 balanceTopper = LinkToken(linkTokenAddress).balanceOf(owner);

         // ACT + ASSERT
         // Execute + Verify: Expect Specific Revert when player tries to top up the subscription
         // Assert: The Raffle Contract's balance has increased by the link token amount
         assert(balanceBefore == linkTokenAmount); 
        // Visually check the balances
         console2.log("Raffle Contract Balance Before: ", balanceBefore);
         console2.log("Link Topper Balance Before: ", balanceTopper);

         // Setup: Next transaction will be from the owner's address
         vm.prank(owner);
         // Execute: Owner/linkTopper calls the Raffle Contract to top up the subscription
         raffle.topUpSubscription(linkTokenAmount);
        //  Setup: Next transaction will be from the owner's address
         vm.prank(owner);
         // Execute: Get the owner's balance after the top up
         uint256 balanceAfter = LinkToken(linkTokenAddress).balanceOf(address(raffle));
         console2.log("Raffle Contract Balance After: ", balanceAfter);
         // Verify that the Consumer is the Raffle contract & not the owner
         balanceTopper = LinkToken(linkTokenAddress).balanceOf(owner);
         console2.log("Link Topper Balance After: ", balanceTopper);
         // Verify: The owner's balance has decreased by the link token amount
         assert(balanceAfter == balanceBefore - linkTokenAmount);
     }
    
}
