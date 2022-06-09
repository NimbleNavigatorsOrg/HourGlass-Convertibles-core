// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

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
    struct Granularities {
        uint256 tranche;
        uint256 penalty;
        uint256 price;
    }
    bytes s_data;
    // ButtonWoodBondController s_bond;

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
     * @param price The initial price
     */
    function createConvertibleBondBox(
        IButtonWoodBondController bond,
        ICBBSlipFactory slipFactory,
        uint256 penalty,
        address collateralToken,
        address stableToken,
        uint256 price,
        uint256 trancheIndex
    ) public returns (address) {
        
        ConvertibleBondBox clone;
        Granularities memory granularities = Granularities(1000, 1000, 1e9);
        // s_bond = bond;

        {
            uint256 trancheCount = bond.trancheCount();
            uint256 maturityDate = bond.maturityDate();
            (ITranche safeTranche, uint256 safeRatio) = bond.tranches(trancheIndex);
            (ITranche riskTranche, uint256 riskRatio) = bond.tranches(trancheCount - 1);
            console2.log("address(safeTranche) LBF", address(safeTranche));
            console2.log("address(riskTranche) LBF", address(riskTranche));

            s_data = bytes.concat(
                abi.encodePacked(
                    bond,
                    slipFactory,
                    penalty,
                    collateralToken,
                    stableToken,
                    price,
                    trancheIndex,
                    granularities.tranche,
                    granularities.penalty,
                    granularities.price,
                    trancheCount,
                    maturityDate,
                    safeTranche
                ),
                abi.encodePacked(
                    safeRatio,
                    riskTranche,
                    riskRatio
                ));
            clone = ConvertibleBondBox(implementation.clone(s_data));
        }

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
