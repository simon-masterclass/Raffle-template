// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle gas cost analysis contract
 * @author c0 | X: @c0mmanderZero
 * @notice This contract is just for testing gas costs of different revert types
 * @dev test it out in Remix or Foundry gas snapshot tool, etc.
 */
contract RaffleGas {
    uint256 private immutable i_entranceFee;

    /* Error Codes */
    error Raffle__InsufficientFunds();

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    /* Revert Gas Function Analysis */
    function revertWithError() public view {
        if (i_entranceFee < 69) {
            revert Raffle__InsufficientFunds();
        }
    }

    function revertWithRequire() public view {
        require((i_entranceFee >= 69), "Raffle: Not enough ETH sent to enter.");
    }

    /* require with custom error not available until solidity version 0.8.26 is released */
    // function revertWithRequireAndCustomError() public view {
    //     require((i_entranceFee >= 69), Raffle__InsufficientFunds());
    // }

    function revertWithAssert() public view {
        assert((i_entranceFee >= 69));
    }
}
