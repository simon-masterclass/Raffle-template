// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Interactions contract for interacting with Raffle contract VRFCoordinator
 * @author c0 | X: @c0mmanderZero
 * @notice Interacts with Raffle contract VRFCoordinator
 * @dev The Chainlink VRFCoordinator contract requires Link tokens on Testnets and Mainets
 * @dev The VRFCoordinator contract is used to generate random numbers for the Raffle contract.
 * @dev This contract is adaptable to any EVM-compatible chain and deploys a Mock VRFCoordinator
 * @dev for local testing.
 */

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    function run() public {
        CreateSubscriptionUsingConfig();
    }

    function CreateSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address owner = helperConfig.getConfig().owner;

        return createSubscription(vrfCoordinator, owner);
    }

    function createSubscription(address vrfCoordinator, address owner) public returns (uint256, address) {
        // Call vrfCoordinator on the specified Network to create subscription
        vm.startBroadcast(owner);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        if (ENABLE_CONSOLE_LOGS_TF) {
            console2.log("");
            console2.log("+-------------------------------------+");
            console2.log("Created VRF subscription with subId:", subId);
            console2.log("+-------------------------------------+");
            console2.log("Created VRF subscription on Chain Id: ", block.chainid);
            console2.log("Please update the subscription Id in your helperConfig.s.sol");
            console2.log("");
        }

        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 Link

    function run() public {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkTokenAddress = helperConfig.getConfig().linkTokenAddress;
        address owner = helperConfig.getConfig().owner;

        fundSubscription(vrfCoordinator, subscriptionId, linkTokenAddress, owner);
    }

    function fundSubscription(address vrfCoordinator_, uint256 subId_, address linkToken_, address owner) public {
        // Call vrfCoordinator on the specified Network to fund subscription
        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast(owner);
            VRFCoordinatorV2_5Mock(vrfCoordinator_).fundSubscription(subId_, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            // For all other chains, fund the subscription with Link tokens from the owner address
            if (ENABLE_CONSOLE_LOGS_TF) {
                console2.log("");
                console2.log("F: CHECK LINK TOKEN BALANCES:");
                console2.log("F: Address of owner: ", owner);
                console2.log(
                    "F: Link Token Balance of Owner Before transferAndCall: ", LinkToken(linkToken_).balanceOf(owner)
                );
            }

            vm.startBroadcast(owner);
            LinkToken(linkToken_).transferAndCall(vrfCoordinator_, FUND_AMOUNT, abi.encode(subId_));
            vm.stopBroadcast();

            if (ENABLE_CONSOLE_LOGS_TF)
            console2.log("F: Link Token Balance of Owner (After): ", LinkToken(linkToken_).balanceOf(owner));
        }

        if (ENABLE_CONSOLE_LOGS_TF) {
            // Log the funded subscription
            console2.log("");
            console2.log("+-------------------------------------+");
            console2.log("Funded Chainlink VRF subscription Id: :", subId_);
            console2.log("+-------------------------------------+");
            console2.log("Funding VRF subscription on Chain Id: ", block.chainid);
            console2.log("Funded Using Chainlink VRF Coordinator: ", vrfCoordinator_);
            console2.log("Funded Your VRF subscription with this much Link:", FUND_AMOUNT);
            console2.log("");
        }
    }
}

contract AddConsumer is Script, CodeConstants {
    using DevOpsTools for *;

    function run() public {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentDeployed);
    }

    function addConsumerUsingConfig(address mostRecentDeployment_) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address owner = helperConfig.getConfig().owner;

        addConsumer(mostRecentDeployment_, vrfCoordinator, subscriptionId, owner);
    }

    function addConsumer(address contractToAddToVRF, address vrfCoordinator, uint256 subId, address owner) public {

        if (ENABLE_CONSOLE_LOGS_TF) {
            console2.log("");
            console2.log("+-------------------------------------+");
            console2.log("Adding Consumer to VRF subscription Id: :", subId);
            console2.log("+-------------------------------------+");
            console2.log("Adding Consumer to VRF subscription on Chain Id: ", block.chainid);
            console2.log("Adding Consumer to Chainlink VRF Coordinator: ", vrfCoordinator);
            console2.log("Adding Consumer to Raffle contract: ", contractToAddToVRF);
            console2.log("");
            // Call vrfCoordinator on the specified Network to add consumer
        }    

        vm.startBroadcast(owner);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVRF);
        vm.stopBroadcast();
    }
}
