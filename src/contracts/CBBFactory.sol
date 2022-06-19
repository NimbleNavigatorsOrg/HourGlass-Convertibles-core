// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./ConvertibleBondBox.sol";
import "../interfaces/ICBBFactory.sol";

contract CBBFactory is ICBBFactory {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;
    bytes s_data;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @dev Initializer for Convertible Bond Box
     * @param bond The buttonTranche bond tied to this Convertible Bond Box
     * @param slipFactory The factory for the Slip-Tokens
     * @param penalty The penalty ratio for non-repayment of loan
     * @param collateralToken The base asset collateral token (a btn-Token)
     * @param stableToken The address of the stable-token being lent for the safe-Tranche
     * @param trancheIndex The index of the safe-Tranche
     * @param owner The initial owner
     */
    function createConvertibleBondBox(
        IButtonWoodBondController bond,
        ICBBSlipFactory slipFactory,
        uint256 penalty,
        address collateralToken,
        address stableToken,
        uint256 trancheIndex,
        address owner
    ) public returns (address) {
        ConvertibleBondBox clone;

        {
            uint256 trancheCount = bond.trancheCount();
            uint256 maturityDate = bond.maturityDate();
            (ITranche safeTranche, uint256 safeRatio) = bond.tranches(
                trancheIndex
            );
            (ITranche riskTranche, uint256 riskRatio) = bond.tranches(
                trancheCount - 1
            );

            s_data = bytes.concat(
                abi.encodePacked(
                    bond,
                    slipFactory,
                    penalty,
                    collateralToken,
                    stableToken,
                    trancheIndex,
                    trancheCount,
                    maturityDate,
                    safeTranche
                ),
                abi.encodePacked(safeRatio, riskTranche, riskRatio)
            );
            clone = ConvertibleBondBox(implementation.clone(s_data));
            ConvertibleBondBox(clone).initialize(owner);
        }

        //TODO: Need to update this event
        emit ConvertibleBondBoxCreated(
            collateralToken,
            stableToken,
            trancheIndex,
            penalty,
            msg.sender
        );
        return address(clone);
    }
}
