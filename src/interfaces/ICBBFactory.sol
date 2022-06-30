// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./IButtonWoodBondController.sol";
import "./ISlipFactory.sol";

/**
 * @notice Interface for Convertible Bond Box factory contracts
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

    function createConvertibleBondBox(
        IButtonWoodBondController bond,
        ISlipFactory slipFactory,
        uint256 penalty,
        address collateralToken,
        address stableToken,
        uint256 trancheIndex,
        address owner
    ) external returns (address);
}
