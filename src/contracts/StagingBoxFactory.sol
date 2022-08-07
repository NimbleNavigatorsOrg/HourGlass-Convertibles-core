// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./StagingBox.sol";
import "./ConvertibleBondBox.sol";
import "../interfaces/ICBBFactory.sol";
import "../interfaces/IStagingBoxFactory.sol";

contract StagingBoxFactory is IStagingBoxFactory {
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;

    mapping(address => address) public CBBtoSB;

    struct SlipPair {
        address lendSlip;
        address borrowSlip;
    }

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @dev Deploys a staging box with a CBB
     * @param cBBFactory The ConvertibleBondBox factory
     * @param slipFactory The factory for the Slip-Tokens
     * @param bond The buttonwood bond
     * @param penalty The penalty for late repay
     * @param stableToken The stable token
     * @param trancheIndex The tranche index used to determine the safe tranche
     * @param initialPrice The initial price of the safe asset
     * @param cbbOwner The owner of the ConvertibleBondBox
     */

    function createStagingBoxWithCBB(
        ICBBFactory cBBFactory,
        ISlipFactory slipFactory,
        IBondController bond,
        uint256 penalty,
        address stableToken,
        uint256 trancheIndex,
        uint256 initialPrice,
        address cbbOwner
    ) public returns (address) {
        ConvertibleBondBox convertibleBondBox = ConvertibleBondBox(
            cBBFactory.createConvertibleBondBox(
                bond,
                slipFactory,
                penalty,
                stableToken,
                trancheIndex,
                address(this)
            )
        );

        address deployedSB = this.createStagingBoxOnly(
            slipFactory,
            convertibleBondBox,
            initialPrice,
            cbbOwner
        );

        //transfer ownership of CBB to SB
        convertibleBondBox.transferOwnership(deployedSB);

        return deployedSB;
    }

    /**
     * @dev Deploys only a staging box
     * @param slipFactory The factory for the Slip-Tokens
     * @param convertibleBondBox The CBB tied to the staging box being deployed
     * @param initialPrice The initial price of the safe asset
     * @param owner The owner of the StagingBox
     */

    function createStagingBoxOnly(
        ISlipFactory slipFactory,
        ConvertibleBondBox convertibleBondBox,
        uint256 initialPrice,
        address owner
    ) public returns (address) {
        require(
            msg.sender == convertibleBondBox.owner(),
            "StagingBoxFactory: Deployer not owner of CBB"
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
                convertibleBondBox.s_priceGranularity()
            )
        );

        // clone staging box
        StagingBox clone = StagingBox(implementation.clone(data));
        clone.initialize(owner);

        //tansfer slips ownership to staging box
        ISlip(SlipData.lendSlip).changeOwner(address(clone));
        ISlip(SlipData.borrowSlip).changeOwner(address(clone));

        address oldStagingBox = CBBtoSB[address(convertibleBondBox)];

        if (oldStagingBox == address(0)) {
            emit StagingBoxCreated(
                convertibleBondBox,
                initialPrice,
                owner,
                msg.sender,
                address(clone)
            );
        } else {
            emit StagingBoxReplaced(
                convertibleBondBox,
                initialPrice,
                owner,
                msg.sender,
                oldStagingBox,
                address(clone)
            );
        }

        CBBtoSB[address(convertibleBondBox)] = address(clone);

        return address(clone);
    }

    function deploySlips(
        ISlipFactory slipFactory,
        address safeSlip,
        address riskSlip
    ) private returns (SlipPair memory) {
        // clone deploy lend slip
        address lendSlipTokenAddress = slipFactory.createSlip(
            "Staging-Lender-Slip",
            IERC20Metadata(safeSlip).name(),
            safeSlip
        );

        //clone deployborrow slip
        address borrowSlipTokenAddress = slipFactory.createSlip(
            "Staging-Borrower-Slip",
            IERC20Metadata(riskSlip).name(),
            riskSlip
        );

        SlipPair memory SlipData = SlipPair(
            lendSlipTokenAddress,
            borrowSlipTokenAddress
        );

        return SlipData;
    }
}
