// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./StagingBox.sol";
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
     * @param convertibleBondBox The ConvertibleBondBox tied to this StagingBox
     * @param slipFactory The factory for the Slip-Tokens
     * @param initialPrice The initial price
     * @param owner The initial owner
     */

    function createStagingBox(
        IConvertibleBondBox convertibleBondBox,
        ICBBSlipFactory slipFactory,
        uint256 initialPrice,
        address owner
    ) public returns (address) {
        //FactoryStuff
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
            owner
            );
        StagingBox clone = StagingBox(implementation.clone(data));

        clone.initialize(owner);

        emit StagingBoxCreated(
            convertibleBondBox,
            slipFactory,
            initialPrice,
            owner,
            msg.sender
        );

        return address(clone);
    }
}
