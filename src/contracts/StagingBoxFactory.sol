// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./StagingBox.sol";
import "./CBBFactory.sol";
import "../interfaces/IButtonWoodBondController.sol";
import "../interfaces/IStagingBoxFactory.sol";
import "../interfaces/IConvertibleBondBox.sol";

contract StagingBoxFactory is IStagingBoxFactory {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @dev Initializer for Convertible Bond Box
     * @param cBBFactory The ConvertibleBondBox factory
     * @param slipFactory The factory for the Slip-Tokens
     * @param bond The buttonwood bond
     * @param penalty The penalty for late repay
     * @param collateralToken The collateral token
     * @param stableToken The stable token
     * @param trancheIndex The tranche index used to determine the safe tranche
     * @param initialPrice The initial price of the safe asset
     * @param stagingBoxOwner The owner of the SB
     * @param cbbOwner The owner of the ConvertibleBondBox
     */

    function createStagingBox(
        CBBFactory cBBFactory,
        ISlipFactory slipFactory,
        IButtonWoodBondController bond,
        uint256 penalty,
        address collateralToken,
        address stableToken,
        uint256 trancheIndex,
        uint256 initialPrice,
        address stagingBoxOwner,
        address cbbOwner
    ) public returns (address) {

        ConvertibleBondBox convertibleBondBox = ConvertibleBondBox(cBBFactory.createConvertibleBondBox(
            bond,
            slipFactory,
            penalty,
            collateralToken,
            stableToken,
            trancheIndex,
            cbbOwner
        ));

        bytes memory data = abi.encodePacked(
            slipFactory, 
            convertibleBondBox, 
            initialPrice, 
            convertibleBondBox.stableToken(),
            convertibleBondBox.safeTranche(),
            convertibleBondBox.s_safeSlipTokenAddress(),
            convertibleBondBox.safeRatio(),
            convertibleBondBox.riskTranche(),
            convertibleBondBox.s_riskSlipTokenAddress(),
            convertibleBondBox.riskRatio(),
            convertibleBondBox.s_priceGranularity(),
            stagingBoxOwner
            );
        StagingBox clone = StagingBox(implementation.clone(data));

        clone.initialize(stagingBoxOwner);

        emit StagingBoxCreated(
            convertibleBondBox,
            slipFactory,
            initialPrice,
            stagingBoxOwner,
            msg.sender
        );

        return address(clone);
    }
}
