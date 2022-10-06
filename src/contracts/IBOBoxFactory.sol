// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IBOBox.sol";
import "./ConvertibleBondBox.sol";
import "../interfaces/ICBBFactory.sol";
import "../interfaces/IIBOBoxFactory.sol";

contract IBOBoxFactory is IIBOBoxFactory, Context {
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;

    mapping(address => address) public CBBtoIBO;

    struct SlipPair {
        address buyOrder;
        address issueOrder;
    }

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @dev Deploys a IBO box with a CBB
     * @param cBBFactory The ConvertibleBondBox factory
     * @param slipFactory The factory for the Slip-Tokens
     * @param bond The buttonwood bond
     * @param penalty The penalty for late repay
     * @param stableToken The stable token
     * @param trancheIndex The tranche index used to determine the safe tranche
     * @param initialPrice The initial price of the safe asset
     * @param cbbOwner The owner of the ConvertibleBondBox
     */

    function createIBOBoxWithCBB(
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

        address deployedIBOB = this.createIBOBoxOnly(
            slipFactory,
            convertibleBondBox,
            initialPrice,
            cbbOwner
        );

        //transfer ownership of CBB to IBO
        convertibleBondBox.transferOwnership(deployedIBOB);

        return deployedIBOB;
    }

    /**
     * @dev Deploys only a IBO box
     * @param slipFactory The factory for the Slip-Tokens
     * @param convertibleBondBox The CBB tied to the IBO box being deployed
     * @param initialPrice The initial price of the safe asset
     * @param owner The owner of the IBOBox
     */

    function createIBOBoxOnly(
        ISlipFactory slipFactory,
        ConvertibleBondBox convertibleBondBox,
        uint256 initialPrice,
        address owner
    ) public returns (address) {
        require(
            _msgSender() == convertibleBondBox.owner(),
            "IBOBoxFactory: Deployer not owner of CBB"
        );

        SlipPair memory SlipData = deploySlips(
            slipFactory,
            address(convertibleBondBox.safeTranche()),
            address(convertibleBondBox.riskTranche()),
            address(convertibleBondBox.stableToken())
        );

        bytes memory data = bytes.concat(
            abi.encodePacked(
                SlipData.buyOrder,
                SlipData.issueOrder,
                convertibleBondBox,
                initialPrice,
                convertibleBondBox.stableToken(),
                convertibleBondBox.safeTranche(),
                address(convertibleBondBox.bondSlip()),
                convertibleBondBox.safeRatio()
            ),
            abi.encodePacked(
                convertibleBondBox.riskTranche(),
                address(convertibleBondBox.debtSlip()),
                convertibleBondBox.riskRatio(),
                convertibleBondBox.s_priceGranularity(),
                convertibleBondBox.trancheDecimals(),
                convertibleBondBox.stableDecimals()
            )
        );

        // clone IBO box
        IBOBox clone = IBOBox(implementation.clone(data));
        clone.initialize(owner);

        //tansfer slips ownership to IBO box
        ISlip(SlipData.buyOrder).changeOwner(address(clone));
        ISlip(SlipData.issueOrder).changeOwner(address(clone));

        address oldIBOBox = CBBtoIBO[address(convertibleBondBox)];

        if (oldIBOBox == address(0)) {
            emit IBOBoxCreated(
                _msgSender(),
                address(clone),
                address(slipFactory)
            );
        } else {
            emit IBOBoxReplaced(
                convertibleBondBox,
                _msgSender(),
                oldIBOBox,
                address(clone),
                address(slipFactory)
            );
        }

        CBBtoIBO[address(convertibleBondBox)] = address(clone);

        return address(clone);
    }

    function deploySlips(
        ISlipFactory slipFactory,
        address safeTranche,
        address riskTranche,
        address stableToken
    ) private returns (SlipPair memory) {
        string memory collateralSymbolSafe = IERC20Metadata(
            address(safeTranche)
        ).symbol();
        string memory collateralSymbolRisk = IERC20Metadata(
            address(riskTranche)
        ).symbol();

        // clone deploy lend slip
        address buyOrderTokenAddress = slipFactory.createSlip(
            "IBO-Buy-Slip",
            string(abi.encodePacked("IBO-BUY-SLIP-", collateralSymbolSafe)),
            stableToken
        );

        //clone deployborrow slip
        address issueOrderTokenAddress = slipFactory.createSlip(
            "IBO-Sell-Slip",
            string(abi.encodePacked("IBO-SELL-SLIP-", collateralSymbolRisk)),
            stableToken
        );

        SlipPair memory SlipData = SlipPair(
            buyOrderTokenAddress,
            issueOrderTokenAddress
        );

        return SlipData;
    }
}
