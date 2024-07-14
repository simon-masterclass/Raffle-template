// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title DeployRaffle
 * @author c0 | X: @c0mmanderZero
 * @notice test script for deploying Raffle contract
 * @dev This deploy script allows deployment to any EVM-compatible chain but is
 * @dev specifically designed for Avalanche Fuji Testnet
 */

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";

contract DeplyRaffle is Script {

    function run() public {


    }

    function deployContract() public returns (Raffle, HelperConfig) {

    }   

}
