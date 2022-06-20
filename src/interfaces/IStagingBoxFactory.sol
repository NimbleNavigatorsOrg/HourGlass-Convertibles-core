// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;
import "./IConvertibleBondBox.sol";
import "./ICBBFactory.sol";


/**
 * @notice Interface for Convertible Bond Box factory contracts
 */

interface IStagingBoxFactory {
    event StagingBoxCreated(
        IConvertibleBondBox convertibleBondBox,
        ICBBSlipFactory slipFactory,
        uint256 initialPrice,
        address owner,
        address msgSender
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}
