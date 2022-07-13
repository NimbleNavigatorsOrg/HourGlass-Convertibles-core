// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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

    struct SlipPair {
        address lendSlip;
        address borrowSlip;
    }

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @dev Initializer for Convertible Bond Box
     * @param cBBFactory The ConvertibleBondBox factory
     * @param slipFactory The factory for the Slip-Tokens
     * @param bond The buttonwood bond
     * @param penalty The penalty for late repay
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
        address stableToken,
        uint256 trancheIndex,
        uint256 initialPrice,
        address stagingBoxOwner,
        address cbbOwner
    ) public returns (address) {
        ConvertibleBondBox convertibleBondBox = ConvertibleBondBox(
            cBBFactory.createConvertibleBondBox(
                bond,
                slipFactory,
                penalty,
                stableToken,
                trancheIndex,
                cbbOwner
            )
        );

        SlipPair memory SlipData = deploySlips(
            slipFactory,
            address(convertibleBondBox.safeSlip()),
            address(convertibleBondBox.riskSlip())
        );

        bytes memory data = bytes.concat(
            abi.encodePacked(
                SlipData.lendSlip,
                SlipData.borrowSlip,
                convertibleBondBox,
                initialPrice,
                convertibleBondBox.stableToken(),
                convertibleBondBox.safeTranche(),
                address(convertibleBondBox.safeSlip()),
                convertibleBondBox.safeRatio()
            ),
            abi.encodePacked(
                convertibleBondBox.riskTranche(),
                address(convertibleBondBox.riskSlip()),
                convertibleBondBox.riskRatio(),
                convertibleBondBox.s_priceGranularity(),
                stagingBoxOwner
            )
        );

        // clone staging box
        StagingBox clone = StagingBox(implementation.clone(data));
        clone.initialize(stagingBoxOwner);

        //tansfer slips ownership to staging box
        ISlip(SlipData.lendSlip).changeOwner(address(clone));
        ISlip(SlipData.borrowSlip).changeOwner(address(clone));

        emit StagingBoxCreated(
            convertibleBondBox,
            slipFactory,
            initialPrice,
            stagingBoxOwner,
            msg.sender,
            address(clone)
        );

        return address(clone);
    }

    function deploySlips(
        ISlipFactory slipFactory,
        address safeSlip,
        address riskSlip
    ) private returns (SlipPair memory) {
        // clone deploy lend slip
        address lendSlipTokenAddress = slipFactory.createSlip(
            IERC20Metadata(safeSlip).symbol(),
            "Staging-Lender-Slip",
            safeSlip
        );

        //clone deployborrow slip
        address borrowSlipTokenAddress = slipFactory.createSlip(
            IERC20Metadata(riskSlip).symbol(),
            "Staging-Borrower-Slip",
            riskSlip
        );

        SlipPair memory SlipData = SlipPair(
            lendSlipTokenAddress,
            borrowSlipTokenAddress
        );

        return SlipData;
    }
}
