// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DeployRaffle
 * @author c0 | X: @c0mmanderZero
 * @notice test script for deploying Raffle contract
 * @dev This deploy script allows deployment to any EVM-compatible chain but is
 * @dev specifically designed for Avalanche Fuji Testnet
 */
import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployRaffle is Script {
    // Owner of the contract - TBD
    address public owner;

    function run() public {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // If local chain => Get or set the local network config
        // If Fuji Avax chain => Get the Fuji Avax network config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        // Deploy Raffle contract
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.nativePayment,
            config.callbackGasLimit,
            owner, // Owner of the contract - TBD
            config.linkTokenAddress,
            config.keyHash4GasLane,
            config.subscriptionId,
            config.vrfCoordinator
        );
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }
}
