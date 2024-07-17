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

contract CreateSubscription is Script {
    function run() public {
        CreateSubscriptionUsingConfig();
    }

    function CreateSubscriptionUsingConfig() public returns (uint, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console2.log("Creating VRF subscription on Chain Id: ", block.chainid);
        // Call vrfCoordinator on the specified Network to create subscription
        vm.startBroadcast();
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

        fundSubscription(vrfCoordinator, subscriptionId, linkTokenAddress);
    }

    function fundSubscription(address vrfCoordinator_, uint256 subId_, address linkToken_) public {
        console2.log("Funding VRF subscription on Chain Id: ", block.chainid);
        console2.log("Funded Chainlink VRF subscription Id: ", subId_);
        console2.log("Funded Using Chainlink VRF Coordinator: ", vrfCoordinator_);
        // Call vrfCoordinator on the specified Network to fund subscription
        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast();
                VRFCoordinatorV2_5Mock(vrfCoordinator_).fundSubscription(subId_, FUND_AMOUNT);  
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
                LinkToken(linkToken_).transferAndCall(vrfCoordinator_, FUND_AMOUNT, abi.encode(subId_));
            vm.stopBroadcast();
        }
        console2.log("Funded Your VRF subscription with this much Link:", FUND_AMOUNT);
    }

}