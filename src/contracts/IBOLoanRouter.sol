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
        uint256 _minBorrowSlips
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

        _IBOBox.depositBorrow(msg.sender, borrowAmount);

        if (borrowAmount < _minBorrowSlips)
            revert SlippageExceeded({
                expectedAmount: borrowAmount,
                minAmount: _minBorrowSlips
            });
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function multiWrapTrancheBorrow(
        IIBOBox _IBOBox,
        uint256 _amountRaw,
        uint256 _minBorrowSlips
    ) external {
        simpleWrapTrancheBorrow(_IBOBox, _amountRaw, _minBorrowSlips);

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
    function simpleWithdrawBorrowUnwrap(
        IIBOBox _IBOBox,
        uint256 _borrowSlipAmount
    ) external {
        //transfer borrowSlips
        _IBOBox.borrowSlip().transferFrom(
            msg.sender,
            address(this),
            _borrowSlipAmount
        );

        //approve borrowSlips for IBOBox
        if (
            _IBOBox.borrowSlip().allowance(address(this), address(_IBOBox)) <
            _borrowSlipAmount
        ) {
            _IBOBox.borrowSlip().approve(address(_IBOBox), type(uint256).max);
        }

        //withdraw borrowSlips for tranches
        _IBOBox.withdrawBorrow(_borrowSlipAmount);

        //redeem tranches with underlying bond & mature
        _redeemTrancheImmatureUnwrap(_IBOBox);
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function redeemBuyOrdersForStables(IIBOBox _IBOBox, uint256 _buyOrderAmount)
        external
    {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _IBOBox
        );

        _IBOBox.buyOrder().transferFrom(
            msg.sender,
            address(this),
            _buyOrderAmount
        );

        //redeem buyOrders for BondSlips
        _IBOBox.redeemBuyOrder(_buyOrderAmount);

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
    function redeemBuyOrdersForTranchesAndUnwrap(
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
        _IBOBox.redeemBuyOrder(_buyOrderAmount);

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
    function redeemIssuerSlipsForTranchesAndUnwrap(
        IIBOBox _IBOBox,
        uint256 _issuerSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_IBOBox);

        //Transfer issuerSlips to router
        convertibleBondBox.issuerSlip().transferFrom(
            msg.sender,
            address(this),
            _issuerSlipAmount
        );

        //Redeem issuerSlips for riskTranches
        convertibleBondBox.redeemRiskTranche(_issuerSlipAmount);

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
        uint256 _issuerSlipAmount
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

        //Calculate IssuerSlips (minus fees) and transfer to router
        convertibleBondBox.issuerSlip().transferFrom(
            msg.sender,
            address(this),
            _issuerSlipAmount
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

        //send unpaid issuerSlip back

        convertibleBondBox.issuerSlip().transfer(
            msg.sender,
            IERC20(_IBOBox.issuerSlipAddress()).balanceOf(address(this))
        );
    }

    /**
     * @inheritdoc IIBOLoanRouter
     */
    function repayMaxAndUnwrapSimple(
        IIBOBox _IBOBox,
        uint256 _stableAmount,
        uint256 _stableFees,
        uint256 _issuerSlipAmount
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
        convertibleBondBox.issuerSlip().transferFrom(
            msg.sender,
            address(this),
            _issuerSlipAmount
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
        convertibleBondBox.repayMax(_issuerSlipAmount);

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
        uint256 _issuerSlipAmount
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
        convertibleBondBox.issuerSlip().transferFrom(
            msg.sender,
            address(this),
            _issuerSlipAmount
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
