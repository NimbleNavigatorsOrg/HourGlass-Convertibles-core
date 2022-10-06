// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IIBOLoanRouter.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/IBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/button-wrappers/contracts/interfaces/IButtonToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console2.sol";

contract IBOLoanRouter is IIBOLoanRouter {
    /**
     * @inheritdoc IIBOLoanRouter
     */
    function simpleWrapTrancheBorrow(
        IIBOBox _IBOBox,
        uint256 _amountRaw,
        uint256 _minIssueOrders
    ) public {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,
            IERC20 underlying
        ) = fetchElasticStack(_IBOBox);

        TransferHelper.safeTransferFrom(
            address(underlying),
            msg.sender,
            address(this),
            _amountRaw
        );

        if (
            underlying.allowance(address(this), address(wrapper)) < _amountRaw
        ) {
            underlying.approve(address(wrapper), type(uint256).max);
        }
        uint256 wrapperAmount = wrapper.deposit(_amountRaw);

        wrapper.approve(address(bond), type(uint256).max);
        bond.deposit(wrapperAmount);

        uint256 riskTrancheBalance = _IBOBox.riskTranche().balanceOf(
            address(this)
        );
        uint256 safeTrancheBalance = _IBOBox.safeTranche().balanceOf(
            address(this)
        );

        if (
            _IBOBox.safeTranche().allowance(address(this), address(_IBOBox)) <
            safeTrancheBalance
        ) {
            _IBOBox.safeTranche().approve(address(_IBOBox), type(uint256).max);
        }

        if (
            _IBOBox.riskTranche().allowance(address(this), address(_IBOBox)) <
            riskTrancheBalance
        ) {
            _IBOBox.riskTranche().approve(address(_IBOBox), type(uint256).max);
        }

        uint256 borrowAmount = (Math.min(
            safeTrancheBalance,
            ((riskTrancheBalance * convertibleBondBox.safeRatio()) /
                convertibleBondBox.riskRatio())
        ) *
            _IBOBox.initialPrice() *
            _IBOBox.stableDecimals()) /
            _IBOBox.priceGranularity() /
            _IBOBox.trancheDecimals();

        _IBOBox.createIssueOrder(msg.sender, borrowAmount);

        if (borrowAmount < _minIssueOrders)
            revert SlippageExceeded({
                expectedAmount: borrowAmount,
                minAmount: _minIssueOrders
            });
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function multiWrapTrancheBorrow(
        IIBOBox _IBOBox,
        uint256 _amountRaw,
        uint256 _minIssueOrders
    ) external {
        simpleWrapTrancheBorrow(_IBOBox, _amountRaw, _minIssueOrders);

        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            ,

        ) = fetchElasticStack(_IBOBox);

        //send back unused tranches to msg.sender
        uint256 trancheCount = bond.trancheCount();
        uint256 trancheIndex = convertibleBondBox.trancheIndex();
        for (uint256 i = 0; i < trancheCount; ) {
            if (i != trancheIndex && i != trancheCount - 1) {
                (ITranche tranche, ) = bond.tranches(i);
                tranche.transfer(msg.sender, tranche.balanceOf(address(this)));
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function simpleCancelIssueUnwrap(IIBOBox _IBOBox, uint256 _issueOrderAmount)
        external
    {
        //transfer issueOrders
        _IBOBox.issueOrder().transferFrom(
            msg.sender,
            address(this),
            _issueOrderAmount
        );

        //approve issueOrders for IBOBox
        if (
            _IBOBox.issueOrder().allowance(address(this), address(_IBOBox)) <
            _issueOrderAmount
        ) {
            _IBOBox.issueOrder().approve(address(_IBOBox), type(uint256).max);
        }

        //cancel issueOrders for tranches
        _IBOBox.cancelIssue(_issueOrderAmount);

        //redeem tranches with underlying bond & mature
        _redeemTrancheImmatureUnwrap(_IBOBox);
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function executeBuyOrdersRedeemStables(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
    ) external {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        _IBOBox.buyOrder().transferFrom(
            msg.sender,
            address(this),
            _buyOrderAmount
        );

        //redeem buyOrders for BondSlips
        _IBOBox.executeBuyOrder(_buyOrderAmount);

        //get balance of BondSlips and redeem for stables
        uint256 bondSlipAmount = IERC20(_IBOBox.bondSlipAddress()).balanceOf(
            address(this)
        );

        convertibleBondBox.redeemStable(bondSlipAmount);

        //get balance of stables and send back to user
        uint256 stableBalance = convertibleBondBox.stableToken().balanceOf(
            address(this)
        );

        TransferHelper.safeTransfer(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            stableBalance
        );
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function executeBuyOrdersRedeemTranchesAndUnwrap(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
    ) external {
        //Transfer lendslips to router
        _IBOBox.buyOrder().transferFrom(
            msg.sender,
            address(this),
            _buyOrderAmount
        );

        //redeem buyOrders for BondSlips
        _IBOBox.executeBuyOrder(_buyOrderAmount);

        //redeem BondSlips for SafeTranche
        uint256 bondSlipAmount = IERC20(_IBOBox.bondSlipAddress()).balanceOf(
            address(this)
        );

        _bondSlipsForTranchesUnwrap(_IBOBox, bondSlipAmount);
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function redeemBondSlipsForTranchesAndUnwrap(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
    ) external {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );
        //Transfer BondSlips to router
        convertibleBondBox.bondSlip().transferFrom(
            msg.sender,
            address(this),
            _bondSlipAmount
        );

        _bondSlipsForTranchesUnwrap(_IBOBox, _bondSlipAmount);
    }

    function _bondSlipsForTranchesUnwrap(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
    ) internal {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        convertibleBondBox.redeemSafeTranche(_bondSlipAmount);

        //redeem SafeTranche for underlying collateral
        uint256 safeTrancheAmount = convertibleBondBox.safeTranche().balanceOf(
            address(this)
        );
        bond.redeemMature(
            address(convertibleBondBox.safeTranche()),
            safeTrancheAmount
        );

        //redeem penalty riskTranche
        uint256 riskTrancheAmount = convertibleBondBox.riskTranche().balanceOf(
            address(this)
        );
        if (riskTrancheAmount > 0) {
            bond.redeemMature(
                address(convertibleBondBox.riskTranche()),
                riskTrancheAmount
            );
        }

        //unwrap to msg.sender
        wrapper.withdrawAllTo(msg.sender);
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function redeemDebtSlipsForTranchesAndUnwrap(
        IIBOBox _IBOBox,
        uint256 _debtSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //Transfer debtSlips to router
        convertibleBondBox.debtSlip().transferFrom(
            msg.sender,
            address(this),
            _debtSlipAmount
        );

        //Redeem debtSlips for riskTranches
        convertibleBondBox.redeemRiskTranche(_debtSlipAmount);

        //redeem riskTranche for underlying collateral
        uint256 riskTrancheAmount = convertibleBondBox.riskTranche().balanceOf(
            address(this)
        );
        bond.redeemMature(
            address(convertibleBondBox.riskTranche()),
            riskTrancheAmount
        );

        //unwrap to msg.sender
        wrapper.withdrawAllTo(msg.sender);
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function repayAndUnwrapSimple(
        IIBOBox _IBOBox,
        uint256 _stableAmount,
        uint256 _stableFees,
        uint256 _debtSlipAmount
    ) external {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        //Transfer Stables to Router
        TransferHelper.safeTransferFrom(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            address(this),
            _stableAmount + _stableFees
        );

        //Calculate DebtSlips (minus fees) and transfer to router
        convertibleBondBox.debtSlip().transferFrom(
            msg.sender,
            address(this),
            _debtSlipAmount
        );

        //call repay function
        if (
            convertibleBondBox.stableToken().allowance(
                address(this),
                address(convertibleBondBox)
            ) < _stableAmount + _stableFees
        ) {
            SafeERC20.safeIncreaseAllowance(
                (convertibleBondBox.stableToken()),
                address(convertibleBondBox),
                type(uint256).max - _stableAmount - _stableFees
            );
        }
        convertibleBondBox.repay(_stableAmount);

        _redeemTrancheImmatureUnwrap(_IBOBox);

        //send unpaid debtSlip back

        convertibleBondBox.debtSlip().transfer(
            msg.sender,
            IERC20(_IBOBox.debtSlipAddress()).balanceOf(address(this))
        );
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function repayMaxAndUnwrapSimple(
        IIBOBox _IBOBox,
        uint256 _stableAmount,
        uint256 _stableFees,
        uint256 _debtSlipAmount
    ) external {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        //Transfer Stables + fees + slippage to Router
        TransferHelper.safeTransferFrom(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            address(this),
            _stableAmount + _stableFees
        );

        //Transfer risk slips to CBB
        convertibleBondBox.debtSlip().transferFrom(
            msg.sender,
            address(this),
            _debtSlipAmount
        );

        //call repayMax function
        if (
            convertibleBondBox.stableToken().allowance(
                address(this),
                address(convertibleBondBox)
            ) < _stableAmount + _stableFees
        ) {
            SafeERC20.safeIncreaseAllowance(
                (convertibleBondBox.stableToken()),
                address(convertibleBondBox),
                type(uint256).max - _stableAmount - _stableFees
            );
        }
        convertibleBondBox.repayMax(_debtSlipAmount);

        _redeemTrancheImmatureUnwrap(_IBOBox);

        //send unused stables back to msg.sender
        TransferHelper.safeTransfer(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            convertibleBondBox.stableToken().balanceOf(address(this))
        );
    }

    function _redeemTrancheImmatureUnwrap(IIBOBox _IBOBox) internal {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        uint256 safeRatio = convertibleBondBox.safeRatio();
        uint256 riskRatio = convertibleBondBox.riskRatio();

        uint256[] memory redeemAmounts = new uint256[](2);

        redeemAmounts[0] = convertibleBondBox.safeTranche().balanceOf(
            address(this)
        );
        redeemAmounts[1] = convertibleBondBox.riskTranche().balanceOf(
            address(this)
        );

        if (redeemAmounts[0] * riskRatio < redeemAmounts[1] * safeRatio) {
            redeemAmounts[1] = (redeemAmounts[0] * riskRatio) / safeRatio;
        } else {
            redeemAmounts[0] = (redeemAmounts[1] * safeRatio) / riskRatio;
        }

        redeemAmounts[0] -= redeemAmounts[0] % safeRatio;
        redeemAmounts[1] -= redeemAmounts[1] % riskRatio;

        bond.redeem(redeemAmounts);
        //unwrap rebasing collateral and send underlying to msg.sender
        wrapper.withdrawAllTo(msg.sender);
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function repayAndUnwrapMature(
        IIBOBox _IBOBox,
        uint256 _stableAmount,
        uint256 _stableFees,
        uint256 _debtSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //Transfer Stables to Router
        TransferHelper.safeTransferFrom(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            address(this),
            _stableAmount + _stableFees
        );

        //Transfer to router
        convertibleBondBox.debtSlip().transferFrom(
            msg.sender,
            address(this),
            _debtSlipAmount
        );

        //call repay function
        if (
            convertibleBondBox.stableToken().allowance(
                address(this),
                address(convertibleBondBox)
            ) < _stableAmount + _stableFees
        ) {
            SafeERC20.safeIncreaseAllowance(
                (convertibleBondBox.stableToken()),
                address(convertibleBondBox),
                type(uint256).max - _stableAmount - _stableFees
            );
        }
        convertibleBondBox.repay(_stableAmount);

        //call redeemMature on bond
        bond.redeemMature(
            address(convertibleBondBox.safeTranche()),
            convertibleBondBox.safeTranche().balanceOf(address(this))
        );

        bond.redeemMature(
            address(convertibleBondBox.riskTranche()),
            convertibleBondBox.riskTranche().balanceOf(address(this))
        );

        //unwrap rebasing collateral to msg.sender
        wrapper.withdrawAllTo(msg.sender);
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
