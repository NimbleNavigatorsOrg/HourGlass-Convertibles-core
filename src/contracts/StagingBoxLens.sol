// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IStagingBoxLens.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "@buttonwood-protocol/button-wrappers/contracts/interfaces/IButtonToken.sol";

contract StagingBoxLens is IStagingBoxLens {
    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewTransmitReInitBool(IStagingBox _stagingBox)
        public
        view
        returns (bool)
    {
        bool isLend = false;

        uint256 stableBalance = _stagingBox.stableToken().balanceOf(
            address(_stagingBox)
        );
        uint256 safeTrancheBalance = _stagingBox.safeTranche().balanceOf(
            address(_stagingBox)
        );
        uint256 expectedStableLoan = (safeTrancheBalance *
            _stagingBox.initialPrice()) / _stagingBox.priceGranularity();

        if (expectedStableLoan > stableBalance) {
            isLend = true;
        }

        return isLend;
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewSimpleWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
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
            _stagingBox.initialPrice() *
            _stagingBox.stableDecimals()) /
            _stagingBox.priceGranularity() /
            _stagingBox.trancheDecimals();

        return (stableLoanAmount, safeTrancheAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function vieSimplewWithdrawBorrowUnwrap(
        IStagingBox _stagingBox,
        uint256 _borrowSlipAmount
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        uint256 safeTrancheAmount = (_borrowSlipAmount *
            _stagingBox.priceGranularity() *
            _stagingBox.trancheDecimals()) /
            _stagingBox.initialPrice() /
            _stagingBox.stableDecimals();

        //calculate total amount of tranche tokens by dividing by safeRatio
        uint256 trancheTotal = (safeTrancheAmount *
            convertibleBondBox.s_trancheGranularity()) /
            convertibleBondBox.safeRatio();

        ////multiply with CDR to get btn token amount
        uint256 buttonAmount = (trancheTotal *
            convertibleBondBox.collateralToken().balanceOf(address(bond))) /
            bond.totalDebt();

        //calculate underlying with ButtonTokenWrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRedeemLendSlipsForStables(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) public view returns (uint256) {
        //calculate lendSlips to safeSlips w/ initialPrice
        uint256 safeSlipsAmount = (_lendSlipAmount *
            _stagingBox.priceGranularity() *
            _stagingBox.trancheDecimals()) /
            _stagingBox.initialPrice() /
            _stagingBox.stableDecimals();

        return _safeSlipsForStables(_stagingBox, safeSlipsAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRedeemSafeSlipsForStables(
        IStagingBox _stagingBox,
        uint256 _safeSlipAmount
    ) public view returns (uint256) {
        return _safeSlipsForStables(_stagingBox, _safeSlipAmount);
    }

    function _safeSlipsForStables(
        IStagingBox _stagingBox,
        uint256 _safeSlipAmount
    ) internal view returns (uint256) {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _stagingBox
        );

        //subtract fees
        _safeSlipAmount -=
            (_safeSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //calculate safeSlips to stables via math for CBB redeemStable
        uint256 cbbStableBalance = _stagingBox.stableToken().balanceOf(
            address(convertibleBondBox)
        );

        uint256 stableAmount = (_safeSlipAmount * cbbStableBalance) /
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
        //calculate lendSlips to safeSlips w/ initialPrice
        uint256 safeSlipsAmount = (_lendSlipAmount *
            _stagingBox.priceGranularity() *
            _stagingBox.trancheDecimals()) /
            _stagingBox.initialPrice() /
            _stagingBox.stableDecimals();

        return _safeSlipRedeemUnwrap(_stagingBox, safeSlipsAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRedeemSafeSlipsForTranches(
        IStagingBox _stagingBox,
        uint256 _safeSlipAmount
    ) public view returns (uint256, uint256) {
        return _safeSlipRedeemUnwrap(_stagingBox, _safeSlipAmount);
    }

    function _safeSlipRedeemUnwrap(
        IStagingBox _stagingBox,
        uint256 _safeSlipAmount
    ) internal view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //subtract fees
        _safeSlipAmount -=
            (_safeSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //safeSlips = safeTranches
        //calculate safe tranches to rebasing collateral via balance of safeTranche address
        uint256 buttonAmount = (wrapper.balanceOf(
            address(_stagingBox.safeTranche())
        ) * _safeSlipAmount) / _stagingBox.safeTranche().totalSupply();

        //calculate penalty riskTranche
        uint256 penaltyTrancheTotal = _stagingBox.riskTranche().balanceOf(
            address(convertibleBondBox)
        ) - IERC20(_stagingBox.riskSlipAddress()).totalSupply();

        uint256 penaltyTrancheRedeemable = (_safeSlipAmount *
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

    function viewRepayAndUnwrapSimple(
        IStagingBox _stagingBox,
        uint256 _stableAmount
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //minus fees
        uint256 stableFees = (_stableAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //calculate safeTranches for stables w/ current price
        uint256 safeTranchePayout = (_stableAmount *
            convertibleBondBox.s_priceGranularity() *
            convertibleBondBox.trancheDecimals()) /
            convertibleBondBox.currentPrice() /
            convertibleBondBox.stableDecimals();

        uint256 riskTranchePayout = (safeTranchePayout *
            convertibleBondBox.riskRatio()) / convertibleBondBox.safeRatio();

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
        return (underlyingAmount, _stableAmount, stableFees, riskTranchePayout);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRepayMaxAndUnwrapSimple(
        IStagingBox _stagingBox,
        uint256 _riskSlipAmount
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //riskTranche payout = riskSlipAmount
        uint256 riskTranchePayout = _riskSlipAmount;
        uint256 safeTranchePayout = (riskTranchePayout *
            _stagingBox.safeRatio()) / _stagingBox.riskRatio();

        //calculate repayment cost
        uint256 stablesOwed = (safeTranchePayout *
            convertibleBondBox.currentPrice() *
            convertibleBondBox.stableDecimals()) /
            convertibleBondBox.s_priceGranularity() /
            convertibleBondBox.trancheDecimals();

        //calculate stable Fees
        uint256 stableFees = (stablesOwed * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

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
        return (underlyingAmount, stablesOwed, stableFees, riskTranchePayout);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRepayAndUnwrapMature(
        IStagingBox _stagingBox,
        uint256 _stableAmount
    )
        public
        view
        returns (
            uint256,
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

        //calculate fees
        uint256 stableFees = (_stableAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //calculate tranches
        uint256 safeTranchepayout = (_stableAmount *
            convertibleBondBox.trancheDecimals()) /
            convertibleBondBox.stableDecimals();

        uint256 riskTranchePayout = (safeTranchepayout *
            _stagingBox.riskRatio()) / _stagingBox.safeRatio();

        //get collateral balance for safeTranche rebasing collateral output
        uint256 collateralBalanceSafe = wrapper.balanceOf(
            address(_stagingBox.safeTranche())
        );
        uint256 buttonAmount = (safeTranchepayout * collateralBalanceSafe) /
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
        return (underlyingAmount, _stableAmount, stableFees, riskTranchePayout);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewRepayMaxAndUnwrapMature(
        IStagingBox _stagingBox,
        uint256 _riskSlipAmount
    )
        public
        view
        returns (
            uint256,
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

        //Calculate tranches
        //riskTranche payout = riskSlipAmount
        uint256 safeTranchePayout = (_riskSlipAmount *
            _stagingBox.safeRatio()) / _stagingBox.riskRatio();

        uint256 stablesOwed = (safeTranchePayout *
            _stagingBox.stableDecimals()) / _stagingBox.trancheDecimals();

        //calculate stable Fees
        uint256 stableFees = (stablesOwed * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //get collateral balance for safeTranche rebasing collateral output
        uint256 buttonAmount = (safeTranchePayout *
            wrapper.balanceOf(address(_stagingBox.safeTranche()))) /
            convertibleBondBox.safeTranche().totalSupply();

        //get collateral balance for riskTranche rebasing collateral output
        uint256 collateralBalanceRisk = wrapper.balanceOf(
            address(_stagingBox.riskTranche())
        );
        buttonAmount +=
            (_riskSlipAmount * collateralBalanceRisk) /
            convertibleBondBox.riskTranche().totalSupply();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, stablesOwed, stableFees, _riskSlipAmount);
    }

    /**
     * @inheritdoc IStagingBoxLens
     */

    function viewMaxRedeemBorrowSlip(IStagingBox _stagingBox)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _stagingBox
        );

        uint256 riskSlipBalance = convertibleBondBox.riskSlip().balanceOf(
            address(_stagingBox)
        );
        uint256 stableBalance = convertibleBondBox.stableToken().balanceOf(
            address(_stagingBox)
        );

        uint256 maxBorrowSlipAmountFromSlips = (riskSlipBalance *
            _stagingBox.safeRatio()) / _stagingBox.riskRatio();
        uint256 maxBorrowSlipAmountFromStables = (stableBalance *
            _stagingBox.priceGranularity()) / _stagingBox.initialPrice();

        return
            min(maxBorrowSlipAmountFromSlips, maxBorrowSlipAmountFromStables);
    }

    function fetchElasticStack(IStagingBox _stagingBox)
        internal
        view
        returns (
            IConvertibleBondBox,
            IBondController,
            IButtonToken,
            IERC20
        )
    {
        IConvertibleBondBox convertibleBondBox = _stagingBox
            .convertibleBondBox();
        IBondController bond = convertibleBondBox.bond();
        IButtonToken wrapper = IButtonToken(bond.collateralToken());
        IERC20 underlying = IERC20(wrapper.underlying());

        return (convertibleBondBox, bond, wrapper, underlying);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a <= b ? a : b;
    }
}
