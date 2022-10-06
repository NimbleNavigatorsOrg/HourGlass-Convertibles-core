// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IIBOBoxLens.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "@buttonwood-protocol/button-wrappers/contracts/interfaces/IButtonToken.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract IBOBoxLens is IIBOBoxLens {
    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewTransmitActivateBool(IIBOBox _IBOBox)
        public
        view
        returns (bool)
    {
        bool isLend = false;

        uint256 stableBalance = _IBOBox.stableToken().balanceOf(
            address(_IBOBox)
        );
        uint256 safeTrancheBalance = _IBOBox.safeTranche().balanceOf(
            address(_IBOBox)
        );
        uint256 expectedStableLoan = (safeTrancheBalance *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        //if excess borrowDemand, call lend
        if (expectedStableLoan >= stableBalance) {
            isLend = true;
        }

        return isLend;
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewSimpleWrapTrancheBorrow(IIBOBox _IBOBox, uint256 _amountRaw)
        public
        view
        returns (uint256, uint256)
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //calculate rebase token qty w wrapperfunction
        uint256 buttonAmount = wrapper.underlyingToWrapper(_amountRaw);

        //calculate safeTranche (borrowSlip amount) amount with tranche ratio & CDR
        uint256 bondCollateralBalance = wrapper.balanceOf(address(bond));
        uint256 bondDebt = bond.totalDebt();

        if (bondDebt == 0) {
            bondDebt = buttonAmount;
            bondCollateralBalance = buttonAmount;
        }

        uint256 safeTrancheAmount = (buttonAmount *
            convertibleBondBox.safeRatio() *
            bondDebt) /
            bondCollateralBalance /
            convertibleBondBox.s_trancheGranularity();

        //calculate stabletoken amount w/ safeTrancheAmount & initialPrice
        uint256 stableLoanAmount = (safeTrancheAmount *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        return (stableLoanAmount, safeTrancheAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewSimpleWithdrawBorrowUnwrap(
        IIBOBox _IBOBox,
        uint256 _borrowSlipAmount
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        uint256 safeTrancheAmount = (_borrowSlipAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.stableDecimals();

        uint256 riskTrancheAmount = (safeTrancheAmount *
            convertibleBondBox.riskRatio()) / convertibleBondBox.safeRatio();

        //calculate total amount of tranche tokens by dividing by safeRatio
        uint256 trancheTotal = safeTrancheAmount + riskTrancheAmount;

        ////multiply with CDR to get btn token amount
        uint256 buttonAmount = 0;
        if (bond.totalDebt() > 0) {
            if (!bond.isMature()) {
                buttonAmount =
                    (trancheTotal *
                        convertibleBondBox.collateralToken().balanceOf(
                            address(bond)
                        )) /
                    bond.totalDebt();
            } else {
                buttonAmount =
                    (safeTrancheAmount *
                        convertibleBondBox.collateralToken().balanceOf(
                            address(convertibleBondBox.safeTranche())
                        )) /
                    convertibleBondBox.safeTranche().totalSupply();
                buttonAmount +=
                    (riskTrancheAmount *
                        convertibleBondBox.collateralToken().balanceOf(
                            address(convertibleBondBox.riskTranche())
                        )) /
                    convertibleBondBox.riskTranche().totalSupply();
            }
        }

        //calculate underlying with ButtonTokenWrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewWithdrawLendSlip(IIBOBox _IBOBox, uint256 _lendSlipAmount)
        external
        view
        returns (uint256)
    {
        return _lendSlipAmount;
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewRedeemBorrowSlipForRiskSlip(
        IIBOBox _IBOBox,
        uint256 _borrowSlipAmount
    ) external view returns (uint256, uint256) {
        uint256 loanAmount = _borrowSlipAmount;

        uint256 riskSlipAmount = (loanAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.riskRatio() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.safeRatio() /
            _IBOBox.stableDecimals();

        return (riskSlipAmount, loanAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewRedeemLendSlipForSafeSlip(
        IIBOBox _IBOBox,
        uint256 _lendSlipAmount
    ) external view returns (uint256) {
        uint256 safeSlipAmount = (_lendSlipAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.stableDecimals();

        return (safeSlipAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewRedeemLendSlipsForStables(
        IIBOBox _IBOBox,
        uint256 _lendSlipAmount
    ) public view returns (uint256, uint256) {
        //calculate lendSlips to safeSlips w/ initialPrice
        uint256 safeSlipsAmount = (_lendSlipAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.stableDecimals();

        return _safeSlipsForStablesWithFees(_IBOBox, safeSlipsAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRedeemSafeSlipsForStables(
        IIBOBox _IBOBox,
        uint256 _safeSlipAmount
    ) public view returns (uint256, uint256) {
        return _safeSlipsForStablesWithFees(_IBOBox, _safeSlipAmount);
    }

    function _safeSlipsForStablesWithFees(
        IIBOBox _IBOBox,
        uint256 _safeSlipAmount
    ) internal view returns (uint256, uint256) {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 feeSlip = (_safeSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        uint256 stableAmount = _safeSlipsForStables(
            _IBOBox,
            _safeSlipAmount - feeSlip
        );
        uint256 feeAmount = _safeSlipsForStables(_IBOBox, feeSlip);

        return (stableAmount, feeAmount);
    }

    function _safeSlipsForStables(IIBOBox _IBOBox, uint256 _safeSlipAmount)
        internal
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 feeSlip = (_safeSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //subtract fees
        _safeSlipAmount -= feeSlip;

        //calculate safeSlips to stables via math for CBB redeemStable
        uint256 cbbStableBalance = _IBOBox.stableToken().balanceOf(
            address(convertibleBondBox)
        );

        uint256 stableAmount = 0;

        if (convertibleBondBox.s_repaidSafeSlips() > 0) {
            stableAmount =
                (_safeSlipAmount * cbbStableBalance) /
                convertibleBondBox.s_repaidSafeSlips();
        }

        return (stableAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRedeemLendSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _lendSlipAmount
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
        //calculate lendSlips to safeSlips w/ initialPrice
        uint256 safeSlipsAmount = (_lendSlipAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.stableDecimals();

        return _safeSlipRedeemUnwrapWithFees(_IBOBox, safeSlipsAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRedeemSafeSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _safeSlipAmount
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
        return _safeSlipRedeemUnwrapWithFees(_IBOBox, _safeSlipAmount);
    }

    function _safeSlipRedeemUnwrapWithFees(
        IIBOBox _IBOBox,
        uint256 _safeSlipAmount
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
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 feeSlip = (_safeSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        (
            uint256 underlyingAmount,
            uint256 buttonAmount
        ) = _safeSlipRedeemUnwrap(_IBOBox, _safeSlipAmount - feeSlip);

        (uint256 underlyingFee, uint256 buttonFee) = _safeSlipRedeemUnwrap(
            _IBOBox,
            feeSlip
        );

        return (underlyingAmount, buttonAmount, underlyingFee, buttonFee);
    }

    function _safeSlipRedeemUnwrap(IIBOBox _IBOBox, uint256 _safeSlipAmount)
        internal
        view
        returns (uint256, uint256)
    {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //safeSlips = safeTranches
        //calculate safe tranches to rebasing collateral via balance of safeTranche address
        uint256 buttonAmount = (wrapper.balanceOf(
            address(_IBOBox.safeTranche())
        ) * _safeSlipAmount) / _IBOBox.safeTranche().totalSupply();

        //calculate penalty riskTranche
        uint256 penaltyTrancheTotal = _IBOBox.riskTranche().balanceOf(
            address(convertibleBondBox)
        ) - IERC20(_IBOBox.riskSlipAddress()).totalSupply();

        uint256 penaltyTrancheRedeemable = (_safeSlipAmount *
            penaltyTrancheTotal) /
            (IERC20(_IBOBox.safeSlipAddress()).totalSupply() -
                convertibleBondBox.s_repaidSafeSlips());

        //calculate rebasing collateral redeemable for riskTranche penalty
        //total the rebasing collateral
        buttonAmount +=
            (wrapper.balanceOf(address(_IBOBox.riskTranche())) *
                penaltyTrancheRedeemable) /
            _IBOBox.riskTranche().totalSupply();

        //convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRedeemRiskSlipsForTranches(
        IIBOBox _IBOBox,
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
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        //subtract fees
        uint256 feeSlip = (_riskSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        (
            uint256 underlyingAmount,
            uint256 buttonAmount
        ) = _redeemRiskSlipForTranches(_IBOBox, _riskSlipAmount - feeSlip);
        (uint256 underlyingFee, uint256 buttonFee) = _redeemRiskSlipForTranches(
            _IBOBox,
            feeSlip
        );

        return (underlyingAmount, buttonAmount, underlyingFee, buttonFee);
    }

    function _redeemRiskSlipForTranches(
        IIBOBox _IBOBox,
        uint256 _riskSlipAmount
    ) internal view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //calculate riskSlip to riskTranche - penalty
        uint256 riskTrancheAmount = _riskSlipAmount -
            (_riskSlipAmount * convertibleBondBox.penalty()) /
            convertibleBondBox.s_penaltyGranularity();

        //calculate rebasing collateral redeemable for riskTranche - penalty via tranche balance
        uint256 buttonAmount = (wrapper.balanceOf(
            address(_IBOBox.riskTranche())
        ) * riskTrancheAmount) / _IBOBox.riskTranche().totalSupply();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, buttonAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRepayAndUnwrapSimple(IIBOBox _IBOBox, uint256 _stableAmount)
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

        ) = fetchElasticStack(_IBOBox);

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
        uint256 buttonAmount = 0;
        if (bond.totalDebt() > 0) {
            buttonAmount =
                (safeTranchePayout *
                    convertibleBondBox.s_trancheGranularity() *
                    collateralBalance) /
                convertibleBondBox.safeRatio() /
                bond.totalDebt();
        }

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, _stableAmount, stableFees, riskTranchePayout);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRepayMaxAndUnwrapSimple(
        IIBOBox _IBOBox,
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

        ) = fetchElasticStack(_IBOBox);

        //riskTranche payout = riskSlipAmount
        uint256 riskTranchePayout = _riskSlipAmount;
        uint256 safeTranchePayout = (riskTranchePayout * _IBOBox.safeRatio()) /
            _IBOBox.riskRatio();

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
        uint256 buttonAmount = 0;

        if (bond.totalDebt() > 0) {
            buttonAmount =
                (safeTranchePayout *
                    convertibleBondBox.s_trancheGranularity() *
                    collateralBalance) /
                convertibleBondBox.safeRatio() /
                bond.totalDebt();
        }

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, stablesOwed, stableFees, riskTranchePayout);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRepayAndUnwrapMature(IIBOBox _IBOBox, uint256 _stableAmount)
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

        ) = fetchElasticStack(_IBOBox);

        //calculate fees
        uint256 stableFees = (_stableAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //calculate tranches
        uint256 safeTranchepayout = (_stableAmount *
            convertibleBondBox.trancheDecimals()) /
            convertibleBondBox.stableDecimals();

        uint256 riskTranchePayout = (safeTranchepayout * _IBOBox.riskRatio()) /
            _IBOBox.safeRatio();

        //get collateral balance for safeTranche rebasing collateral output
        uint256 collateralBalanceSafe = wrapper.balanceOf(
            address(_IBOBox.safeTranche())
        );
        uint256 buttonAmount = (safeTranchepayout * collateralBalanceSafe) /
            convertibleBondBox.safeTranche().totalSupply();

        //get collateral balance for riskTranche rebasing collateral output
        uint256 collateralBalanceRisk = wrapper.balanceOf(
            address(_IBOBox.riskTranche())
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
     * @inheritdoc IIBOBoxLens
     */
    function viewRepayMaxAndUnwrapMature(
        IIBOBox _IBOBox,
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

        ) = fetchElasticStack(_IBOBox);

        //Calculate tranches
        //riskTranche payout = riskSlipAmount
        uint256 safeTranchePayout = (_riskSlipAmount * _IBOBox.safeRatio()) /
            _IBOBox.riskRatio();

        uint256 stablesOwed = (safeTranchePayout * _IBOBox.stableDecimals()) /
            _IBOBox.trancheDecimals();

        //calculate stable Fees
        uint256 stableFees = (stablesOwed * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //get collateral balance for safeTranche rebasing collateral output
        uint256 buttonAmount = (safeTranchePayout *
            wrapper.balanceOf(address(_IBOBox.safeTranche()))) /
            convertibleBondBox.safeTranche().totalSupply();

        //get collateral balance for riskTranche rebasing collateral output
        uint256 collateralBalanceRisk = wrapper.balanceOf(
            address(_IBOBox.riskTranche())
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
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemBorrowSlip(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        uint256 userBorrowSlip = _IBOBox.borrowSlip().balanceOf(_account);
        return Math.min(userBorrowSlip, _IBOBox.s_activateLendAmount());
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemLendSlipForSafeSlip(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userLendSlip = _IBOBox.lendSlip().balanceOf(_account);
        uint256 IBO_safeSlips = convertibleBondBox.safeSlip().balanceOf(
            address(_IBOBox)
        );

        uint256 maxRedeemableLendSlips = (IBO_safeSlips *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        return Math.min(userLendSlip, maxRedeemableLendSlips);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemLendSlipForStables(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userLendSlip = _IBOBox.lendSlip().balanceOf(_account);

        uint256 IBO_safeSlips = convertibleBondBox.safeSlip().balanceOf(
            address(_IBOBox)
        );

        uint256 maxRedeemableLendSlips = (Math.min(
            IBO_safeSlips,
            convertibleBondBox.s_repaidSafeSlips()
        ) *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        return Math.min(userLendSlip, maxRedeemableLendSlips);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemSafeSlipForStables(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userSafeSlip = convertibleBondBox.safeSlip().balanceOf(
            _account
        );

        return Math.min(userSafeSlip, convertibleBondBox.s_repaidSafeSlips());
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxWithdrawLendSlips(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 userLendSlip = _IBOBox.lendSlip().balanceOf(_account);

        uint256 maxWithdrawableLendSlips = userLendSlip;

        if (convertibleBondBox.s_startDate() > 0) {
            uint256 withdrawableStables = _IBOBox.stableToken().balanceOf(
                address(_IBOBox)
            ) - _IBOBox.s_activateLendAmount();

            maxWithdrawableLendSlips = Math.min(
                userLendSlip,
                withdrawableStables
            );
        }

        return maxWithdrawableLendSlips;
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxWithdrawBorrowSlips(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 userBorrowSlip = _IBOBox.borrowSlip().balanceOf(_account);

        uint256 maxWithdrawableBorrowSlip = userBorrowSlip;

        if (convertibleBondBox.s_startDate() > 0) {
            uint256 withdrawableSafeTranche = _IBOBox.safeTranche().balanceOf(
                address(_IBOBox)
            );

            uint256 withdrawableSafeTrancheToBorrowSlip = (withdrawableSafeTranche *
                    _IBOBox.initialPrice() *
                    _IBOBox.stableDecimals()) /
                    _IBOBox.priceGranularity() /
                    _IBOBox.trancheDecimals();

            maxWithdrawableBorrowSlip = Math.min(
                userBorrowSlip,
                withdrawableSafeTrancheToBorrowSlip
            );
        }

        return maxWithdrawableBorrowSlip;
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemSafeSlipForTranches(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userSafeSlip = convertibleBondBox.safeSlip().balanceOf(
            _account
        );

        uint256 cbbSafeTrancheBalance = convertibleBondBox
            .safeTranche()
            .balanceOf(address(convertibleBondBox));

        return Math.min(userSafeSlip, cbbSafeTrancheBalance);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemLendSlipForTranches(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userLendSlip = _IBOBox.lendSlip().balanceOf(_account);

        uint256 cbbSafeTrancheBalance = convertibleBondBox
            .safeTranche()
            .balanceOf(address(convertibleBondBox));

        uint256 cbbSafeTrancheToLendSlip = (cbbSafeTrancheBalance *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        return Math.min(userLendSlip, cbbSafeTrancheToLendSlip);
    }

    function fetchElasticStack(IIBOBox _IBOBox)
        internal
        view
        returns (
            IConvertibleBondBox,
            IBondController,
            IButtonToken,
            IERC20
        )
    {
        IConvertibleBondBox convertibleBondBox = _IBOBox.convertibleBondBox();
        IBondController bond = convertibleBondBox.bond();
        IButtonToken wrapper = IButtonToken(bond.collateralToken());
        IERC20 underlying = IERC20(wrapper.underlying());

        return (convertibleBondBox, bond, wrapper, underlying);
    }
}
