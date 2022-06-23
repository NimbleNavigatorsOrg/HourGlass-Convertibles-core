pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract WithdrawBorrow is SBSetup {

    function testTransfersSafeTrancheFromStagingBoxToMsgSender(uint256 price, uint256 _borrowSlipAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 sbSafeTrancheBalanceBeforeWithdraw = ITranche(s_deployedConvertibleBondBox.safeTranche()).balanceOf(address(s_deployedSB));
        uint256 msgSenderSafeTrancheBalanceBeforeWithdraw = ITranche(s_deployedConvertibleBondBox.safeTranche()).balanceOf(address(this));

        _borrowSlipAmount = bound(_borrowSlipAmount, 0, sbSafeTrancheBalanceBeforeWithdraw);

        s_deployedSB.withdrawBorrow(_borrowSlipAmount);

        uint256 sbSafeTrancheBalanceAfterWithdraw = ITranche(s_deployedConvertibleBondBox.safeTranche()).balanceOf(address(s_deployedSB));
        uint256 msgSenderSafeTrancheBalanceAfterWithdraw = ITranche(s_deployedConvertibleBondBox.safeTranche()).balanceOf(address(this));

        assertEq(sbSafeTrancheBalanceBeforeWithdraw - _borrowSlipAmount, sbSafeTrancheBalanceAfterWithdraw);
        assertEq(msgSenderSafeTrancheBalanceBeforeWithdraw, msgSenderSafeTrancheBalanceAfterWithdraw);
    }

    function testTransfersRiskTrancheFromStagingBoxToMsgSender(uint256 price, uint256 _borrowSlipAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 sbSafeTrancheBalanceBeforeWithdraw = ITranche(s_deployedConvertibleBondBox.safeTranche()).balanceOf(address(s_deployedSB));

        uint256 sbRiskTrancheBalanceBeforeWithdraw = ITranche(s_deployedConvertibleBondBox.riskTranche()).balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskTrancheBalanceBeforeWithdraw = ITranche(s_deployedConvertibleBondBox.riskTranche()).balanceOf(address(this));

        _borrowSlipAmount = bound(_borrowSlipAmount, 0, sbSafeTrancheBalanceBeforeWithdraw);

        uint256 riskTrancheAmount = (_borrowSlipAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

        s_deployedSB.withdrawBorrow(_borrowSlipAmount);

        uint256 sbRiskTrancheBalanceAfterWithdraw = ITranche(s_deployedConvertibleBondBox.riskTranche()).balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskTrancheBalanceAfterWithdraw = ITranche(s_deployedConvertibleBondBox.riskTranche()).balanceOf(address(this));

        assertEq(sbRiskTrancheBalanceBeforeWithdraw - riskTrancheAmount, sbRiskTrancheBalanceAfterWithdraw);
        assertEq(msgSenderRiskTrancheBalanceBeforeWithdraw + riskTrancheAmount, msgSenderRiskTrancheBalanceAfterWithdraw);
    }

    function testEmitsBorrowWithdrawal(uint256 price, uint256 _borrowSlipAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 sbSafeTrancheBalanceBeforeWithdraw = ITranche(s_deployedConvertibleBondBox.safeTranche()).balanceOf(address(s_deployedSB));

        uint256 msgSenderBorrowSlipBalanceBeforeWithdraw = ISlip(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(address(this));

        _borrowSlipAmount = bound(_borrowSlipAmount, 0, sbSafeTrancheBalanceBeforeWithdraw);

        vm.expectEmit(true, true, true, true);
        emit BorrowWithdrawal(address(this), _borrowSlipAmount);
        s_deployedSB.withdrawBorrow(_borrowSlipAmount);
    } 
}