// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;
import "./IConvertibleBondBox.sol";
import "./ISlipFactory.sol";


/**
 * @notice Interface for Convertible Bond Box factory contracts
 */

interface IStagingBoxFactory {
    // TODO: test this event
    event StagingBoxCreated(
        IConvertibleBondBox convertibleBondBox,
        ISlipFactory slipFactory,
        uint256 initialPrice,
        address owner,
        address msgSender,
        address stagingBox
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}
