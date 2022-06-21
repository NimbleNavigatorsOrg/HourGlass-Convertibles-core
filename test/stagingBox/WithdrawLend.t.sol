pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract WithdrawLend is SBSetup {

    function testWithdrawLendTransfersStableTokensFromStagingBoxToMsgSender(uint256 price, uint256 _lendSlipAmount) public {
        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 sbStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

        _lendSlipAmount = bound(_lendSlipAmount, 0, sbStableTokenBalanceBeforeWithdraw);

        s_deployedSB.withdrawLend(_lendSlipAmount);

        uint256 sbStableTokenBalanceAfterWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderStableTokenBalanceAfterWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

        assertEq(msgSenderStableTokenBalanceBeforeWithdraw + _lendSlipAmount, msgSenderStableTokenBalanceAfterWithdraw);
    }

    function testWithdrawLendBurnsMsgSenderLenderSlips(uint256 price, uint256 _lendSlipAmount) public {
        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 sbStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderLendSlipBalanceBeforeWithdraw  = IERC20(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(this));

        _lendSlipAmount = bound(_lendSlipAmount, 0, sbStableTokenBalanceBeforeWithdraw);

        s_deployedSB.withdrawLend(_lendSlipAmount);

        uint256 msgSenderLendSlipBalanceAfterWithdraw  = IERC20(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(this));

        assertEq(msgSenderLendSlipBalanceBeforeWithdraw - _lendSlipAmount, msgSenderLendSlipBalanceAfterWithdraw);
    }

    function testWithdrawLendEmitsLendWithdraw(uint256 price, uint256 _lendSlipAmount) public {
        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 sbStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderLendSlipBalanceBeforeWithdraw  = IERC20(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(this));

        _lendSlipAmount = bound(_lendSlipAmount, 0, sbStableTokenBalanceBeforeWithdraw);

        vm.expectEmit(true, true, true, true);
        emit LendWithdrawal(address(this), _lendSlipAmount);
        s_deployedSB.withdrawLend(_lendSlipAmount);
    }
}