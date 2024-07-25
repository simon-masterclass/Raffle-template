// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Deploy Raffle Contract Script
 * @author c0 | X: @c0mmanderZero
 * @notice test script for deploying Raffle contract
 * @dev This deploy script allows deployment to any EVM-compatible chain but is
 * @dev specifically designed for Avalanche Fuji Testnet
 */

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script, CodeConstants {
    // Owner of the contract - TBD
    address public owner;

    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        if (ENABLE_CONSOLE_LOGS_TF || SPECIAL_LOGS_TF) {
            // Display sender account
            console2.log("");
            console2.log("#######################################");
            console2.log("Deploying Raffle contract using Account:", tx.origin);
            console2.log("#######################################");
            console2.log("");
        }

        HelperConfig helperConfig = new HelperConfig();
        // If local chain => Get or set the local network config
        // If Fuji Avax chain => Get the Fuji Avax network config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            // Create a new subscription
            CreateSubscription createSubId = new CreateSubscription();
            (config.subscriptionId, /* vrfCordinator */ ) =
                createSubId.createSubscription(config.vrfCoordinator, config.owner);

            // Fund subscription with Link tokens
            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(
                config.vrfCoordinator, config.subscriptionId, config.linkTokenAddress, config.owner
            );
        }

        // Deploy Raffle contract
        vm.startBroadcast(config.owner);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.nativePayment,
            config.callbackGasLimit,
            config.owner, // Owner of the contract - TBD - set OWNER_DEPLOYER in HelperConfig
            config.linkTokenAddress,
            config.keyHash4GasLane,
            config.subscriptionId,
            config.vrfCoordinator
        );
        vm.stopBroadcast();

        if (ENABLE_CONSOLE_LOGS_TF || SPECIAL_LOGS_TF) {
            // console2.log("");
            console2.log("########################");
            console2.log("Raffle contract address: ", address(raffle));
            console2.log("########################");
            // console2.log("");
        }

        // Add Raffle contract as a consumer
        AddConsumer addConsumer = new AddConsumer();
        // addConsumer.run();
        // addConsumer.addConsumerUsingConfig(address(raffle));
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.owner);

        return (raffle, helperConfig);
    }
}
