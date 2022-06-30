// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IStagingBoxLens.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "../interfaces/IButtonWoodBondController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/button-wrappers/contracts/interfaces/IButtonToken.sol";

contract StagingBoxLens is IStagingBoxLens {
    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewSimpleWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //calculate rebase token qty w wrapperfunction
        uint256 buttonAmount = wrapper.underlyingToWrapper(_amountRaw);

        //calculate safeTranche (borrowSlip amount) amount with tranche ratio & CDR
        uint256 bondCollateralBalance = IERC20(bond.collateralToken())
            .balanceOf(address(bond));
        uint256 safeTrancheAmount = (buttonAmount *
            _stagingBox.safeRatio() *
            bond.totalDebt()) /
            bondCollateralBalance /
            convertibleBondBox.s_trancheGranularity();

        //calculate stabletoken amount w/ safeTrancheAmount & initialPrice
        uint256 stableLoanAmount = (safeTrancheAmount *
            _stagingBox.initialPrice()) / _stagingBox.priceGranularity();

        return (stableLoanAmount, safeTrancheAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRedeemLendSlipsForStables(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) public view returns (uint256) {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _stagingBox
        );

        //calculate lendSlips to safeSlips w/ initialPrice
        uint256 safeSlipsAmount = (_lendSlipAmount *
            _stagingBox.priceGranularity()) / _stagingBox.initialPrice();

        //subtract fees
        safeSlipsAmount -=
            (safeSlipsAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //calculate safeSlips to stables via math for CBB redeemStable
        uint256 cbbStableBalance = _stagingBox.stableToken().balanceOf(
            address(convertibleBondBox)
        );

        uint256 stableAmount = (safeSlipsAmount * cbbStableBalance) /
            convertibleBondBox.s_repaidSafeSlips();

        return stableAmount;
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRedeemLendSlipsForTranches(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //calculate lendSlips to safeSlips w/ initialPrice
        uint256 safeSlipsAmount = (_lendSlipAmount *
            _stagingBox.priceGranularity()) / _stagingBox.initialPrice();

        //subtract fees
        safeSlipsAmount -=
            (safeSlipsAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //safeSlips = safeTranches
        //calculate safe tranches to rebasing collateral via balance of safeTranche address
        uint256 buttonAmount = (wrapper.balanceOf(
            address(_stagingBox.safeTranche())
        ) * safeSlipsAmount) / _stagingBox.safeTranche().totalSupply();

        //calculate penalty riskTranche
        uint256 penaltyTrancheTotal = _stagingBox.riskTranche().balanceOf(
            address(convertibleBondBox)
        ) - IERC20(_stagingBox.riskSlipAddress()).totalSupply();

        uint256 penaltyTrancheRedeemable = (safeSlipsAmount *
            penaltyTrancheTotal) /
            (IERC20(_stagingBox.safeSlipAddress()).totalSupply() -
                convertibleBondBox.s_repaidSafeSlips());

        //calculate rebasing collateral redeemable for riskTranche penalty
        //total the rebasing collateral
        buttonAmount +=
            (wrapper.balanceOf(address(_stagingBox.riskTranche())) *
                penaltyTrancheRedeemable) /
            _stagingBox.riskTranche().totalSupply();

        //convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRedeemRiskSlipsForTranches(
        IStagingBox _stagingBox,
        uint256 _riskSlipAmount
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //subtract fees
        _riskSlipAmount -=
            (_riskSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //calculate riskSlip to riskTranche - penalty
        uint256 riskTrancheAmount = _riskSlipAmount -
            (_riskSlipAmount * convertibleBondBox.penalty()) /
            convertibleBondBox.s_penaltyGranularity();

        //calculate rebasing collateral redeemable for riskTranche - penalty via tranche balance
        uint256 buttonAmount = (wrapper.balanceOf(
            address(_stagingBox.riskTranche())
        ) * riskTrancheAmount) / _stagingBox.riskTranche().totalSupply();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    //TODO: Account for fees

    function viewRepayAndUnwrapSimple(
        IStagingBox _stagingBox,
        uint256 _stableAmount
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //minus fees
        _stableAmount -=
            (_stableAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //calculate safeTranches for stables w/ current price
        uint256 safeTranchePayout = (_stableAmount *
            convertibleBondBox.s_priceGranularity()) /
            convertibleBondBox.currentPrice();

        //get collateral balance for rebasing collateral output
        uint256 collateralBalance = wrapper.balanceOf(address(bond));
        uint256 buttonAmount = (safeTranchePayout *
            convertibleBondBox.s_trancheGranularity() *
            collateralBalance) /
            convertibleBondBox.safeRatio() /
            bond.totalDebt();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRepayAndUnwrapMature(
        IStagingBox _stagingBox,
        uint256 _stableAmount
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //minus fees
        _stableAmount -=
            (_stableAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //safeTranchepayout = _stableAmount @ maturity
        uint256 safeTranchePayout = _stableAmount;
        uint256 riskTranchePayout = (_stableAmount * _stagingBox.riskRatio()) /
            _stagingBox.safeRatio();

        //get collateral balance for safeTranche rebasing collateral output
        uint256 collateralBalanceSafe = wrapper.balanceOf(
            address(_stagingBox.safeTranche())
        );
        uint256 buttonAmount = (safeTranchePayout * collateralBalanceSafe) /
            convertibleBondBox.safeTranche().totalSupply();

        //get collateral balance for riskTranche rebasing collateral output
        uint256 collateralBalanceRisk = wrapper.balanceOf(
            address(_stagingBox.riskTranche())
        );
        buttonAmount +=
            (riskTranchePayout * collateralBalanceRisk) /
            convertibleBondBox.riskTranche().totalSupply();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    //TODO: Account for fees

    function viewRepayAndUnwrapMax(IStagingBox _stagingBox)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //get msg.sender's risk slip balance
        uint256 riskSlipAmount = IERC20(_stagingBox.riskSlipAddress())
            .balanceOf(msg.sender);

        //riskTranche payout = riskSlipAmount
        uint256 riskTranchePayout = riskSlipAmount;
        uint256 safeTranchePayout = (riskTranchePayout *
            _stagingBox.safeRatio()) / _stagingBox.riskRatio();

        //calculate repayment cost
        uint256 stableRepayment = (safeTranchePayout *
            convertibleBondBox.currentPrice()) /
            convertibleBondBox.s_priceGranularity();

        //get collateral balance for rebasing collateral output
        uint256 collateralBalance = wrapper.balanceOf(address(bond));
        uint256 buttonAmount = (safeTranchePayout *
            convertibleBondBox.s_trancheGranularity() *
            collateralBalance) /
            convertibleBondBox.safeRatio() /
            bond.totalDebt();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (stableRepayment, underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    //TODO: Account for fees

    function viewRepayAndUnwrapMaxMature(IStagingBox _stagingBox)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //get msg.sender's risk slip balance
        uint256 riskSlipAmount = IERC20(_stagingBox.riskSlipAddress())
            .balanceOf(msg.sender);

        //riskTranche payout = riskSlipAmount
        uint256 riskTranchePayout = riskSlipAmount;
        uint256 safeTranchePayout = (riskTranchePayout *
            _stagingBox.safeRatio()) / _stagingBox.riskRatio();

        //calculate repayment cost
        uint256 stableRepayment = (safeTranchePayout);

        //get collateral balance for safeTranche rebasing collateral output
        uint256 collateralBalanceSafe = wrapper.balanceOf(
            address(_stagingBox.safeTranche())
        );
        uint256 buttonAmount = (safeTranchePayout * collateralBalanceSafe) /
            convertibleBondBox.safeTranche().totalSupply();

        //get collateral balance for riskTranche rebasing collateral output
        uint256 collateralBalanceRisk = wrapper.balanceOf(
            address(_stagingBox.riskTranche())
        );
        buttonAmount +=
            (riskTranchePayout * collateralBalanceRisk) /
            convertibleBondBox.riskTranche().totalSupply();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (stableRepayment, underlyingAmount, buttonAmount);
    }

    function fetchElasticStack(IStagingBox _stagingBox)
        internal
        view
        returns (
            IConvertibleBondBox,
            IButtonWoodBondController,
            IButtonToken,
            IERC20
        )
    {
        IConvertibleBondBox convertibleBondBox = _stagingBox
            .convertibleBondBox();
        IButtonWoodBondController bond = convertibleBondBox.bond();
        IButtonToken wrapper = IButtonToken(bond.collateralToken());
        IERC20 underlying = IERC20(wrapper.underlying());

        return (convertibleBondBox, bond, wrapper, underlying);
    }
}
