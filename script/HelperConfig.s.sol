// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Helper Configuration Contract for Deploying Raffle Contract
 * @author c0 | X: @c0mmanderZero
 * @notice Helper contract for configuring Raffle contract
 * @dev This contract provides configuration parameters that will enable
 * @dev the Raffle contract to be deployed on any EVM-compatible chain
 */

import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    // Owner of the contract when deploying to forks or testnets - TBD
    address public OWNER_DEPLOYER = tx.origin;
    address public OWNER_DEPLOYER_2 = 0x7145F2DD87cf598932442deBE49c41278d88C970;

    // Foundry Anvil Test Accounts - RED and BLUE Teams
    address public FOUNDRY_RED_TEAM_TESTER = tx.origin;
    address public FOUNDRY_BLUE_TEAM_TESTER = (tx.origin == 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) ? 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 : 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // VRF Mock Values - Don't really matter for the Mock
    uint96 public MOCK_BASE_FEE =  0.00034 ether;          
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;             
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15; 

    // Chain Ids
    uint256 public constant LOCAL_CHAINID = 31337;
    uint256 public constant AVAX_FUJI_CHAINID = 43113;
    uint256 public constant ARBITRUM_MAINNET_CHAINID = 421611;
    uint256 public constant ARBITRUM_SEPOLIA_CHAINID = 421614;
    uint256 public constant SEPOLIA_ETH_CHAINID = 11155111;

    // Enable / Disable console logs for testing
    bool public constant ENABLE_CONSOLE_LOGS_TF = false;
    bool public constant SPECIAL_LOGS_TF = true;   
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
        address owner;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[AVAX_FUJI_CHAINID] = getFujiAvaxNetworkConfig();
        networkConfigs[SEPOLIA_ETH_CHAINID] = getSepoliaEthConfig();
        networkConfigs[ARBITRUM_MAINNET_CHAINID] = getArbitrumMainnetConfig();
        networkConfigs[ARBITRUM_SEPOLIA_CHAINID] = getArbitrumSepoliaConfig();
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

        //34 Link
        uint256 FUND_AMOUNT = 34 ether; 
        // subId = subscriptionId = 0, unless the createSubscription function is called in broadcast above
        uint256 subId = 0; 
         
        //Deploy Mocks, setup local network config, etc...
        vm.startBroadcast(FOUNDRY_RED_TEAM_TESTER);
            //Deploy Mocks
            VRFCoordinatorV2_5Mock vrfCoordinatorMock =
                new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
                LinkToken linkToken = new LinkToken();
                linkToken.transfer(FOUNDRY_BLUE_TEAM_TESTER, FUND_AMOUNT); //Extra - transfer 34 Link to the owner
                // subId = vrfCoordinatorMock.createSubscription();
                // VRFCoordinatorV2_5Mock(vrfCoordinatorMock).fundSubscription(subId, FUND_AMOUNT); //Extra
        vm.stopBroadcast();

        if (ENABLE_CONSOLE_LOGS_TF) {
            console2.log("");
            console2.log("#######################################");
            console2.log("You have deployed a MOCK VRF contract!");  
            console2.log("#######################################");
            console2.log("Make sure this was intentional!");        
            // console2.log("");
       
            uint256 balanceRed = linkToken.balanceOf(FOUNDRY_RED_TEAM_TESTER);
            uint256 balanceBlue = linkToken.balanceOf(FOUNDRY_BLUE_TEAM_TESTER);
            console2.log("");
            console2.log("--------------------------------------------");
            console2.log("Foundry RED Team Account (tx.origin): ", FOUNDRY_RED_TEAM_TESTER);
            console2.log("Mock Link Balance of RED Team: ", balanceRed);
            console2.log("--------------------------------------------");
            console2.log("Foundry BLUE Team Account (9): ", FOUNDRY_BLUE_TEAM_TESTER);
            console2.log("Mock Link Balance of BLUE Team: ", balanceBlue);
            console2.log("--------------------------------------------");
            // console2.log("");
        }

        // Set local network config
        localNetworkConfig = NetworkConfig({
            entranceFee: 1 ether, // 10^18 wei (units only)
            interval: 30, // 30 seconds
            nativePayment: false,
            callbackGasLimit: 500000,
            // Might need to change this for the mock Link token
            linkTokenAddress: address(linkToken),
            // Doesn't matter for the mock - using the same keyHash as Fuji
            keyHash4GasLane: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887,
            subscriptionId: subId,  // subscriptionId is 0 unless the createSubscription function is called in broadcast above
            vrfCoordinator: address(vrfCoordinatorMock),
            owner: FOUNDRY_RED_TEAM_TESTER
        });

        return localNetworkConfig;
    }

    function getFujiAvaxNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 1 ether, // 1 AVAX or 10^18 wei (units only)
            interval: 30, // 30 seconds
            nativePayment: false,
            callbackGasLimit: 500000,
            linkTokenAddress: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            keyHash4GasLane: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887,
            subscriptionId: 0,
            vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE,
            owner: OWNER_DEPLOYER // TBD
        });
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            entranceFee: 1 ether,
            interval: 30, // 30 seconds
            nativePayment: false,
            callbackGasLimit: 500000, // 500,000 gas
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            keyHash4GasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            subscriptionId: 0, // If left as 0, our scripts will create one!
            owner: OWNER_DEPLOYER
        });
    }

    function getArbitrumMainnetConfig() public view returns (NetworkConfig memory arbitrumSepoliaConfig) {
        arbitrumSepoliaConfig = NetworkConfig({
            entranceFee: 1 ether,
            interval: 30, // 30 seconds
            nativePayment: false,
            callbackGasLimit: 500000, // 500,000 gas
            linkTokenAddress: 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            keyHash4GasLane: 0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409, // 30 gwei Key Hash - Medium Speed/Security
            vrfCoordinator: 0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e,
            subscriptionId: 0, // If left as 0, our scripts will create one!
            owner: OWNER_DEPLOYER
        });
    }

    function getArbitrumSepoliaConfig() public view returns (NetworkConfig memory arbitrumSepoliaConfig) {
        arbitrumSepoliaConfig = NetworkConfig({
            entranceFee: 1 ether,
            interval: 30, // 30 seconds
            nativePayment: false,
            callbackGasLimit: 500000, // 500,000 gas
            linkTokenAddress: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            keyHash4GasLane: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be, // 50 gwei Key Hash - Only option for Arbitrum Sepolia
            vrfCoordinator: 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61,
            subscriptionId: 0, // If left as 0, our scripts will create one!
            owner: OWNER_DEPLOYER
        });
    }

}