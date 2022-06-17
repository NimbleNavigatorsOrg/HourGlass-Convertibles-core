// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

/**
 * @notice Interface for Convertible Bond Box factory contracts
 */

interface IStagingBoxFactory {
    event ConvertibleBondBoxCreated(
        address convertibleBondBox,
        uint256 initialPrice,
        address creator
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}
