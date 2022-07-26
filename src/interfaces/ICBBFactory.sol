// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@buttonwood-protocol/tranche/contracts/interfaces/IBondController.sol";
import "./ISlipFactory.sol";

/**
 * @notice Interface for Convertible Bond Box factory contracts
 */
interface ICBBFactory {
    error TrancheIndexOutOfBounds(uint256 given, uint256 maxIndex);

    event ConvertibleBondBoxCreated(
        address stableToken,
        uint256 trancheIndex,
        uint256 penalty,
        address creator,
        address newBondBoxAdress
    );

    /// @notice Some parameters are invalid
    error InvalidParams();

    function createConvertibleBondBox(
        IBondController bond,
        ISlipFactory slipFactory,
        uint256 penalty,
        address stableToken,
        uint256 trancheIndex,
        address owner
    ) external returns (address);
}
