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
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
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
        // Verify: The player is recorded in the raffle contract
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

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

    function test_DoNotAllowPlayerToEnterWhenRaffleIsCalculating() public {
        // ARRANGE
        // Setup: Next transaction will be from the player's address
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Setup: Move time + block number forward to when the raffle is calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 2);
        // ACT + ASSERT
        // Next transaction will be from the player's address
        vm.prank(PLAYER);
        // Execute + Verify: Expect Revert when player tries to enter the raffle
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }
}
