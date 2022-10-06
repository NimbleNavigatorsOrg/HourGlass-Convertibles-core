// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;
import "./IConvertibleBondBox.sol";

/**
 * @notice Interface for Convertible Bond Box factory contracts
 */

interface IIBOBoxFactory {
    event IBOBoxCreated(
        address msgSender,
        address IBOBox,
        address slipFactory
    );

    event IBOBoxReplaced(
        IConvertibleBondBox convertibleBondBox,
        address msgSender,
        address oldIBOBox,
        address newIBOBox,
        address slipFactory
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}
