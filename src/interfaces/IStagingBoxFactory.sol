// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;
import "./IConvertibleBondBox.sol";

/**
 * @notice Interface for Convertible Bond Box factory contracts
 */

interface IStagingBoxFactory {
    // TODO: test this event
    event StagingBoxCreated(
        IConvertibleBondBox convertibleBondBox,
        uint256 initialPrice,
        address owner,
        address msgSender,
        address stagingBox
    );

    event StagingBoxReplaced(
        IConvertibleBondBox convertibleBondBox,
        uint256 initialPrice,
        address owner,
        address msgSender,
        address oldStagingBox,
        address newStagingBox
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}
