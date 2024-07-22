// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

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

contract CreateSubscription is Script {
    function run() public {
        CreateSubscriptionUsingConfig();
    }

    function CreateSubscriptionUsingConfig() public returns (uint, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address owner = helperConfig.getConfig().owner;

        return createSubscription(vrfCoordinator, owner);
    }

    function createSubscription(address vrfCoordinator, address owner) public returns (uint256, address) {
        console2.log("Creating VRF subscription on Chain Id: ", block.chainid);
        // Call vrfCoordinator on the specified Network to create subscription
        vm.startBroadcast(owner);
            uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console2.log("Your VRF subscription Id is:", subId);
        console2.log("Please update the subscription Id in your helperConfig.s.sol");

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
        console2.log("Funding VRF subscription on Chain Id: ", block.chainid);
        console2.log("Funded Chainlink VRF subscription Id: ", subId_);
        console2.log("Funded Using Chainlink VRF Coordinator: ", vrfCoordinator_);
        // Call vrfCoordinator on the specified Network to fund subscription
        if (block.chainid == LOCAL_CHAINID) {
            console2.log("F:Link Token Balance of Sender (b4): ",LinkToken(linkToken_).balanceOf(msg.sender));
            console2.log("F:Message Sender: ", msg.sender);
            console2.log("F:Link Token Balance of this Contract: ", LinkToken(linkToken_).balanceOf(address(this)));
            console2.log("F:Address this Contract: ",address(this));
            // Mint Link tokens to the sender
            // console2.log("F:Link Token Balance of Sender (after): ",LinkToken(linkToken_).balanceOf(msg.sender));

            vm.startBroadcast(owner);
                VRFCoordinatorV2_5Mock(vrfCoordinator_).fundSubscription(subId_, FUND_AMOUNT);  
            vm.stopBroadcast();
        } else {
            console2.log("F:Link Token Balance of Sender: ",LinkToken(linkToken_).balanceOf(msg.sender));
            console2.log("F:Message Sender: ", msg.sender);
            console2.log("F:Link Token Balance of this Contract: ", LinkToken(linkToken_).balanceOf(address(this)));
            console2.log("F:Address this Contract: ",address(this));

            vm.startBroadcast(owner);
                LinkToken(linkToken_).transferAndCall(vrfCoordinator_, FUND_AMOUNT, abi.encode(subId_));
            vm.stopBroadcast();
        }
        console2.log("Funded Your VRF subscription with this much Link:", FUND_AMOUNT);
    }
}

contract AddConsumer is Script {
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
        console2.log("Adding Consumer to VRF subscription on Chain Id: ", block.chainid);
        console2.log("Adding Consumer to Chainlink VRF Coordinator: ", vrfCoordinator);
        console2.log("Adding Consumer to Chainlink VRF subscription Id: ", subId);
        console2.log("Adding Consumer to Raffle contract: ", contractToAddToVRF);
        // Call vrfCoordinator on the specified Network to add consumer
        vm.startBroadcast(owner);
            VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVRF);
        vm.stopBroadcast(); 
    }
}