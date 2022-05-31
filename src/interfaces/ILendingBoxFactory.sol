// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
 * @notice Interface for Auction factory contracts
 */
interface ILendingBoxFactory {
    event LendingBoxCreated(
        address collateralToken, 
        address stableToken, 
        uint256 trancheIndex,
        uint256 penalty, 
        address creator
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}