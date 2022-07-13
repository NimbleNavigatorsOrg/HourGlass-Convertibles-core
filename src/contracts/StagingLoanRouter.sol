// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IStagingLoanRouter.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "../interfaces/IButtonWoodBondController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/button-wrappers/contracts/interfaces/IButtonToken.sol";

contract StagingLoanRouter is IStagingLoanRouter {
    /**
     * @inheritdoc IStagingLoanRouter
     */

    function simpleWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw,
        uint256 _minBorrowSlips
    ) public {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,
            IERC20 underlying
        ) = fetchElasticStack(_stagingBox);

        TransferHelper.safeTransferFrom(
            address(underlying),
            msg.sender,
            address(this),
            _amountRaw
        );
        underlying.approve(address(wrapper), _amountRaw);
        uint256 wrapperAmount = wrapper.deposit(_amountRaw);

        wrapper.approve(address(bond), type(uint256).max);
        bond.deposit(wrapperAmount);

        uint256 riskTrancheBalance = _stagingBox.riskTranche().balanceOf(
            address(this)
        );
        uint256 safeTrancheBalance = _stagingBox.safeTranche().balanceOf(
            address(this)
        );

        _stagingBox.safeTranche().approve(
            address(_stagingBox),
            type(uint256).max
        );
        _stagingBox.riskTranche().approve(
            address(_stagingBox),
            type(uint256).max
        );

        _stagingBox.depositBorrow(
            msg.sender,
            min(
                safeTrancheBalance,
                ((riskTrancheBalance * convertibleBondBox.safeRatio()) /
                    convertibleBondBox.riskRatio())
            )
        );

        if (safeTrancheBalance < _minBorrowSlips)
            revert SlippageExceeded({
                expectedAmount: safeTrancheBalance,
                minAmount: _minBorrowSlips
            });
    }

    /**
     * @inheritdoc IStagingLoanRouter
     */

    function multiWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw,
        uint256 _minBorrowSlips
    ) external {
        simpleWrapTrancheBorrow(_stagingBox, _amountRaw, _minBorrowSlips);

        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            ,

        ) = fetchElasticStack(_stagingBox);

        //send back unused tranches to msg.sender
        for (uint256 i = 0; i < bond.trancheCount(); i++) {
            if (
                i != convertibleBondBox.trancheIndex() &&
                i != bond.trancheCount() - 1
            ) {
                (ITranche tranche, ) = bond.tranches(i);
                TransferHelper.safeTransfer(
                    address(tranche),
                    msg.sender,
                    tranche.balanceOf(address(this))
                );
            }
        }
    }

    /**
     * @inheritdoc IStagingLoanRouter
     */

    function redeemLendSlipsForStables(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) external {
        (IConvertibleBondBox convertibleBondBox, , , ) = fetchElasticStack(
            _stagingBox
        );

        //Transfer lendslips to router
        TransferHelper.safeTransferFrom(
            address(_stagingBox.lendSlip()),
            msg.sender,
            address(this),
            _lendSlipAmount
        );

        //redeem lendSlips for SafeSlips
        _stagingBox.redeemLendSlip(_lendSlipAmount);

        //get balance of SafeSlips and redeem for stables
        uint256 safeSlipAmount = IERC20(_stagingBox.safeSlipAddress())
            .balanceOf(address(this));

        convertibleBondBox.redeemStable(safeSlipAmount);

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
     * @inheritdoc IStagingLoanRouter
     */

    function redeemLendSlipsForTranchesAndUnwrap(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //Transfer lendslips to router
        TransferHelper.safeTransferFrom(
            address(_stagingBox.lendSlip()),
            msg.sender,
            address(this),
            _lendSlipAmount
        );

        //redeem lendSlips for SafeSlips
        _stagingBox.redeemLendSlip(_lendSlipAmount);

        //redeem SafeSlips for SafeTranche
        uint256 safeSlipAmount = IERC20(_stagingBox.safeSlipAddress())
            .balanceOf(address(this));

        convertibleBondBox.redeemSafeTranche(safeSlipAmount);

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
     * @inheritdoc IStagingLoanRouter
     */

    function redeemRiskSlipsForTranchesAndUnwrap(
        IStagingBox _stagingBox,
        uint256 _riskSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //Transfer riskSlips to router
        TransferHelper.safeTransferFrom(
            _stagingBox.riskSlipAddress(),
            msg.sender,
            address(this),
            _riskSlipAmount
        );

        //Redeem riskSlips for riskTranches
        convertibleBondBox.redeemRiskTranche(_riskSlipAmount);

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
     * @inheritdoc IStagingLoanRouter
     */

    function repayAndUnwrapSimple(
        IStagingBox _stagingBox,
        uint256 _stableAmount,
        uint256 _riskSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //Transfer Stables to Router
        TransferHelper.safeTransferFrom(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            address(this),
            _stableAmount
        );

        //Calculate RiskSlips (minus fees) and transfer to router
        TransferHelper.safeTransferFrom(
            _stagingBox.riskSlipAddress(),
            msg.sender,
            address(this),
            _riskSlipAmount
        );

        //call repay function
        convertibleBondBox.stableToken().approve(
            address(convertibleBondBox),
            _stableAmount
        );
        convertibleBondBox.repay(_stableAmount);

        //call redeem on bond (ratio concern?)
        uint256[] memory redeemAmounts = new uint256[](2);
        redeemAmounts[0] = (
            convertibleBondBox.safeTranche().balanceOf(address(this))
        );
        redeemAmounts[1] = ((redeemAmounts[0] *
            convertibleBondBox.riskRatio()) / convertibleBondBox.safeRatio());
        bond.redeem(redeemAmounts);

        //unwrap rebasing collateral to msg.sender
        wrapper.withdrawAllTo(msg.sender);

        //send unpaid riskSlip back
        TransferHelper.safeTransfer(
            _stagingBox.riskSlipAddress(),
            msg.sender,
            IERC20(_stagingBox.riskSlipAddress()).balanceOf(address(this))
        );
    }

    /**
     * @inheritdoc IStagingLoanRouter
     */

    function repayMaxAndUnwrapSimple(
        IStagingBox _stagingBox,
        uint256 _stableAmount,
        uint256 _riskSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //Transfer Stables + fees + slippage to Router
        TransferHelper.safeTransferFrom(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            address(this),
            _stableAmount
        );

        //Transfer risk slips to CBB
        TransferHelper.safeTransferFrom(
            _stagingBox.riskSlipAddress(),
            msg.sender,
            address(this),
            _riskSlipAmount
        );

        //call repayMax function
        convertibleBondBox.stableToken().approve(
            address(convertibleBondBox),
            _stableAmount
        );
        convertibleBondBox.repayMax(_riskSlipAmount);

        //call redeem on bond (ratio concern?)
        uint256[] memory redeemAmounts = new uint256[](2);
        redeemAmounts[0] = (
            convertibleBondBox.safeTranche().balanceOf(address(this))
        );
        redeemAmounts[1] = ((redeemAmounts[0] *
            convertibleBondBox.riskRatio()) / convertibleBondBox.safeRatio());
        bond.redeem(redeemAmounts);

        //unwrap rebasing collateral to msg.sender
        wrapper.withdrawAllTo(msg.sender);

        //send unused stables back to msg.sender
        TransferHelper.safeTransfer(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            convertibleBondBox.stableToken().balanceOf(address(this))
        );
    }

    /**
     * @inheritdoc IStagingLoanRouter
     */

    function repayAndUnwrapMature(
        IStagingBox _stagingBox,
        uint256 _stableAmount,
        uint256 _riskSlipAmount
    ) external {
        (
            IConvertibleBondBox convertibleBondBox,
            IButtonWoodBondController bond,
            IButtonToken wrapper,

        ) = fetchElasticStack(_stagingBox);

        //Transfer Stables to Router
        TransferHelper.safeTransferFrom(
            address(convertibleBondBox.stableToken()),
            msg.sender,
            address(this),
            _stableAmount
        );

        //Transfer to router
        TransferHelper.safeTransferFrom(
            _stagingBox.riskSlipAddress(),
            msg.sender,
            address(this),
            _riskSlipAmount
        );

        //call repay function
        convertibleBondBox.stableToken().approve(
            address(convertibleBondBox),
            _stableAmount
        );
        convertibleBondBox.repay(_stableAmount);

        //call redeemMature on bond
        bond.redeemMature(
            address(convertibleBondBox.safeTranche()),
            _stableAmount
        );
        bond.redeemMature(
            address(convertibleBondBox.riskTranche()),
            _riskSlipAmount
        );

        //unwrap rebasing collateral to msg.sender
        wrapper.withdrawAllTo(msg.sender);
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

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a <= b ? a : b;
    }
}
