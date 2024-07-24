// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle Contract Tests
 * @author c0 | X: @c0mmanderZero
 * @notice This contract tests the Raffle contract and its functions, including interactions with Chainlink VRF
 * @dev This contract is configure to test on a local chain, Arbitrum and on the Avalanche Fuji Testnet
 */

import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Script.sol";
// temporary import for testing
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    // Contracts - Raffle and HelperConfig
    Raffle public raffle;
    HelperConfig public helperConfig;
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

    /* Events */
    event RaffleEntered(address indexed player);
    event RaffleWinnerPicked(address indexed winner, uint256 winnings);

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

        // Setup: Fund player with STARTING_PLAYER_BALANCE = 10 ether; (for testing - subject to change)
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    /** TEST: Raffle state enum should Initialize In Open State */
    function test_RaffleInitializesInOpenState() public view {
        // ASSERT
        // Verify: The raffle is in the open state
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            ENTER RAFFLE TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/

    /** TEST: Raffle contract should Revert When a Player Does Not Send Enough To Enter **/
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

    /** TEST: Raffle contract should Record Players When Then Enter**/
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

    /** TEST: Raffle contract should Emit Event When Player Enters **/
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

    /** TEST: Contract should Not Allow Players To Enter Raffle When it Is in Calculating state **/
    function test_DoNotAllowPlayerToEnterWhenRaffleIsCalculating() public {
        // ARRANGE
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Setup: Warp time + roll block number forward to when the raffle is ready to pick a winner
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

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

    /** TEST: Upkeep Needed should return true When it's Time to Pick a Winner**/
    function test_UpkeepNeededWhenTimeToPickWinner() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
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
    
    /** TEST: Check Upkeep should Return False If It Has No Balance **/
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

    /** TEST: Check Upkeep should Return False If Raffle Isn't Open **/
    function test_CheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        // Setup: Player enters the raffle
        raffle.enterRaffle{value: entranceFee}();
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        // ACT
        // Execute: Trigger the Raffle to Use VRF to pick a winner, transfer funds and resets the raffle
        raffle.performUpkeep("");
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // ASSERT
        // Verify: Expect upkeep to not be needed
        assert(upKeepNeeded == false);
    }

    /** TEST: Check Upkeep should Return False When Raffle Isn't Ready **/
    function test_CheckUpkeepReturnsFalseWhenRaffleIsNotReady() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        // Setup: Player enters the raffle
        raffle.enterRaffle{value: entranceFee}();

        // ACT
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // ASSERT
        // Verify: Expect upkeep to not be needed
        assert(upKeepNeeded == false);
    }

    /** TEST: Check Upkeep should Return False If Enough Time Has Passed With No Raffle Entries **/
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
    
    /** TEST: Perform Upkeep Should Revert When Raffle Is Not Ready **/
    function test_PerformUpkeepRevertsWhenRaffleIsNotReady() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);

        // ACT + ASSERT
        // Execute + Verify: Expect Specific Revert when trying to perform upkeep when raffle is not ready
        vm.expectRevert(); // Raffle.Raffle__UpkeepNotNeeded.selector
        raffle.performUpkeep("");
    }

    /** TEST: Perform Upkeep Should Revert With Specific Error When Upkeep Is Not Needed **/
    function test_PerformUpkeepRevertsWithSpecificErrorIfUpkeepNotNeeded() public {
        // ARRANGE
        // Setup: Set the current balance and number of players in the raffle
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        // Setup: Get the current state of the raffle
        Raffle.RaffleState raffleState = raffle.getRaffleState();


        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        // Setup: Player enters the raffle
        raffle.enterRaffle{value: entranceFee}();
        
        // Setup: Update the current balance and number of players in the raffle
        currentBalance = currentBalance + entranceFee ;
        numPlayers = numPlayers + 1;



        // ACT + ASSERT
        // Execute + Verify: Expect Specific Revert when trying to perform upkeep when upkeep is not needed
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
            );
        // Execute: Perform Upkeep and expect it to revert    
        raffle.performUpkeep("");
    }

    function test_PerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        // Setup: Player enters the raffle
        raffle.enterRaffle{value: entranceFee}();
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // ACT + ASSERT 
        // Execute: Check if upkeep is needed
        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        // Verify: Expect upkeep to be needed
        assert(upKeepNeeded == true);

        // Execute: Perform upkeep to see if it reverts
        raffle.performUpkeep("");
    }

    
}
