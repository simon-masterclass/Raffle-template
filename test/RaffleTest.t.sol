// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title Raffle Contract Tests
 * @author c0 | X: @c0mmanderZero
 * @notice Testing Raffle contract
 * @dev This contract is configure to test on a local chain and on the Avalanche Fuji Testnet
 */

import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";

contract RaffleTest is Test {
    // Contracts - Raffle and HelperConfig
    Raffle public raffle;
    HelperConfig public helperConfig;

    // Test Player
    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCE = 10 ether;

    // Helper Config values
    uint256 entranceFee;
    uint256 interval;
    bool nativePayment; //extra variable - will probably require refactoring to implemnt if nativePayment is true
    uint32 callbackGasLimit;
    address linkTokenAddress; // thinking ahead
    bytes32 keyHash4GasLane;
    uint256 subscriptionId;
    address vrfCoordinator;

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                        TEST INITIALIZATION SETUP
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    
    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        // Helper Config values
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        nativePayment = config.nativePayment;
        callbackGasLimit = config.callbackGasLimit;
        linkTokenAddress = config.linkTokenAddress;
        keyHash4GasLane = config.keyHash4GasLane;
        subscriptionId = config.subscriptionId;
        vrfCoordinator = config.vrfCoordinator; 

        // Fund player
        vm.deal(PLAYER, entranceFee*2);   
    }

    function test_RaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*
                            ENTER RAFFLE TESTS
     *|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    
    function test_RaffleRevertsWhenPlayerDoesNotSendEnoughToEnter() public {
    // ARRANGE
        // Setup: Player will send 1 wei less than the entrance fee
        uint256 insufficientAmount = entranceFee - 1;
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
    // ACT + ASSERT
        // Execute: Expect Revert when player tries to enter the raffle with insufficient funds
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: insufficientAmount}();
    }

    function test_RaffleRecordsPlayersWhenTheyEnter() public {
        // ARRANGE
           // Setup: Next transaction will be from the player's address
           vm.prank(PLAYER);           
        // ACT
           // Execute: Enter the raffle
           raffle.enterRaffle{value: entranceFee}();           
        // ASSERT
           // Verify: The player is recorded in the raffle
           address playerRecorded = raffle.getPlayer(0);
           assert(playerRecorded == PLAYER);
    }

}
