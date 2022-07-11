// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./ConvertibleBondBox.sol";
import "../interfaces/ICBBFactory.sol";
import "../interfaces/ISlipFactory.sol";
import "../interfaces/ISlip.sol";

contract CBBFactory is ICBBFactory {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;
    bytes s_data;

    struct TranchePair {
        ITranche safeTranche;
        uint256 safeRatio;
        ITranche riskTranche;
        uint256 riskRatio;
    }

    struct SlipPair {
        address safeAddress;
        address riskAddress;
    }

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @dev Initializer for Convertible Bond Box
     * @param bond The buttonTranche bond tied to this Convertible Bond Box
     * @param slipFactory The factory for the Slip-Tokens
     * @param penalty The penalty ratio for non-repayment of loan
     * @param stableToken The address of the stable-token being lent for the safe-Tranche
     * @param trancheIndex The index of the safe-Tranche
     * @param owner The initial owner
     */
    function createConvertibleBondBox(
        IButtonWoodBondController bond,
        ISlipFactory slipFactory,
        uint256 penalty,
        address stableToken,
        uint256 trancheIndex,
        address owner
    ) public returns (address) {
        ConvertibleBondBox clone;

        TranchePair memory TrancheData = getBondData(bond, trancheIndex);

        SlipPair memory SlipData = deploySlips(
            slipFactory,
            TrancheData.safeTranche,
            TrancheData.riskTranche
        );

        uint256 maturityDate = bond.maturityDate();
        address collateralToken = bond.collateralToken();

        s_data = bytes.concat(
            abi.encodePacked(
                bond,
                SlipData.safeAddress,
                SlipData.riskAddress,
                penalty,
                collateralToken,
                stableToken,
                trancheIndex,
                maturityDate
            ),
            abi.encodePacked(
                TrancheData.safeTranche,
                TrancheData.safeRatio,
                TrancheData.riskTranche,
                TrancheData.riskRatio
            )
        );

        //Clone CBB and initialize
        clone = ConvertibleBondBox(implementation.clone(s_data));
        clone.initialize(owner);

        //Transfer ownership of slips back to CBB
        ISlip(SlipData.safeAddress).changeOwner(address(clone));
        ISlip(SlipData.riskAddress).changeOwner(address(clone));

        //emit Event
        emit ConvertibleBondBoxCreated(
            stableToken,
            trancheIndex,
            penalty,
            msg.sender
        );
        return address(clone);
    }

    function deploySlips(
        ISlipFactory slipFactory,
        ITranche safeTranche,
        ITranche riskTranche
    ) private returns (SlipPair memory) {
        string memory collateralSymbolSafe = IERC20Metadata(
            address(safeTranche)
        ).symbol();
        string memory collateralSymbolRisk = IERC20Metadata(
            address(riskTranche)
        ).symbol();

        address safeSlipAddress = slipFactory.createSlip(
            string(abi.encodePacked("SLIP-", collateralSymbolSafe)),
            "Safe-CBB-Slip",
            address(safeTranche)
        );

        address riskSlipAddress = slipFactory.createSlip(
            string(abi.encodePacked("SLIP-", collateralSymbolRisk)),
            "Risk-CBB-Slip",
            address(riskTranche)
        );

        SlipPair memory SlipData = SlipPair(safeSlipAddress, riskSlipAddress);

        return SlipData;
    }

    function getBondData(IButtonWoodBondController bond, uint256 trancheIndex)
        private
        returns (TranchePair memory)
    {
        uint256 trancheCount = bond.trancheCount();

        // Safe-Tranche cannot be the Z-Tranche
        if (trancheIndex >= trancheCount - 1)
            revert TrancheIndexOutOfBounds({
                given: trancheIndex,
                maxIndex: trancheCount - 2
            });

        (ITranche safeTranche, uint256 safeRatio) = bond.tranches(trancheIndex);
        (ITranche riskTranche, uint256 riskRatio) = bond.tranches(
            trancheCount - 1
        );

        TranchePair memory TrancheData = TranchePair(
            safeTranche,
            safeRatio,
            riskTranche,
            riskRatio
        );

        return TrancheData;
    }
}
