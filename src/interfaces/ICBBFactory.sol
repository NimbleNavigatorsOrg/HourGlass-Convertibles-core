// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

/**
 * @notice Interface for Auction factory contracts
 */
interface ICBBFactory {
    event ConvertibleBondBoxCreated(
        address collateralToken, 
        address stableToken, 
        uint256 trancheIndex,
        uint256 penalty, 
        address creator
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}