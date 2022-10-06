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

        //calculate safeTranche (issueOrder amount) amount with tranche ratio & CDR
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
        uint256 _issueOrderAmount
    ) public view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        uint256 safeTrancheAmount = (_issueOrderAmount *
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

    function viewWithdrawBuyOrder(IIBOBox _IBOBox, uint256 _buyOrderAmount)
        external
        view
        returns (uint256)
    {
        return _buyOrderAmount;
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewRedeemIssueOrderForDebtSlip(
        IIBOBox _IBOBox,
        uint256 _issueOrderAmount
    ) external view returns (uint256, uint256) {
        uint256 loanAmount = _issueOrderAmount;

        uint256 debtSlipAmount = (loanAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.riskRatio() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.safeRatio() /
            _IBOBox.stableDecimals();

        return (debtSlipAmount, loanAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewRedeemBuyOrderForBondSlip(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
    ) external view returns (uint256) {
        uint256 bondSlipAmount = (_buyOrderAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.stableDecimals();

        return (bondSlipAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewRedeemBuyOrdersForStables(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
    ) public view returns (uint256, uint256) {
        //calculate buyOrders to bondSlips w/ initialPrice
        uint256 bondSlipsAmount = (_buyOrderAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.stableDecimals();

        return _bondSlipsForStablesWithFees(_IBOBox, bondSlipsAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRedeemBondSlipsForStables(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
    ) public view returns (uint256, uint256) {
        return _bondSlipsForStablesWithFees(_IBOBox, _bondSlipAmount);
    }

    function _bondSlipsForStablesWithFees(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
    ) internal view returns (uint256, uint256) {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 feeSlip = (_bondSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        uint256 stableAmount = _bondSlipsForStables(
            _IBOBox,
            _bondSlipAmount - feeSlip
        );
        uint256 feeAmount = _bondSlipsForStables(_IBOBox, feeSlip);

        return (stableAmount, feeAmount);
    }

    function _bondSlipsForStables(IIBOBox _IBOBox, uint256 _bondSlipAmount)
        internal
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 feeSlip = (_bondSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        //subtract fees
        _bondSlipAmount -= feeSlip;

        //calculate bondSlips to stables via math for CBB redeemStable
        uint256 cbbStableBalance = _IBOBox.stableToken().balanceOf(
            address(convertibleBondBox)
        );

        uint256 stableAmount = 0;

        if (convertibleBondBox.s_repaidBondSlips() > 0) {
            stableAmount =
                (_bondSlipAmount * cbbStableBalance) /
                convertibleBondBox.s_repaidBondSlips();
        }

        return (stableAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRedeemBuyOrdersForTranches(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
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
        //calculate buyOrders to bondSlips w/ initialPrice
        uint256 bondSlipsAmount = (_buyOrderAmount *
            _IBOBox.priceGranularity() *
            _IBOBox.trancheDecimals()) /
            _IBOBox.initialPrice() /
            _IBOBox.stableDecimals();

        return _bondSlipRedeemUnwrapWithFees(_IBOBox, bondSlipsAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */
    function viewRedeemBondSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
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
        return _bondSlipRedeemUnwrapWithFees(_IBOBox, _bondSlipAmount);
    }

    function _bondSlipRedeemUnwrapWithFees(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
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

        uint256 feeSlip = (_bondSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        (
            uint256 underlyingAmount,
            uint256 buttonAmount
        ) = _bondSlipRedeemUnwrap(_IBOBox, _bondSlipAmount - feeSlip);

        (uint256 underlyingFee, uint256 buttonFee) = _bondSlipRedeemUnwrap(
            _IBOBox,
            feeSlip
        );

        return (underlyingAmount, buttonAmount, underlyingFee, buttonFee);
    }

    function _bondSlipRedeemUnwrap(IIBOBox _IBOBox, uint256 _bondSlipAmount)
        internal
        view
        returns (uint256, uint256)
    {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //bondSlips = safeTranches
        //calculate safe tranches to rebasing collateral via balance of safeTranche address
        uint256 buttonAmount = (wrapper.balanceOf(
            address(_IBOBox.safeTranche())
        ) * _bondSlipAmount) / _IBOBox.safeTranche().totalSupply();

        //calculate penalty riskTranche
        uint256 penaltyTrancheTotal = _IBOBox.riskTranche().balanceOf(
            address(convertibleBondBox)
        ) - IERC20(_IBOBox.debtSlipAddress()).totalSupply();

        uint256 penaltyTrancheRedeemable = (_bondSlipAmount *
            penaltyTrancheTotal) /
            (IERC20(_IBOBox.bondSlipAddress()).totalSupply() -
                convertibleBondBox.s_repaidBondSlips());

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
    function viewRedeemDebtSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _debtSlipAmount
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
        uint256 feeSlip = (_debtSlipAmount * convertibleBondBox.feeBps()) /
            convertibleBondBox.BPS();

        (
            uint256 underlyingAmount,
            uint256 buttonAmount
        ) = _redeemDebtSlipForTranches(_IBOBox, _debtSlipAmount - feeSlip);
        (uint256 underlyingFee, uint256 buttonFee) = _redeemDebtSlipForTranches(
            _IBOBox,
            feeSlip
        );

        return (underlyingAmount, buttonAmount, underlyingFee, buttonFee);
    }

    function _redeemDebtSlipForTranches(
        IIBOBox _IBOBox,
        uint256 _debtSlipAmount
    ) internal view returns (uint256, uint256) {
        (
            IConvertibleBondBox convertibleBondBox,
            ,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //calculate debtSlip to riskTranche - penalty
        uint256 riskTrancheAmount = _debtSlipAmount -
            (_debtSlipAmount * convertibleBondBox.penalty()) /
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
        uint256 _debtSlipAmount
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

        //riskTranche payout = debtSlipAmount
        uint256 riskTranchePayout = _debtSlipAmount;
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
        uint256 _debtSlipAmount
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
        //riskTranche payout = debtSlipAmount
        uint256 safeTranchePayout = (_debtSlipAmount * _IBOBox.safeRatio()) /
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
            (_debtSlipAmount * collateralBalanceRisk) /
            convertibleBondBox.riskTranche().totalSupply();

        // convert rebasing collateral to collateralToken qty via wrapper
        uint256 underlyingAmount = wrapper.wrapperToUnderlying(buttonAmount);

        // return both
        return (underlyingAmount, stablesOwed, stableFees, _debtSlipAmount);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemIssueOrder(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        uint256 userIssueOrder = _IBOBox.issueOrder().balanceOf(_account);
        return Math.min(userIssueOrder, _IBOBox.s_activateLendAmount());
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemBuyOrderForBondSlip(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userBuyOrder = _IBOBox.buyOrder().balanceOf(_account);
        uint256 IBO_bondSlips = convertibleBondBox.bondSlip().balanceOf(
            address(_IBOBox)
        );

        uint256 maxRedeemableBuyOrders = (IBO_bondSlips *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        return Math.min(userBuyOrder, maxRedeemableBuyOrders);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemBuyOrderForStables(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userBuyOrder = _IBOBox.buyOrder().balanceOf(_account);

        uint256 IBO_bondSlips = convertibleBondBox.bondSlip().balanceOf(
            address(_IBOBox)
        );

        uint256 maxRedeemableBuyOrders = (Math.min(
            IBO_bondSlips,
            convertibleBondBox.s_repaidBondSlips()
        ) *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        return Math.min(userBuyOrder, maxRedeemableBuyOrders);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemBondSlipForStables(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userBondSlip = convertibleBondBox.bondSlip().balanceOf(
            _account
        );

        return Math.min(userBondSlip, convertibleBondBox.s_repaidBondSlips());
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxWithdrawBuyOrders(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 userBuyOrder = _IBOBox.buyOrder().balanceOf(_account);

        uint256 maxWithdrawableBuyOrders = userBuyOrder;

        if (convertibleBondBox.s_startDate() > 0) {
            uint256 withdrawableStables = _IBOBox.stableToken().balanceOf(
                address(_IBOBox)
            ) - _IBOBox.s_activateLendAmount();

            maxWithdrawableBuyOrders = Math.min(
                userBuyOrder,
                withdrawableStables
            );
        }

        return maxWithdrawableBuyOrders;
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxWithdrawIssueOrders(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        uint256 userIssueOrder = _IBOBox.issueOrder().balanceOf(_account);

        uint256 maxWithdrawableIssueOrder = userIssueOrder;

        if (convertibleBondBox.s_startDate() > 0) {
            uint256 withdrawableSafeTranche = _IBOBox.safeTranche().balanceOf(
                address(_IBOBox)
            );

            uint256 withdrawableSafeTrancheToIssueOrder = (withdrawableSafeTranche *
                    _IBOBox.initialPrice() *
                    _IBOBox.stableDecimals()) /
                    _IBOBox.priceGranularity() /
                    _IBOBox.trancheDecimals();

            maxWithdrawableIssueOrder = Math.min(
                userIssueOrder,
                withdrawableSafeTrancheToIssueOrder
            );
        }

        return maxWithdrawableIssueOrder;
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemBondSlipForTranches(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userBondSlip = convertibleBondBox.bondSlip().balanceOf(
            _account
        );

        uint256 cbbSafeTrancheBalance = convertibleBondBox
            .safeTranche()
            .balanceOf(address(convertibleBondBox));

        return Math.min(userBondSlip, cbbSafeTrancheBalance);
    }

    /**
     * @inheritdoc IIBOBoxLens
     */

    function viewMaxRedeemBuyOrderForTranches(IIBOBox _IBOBox, address _account)
        public
        view
        returns (uint256)
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        uint256 userBuyOrder = _IBOBox.buyOrder().balanceOf(_account);

        uint256 cbbSafeTrancheBalance = convertibleBondBox
            .safeTranche()
            .balanceOf(address(convertibleBondBox));

        uint256 cbbSafeTrancheToBuyOrder = (cbbSafeTrancheBalance *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        return Math.min(userBuyOrder, cbbSafeTrancheToBuyOrder);
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
