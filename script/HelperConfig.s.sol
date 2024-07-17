// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title Helper Configuration Contract for Deploying Raffle Contract
 * @author c0 | X: @c0mmanderZero
 * @notice Helper contract for configuring Raffle contract
 * @dev This contract provides configuration parameters that will enable
 * @dev the Raffle contract to be deployed on any EVM-compatible chain
 */

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    // VRF Mock Values - Don't really matter for the Mock
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 6e9;
    // Link / ETH price
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 2e14;

    uint256 public constant AVAX_FUJI_CHAINID = 43113;
    uint256 public constant LOCAL_CHAINID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        bool nativePayment; //extra variable - will probably require refactoring to implemnt if nativePayment is true
        uint32 callbackGasLimit;
        address linkTokenAddress; // thinking ahead
        bytes32 keyHash4GasLane;
        uint256 subscriptionId;
        address vrfCoordinator;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[AVAX_FUJI_CHAINID] = getFujiAvaxNetworkConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAINID) {
            // get or set local network config
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // get or set Anvil Eth network config
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        //Deploy Mocks, setup local network config, etc...
        vm.startBroadcast();
        //Deploy Mocks
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
            LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        // Set local network config
        localNetworkConfig = NetworkConfig({
            entranceFee: 100, // 10^18 wei (units only)
            interval: 30, // 30 seconds
            nativePayment: false,
            callbackGasLimit: 500000,
            // Might need to change this for the mock Link token
            linkTokenAddress: address(linkToken),
            // Doesn't matter for the mock - using the same keyHash as Fuji
            keyHash4GasLane: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887,
            subscriptionId: 0,
            vrfCoordinator: address(vrfCoordinatorMock)
        });

        return localNetworkConfig;
    }

    function getFujiAvaxNetworkConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 100, // 1 AVAX or 10^18 wei (units only)
            interval: 30, // 30 seconds
            nativePayment: false,
            callbackGasLimit: 500000,
            linkTokenAddress: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            keyHash4GasLane: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887,
            subscriptionId: 0,
            vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE
        });
    }
}
