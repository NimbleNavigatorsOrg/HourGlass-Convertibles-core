// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./LendingBox.sol";
import "../interfaces/ILendingBoxFactory.sol";

contract LendingBoxFactory is ILendingBoxFactory {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @dev Initializer for Lending Box
     * @param bond The buttonTranche bond tied to this Convertible Bond Box
     * @param slipFactory The factory for the Slip-Tokens
     * @param penalty The penalty ratio for non-repayment of loan
     * @param collateralToken The base asset collateral token (a btn-Token)
     * @param stableToken The address of the stable-token being lent for the safe-Tranche
     * @param trancheIndex The index of the safe-Tranche
     * @param price The initial price
     */
    function createLendingBox(
        IButtonWoodBondController bond,
        ISlipFactory slipFactory,
        uint256 penalty,
        address collateralToken,
        address stableToken,
        uint256 price,
        uint256 trancheIndex
    ) public returns (address) {
        bytes memory data = abi.encodePacked(
            bond,
            slipFactory,
            penalty,
            collateralToken,
            stableToken,
            price,
            trancheIndex
        );
        LendingBox clone = LendingBox(implementation.clone(data));

        emit LendingBoxCreated(
            collateralToken,
            stableToken,
            trancheIndex,
            penalty,
            msg.sender
        );
        return address(clone);
    }
}
