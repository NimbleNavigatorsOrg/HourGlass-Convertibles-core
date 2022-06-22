pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract RedeemBorrowSlip is SBSetup {

    function testRedeemBorrowSlipTransfersRiskSlipsFromStagingBoxToMsgSender(uint256 price, uint256 _borrowSlipAmount) public {
        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = IERC20(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(address(this));

        uint256 stagingBoxRiskSlipBalanceBeforeRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskSlipBalanceBeforeRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(this));

        _borrowSlipAmount = bound(_borrowSlipAmount, 0, msgSenderBorrowSlipBalanceBeforeRedeem);

        uint256 riskSlipTransferAmount = (_borrowSlipAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);

        uint256 stagingBoxRiskSlipBalanceAfterRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskSlipBalanceAfterRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(this));

        assertEq(stagingBoxRiskSlipBalanceBeforeRedeem - riskSlipTransferAmount, stagingBoxRiskSlipBalanceAfterRedeem);
        assertEq(msgSenderRiskSlipBalanceBeforeRedeem + riskSlipTransferAmount, msgSenderRiskSlipBalanceAfterRedeem);
    }

    function testRedeemBorrowSlipTransfersStableTokensFromStagingBoxToMsgSender(uint256 price, uint256 _borrowSlipAmount) public {
        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = IERC20(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(address(this));

        uint256 stagingBoxStableTokenBalanceBeforeRedeem = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderStableTokenBalanceBeforeRedeem = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

        _borrowSlipAmount = bound(_borrowSlipAmount, 0, msgSenderBorrowSlipBalanceBeforeRedeem);

        uint256 stableTokenTransferAmount = (_borrowSlipAmount * s_deployedSB.initialPrice()) / s_deployedSB.priceGranularity();

        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);

        uint256 stagingBoxStableTokenBalanceAfterRedeem = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderStableTokenBalanceAfterRedeem = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

        assertEq(stagingBoxStableTokenBalanceBeforeRedeem - stableTokenTransferAmount, stagingBoxStableTokenBalanceAfterRedeem);
        assertEq(msgSenderStableTokenBalanceBeforeRedeem + stableTokenTransferAmount, msgSenderStableTokenBalanceAfterRedeem);
    }

    function testRedeemBorrowBurnsMsgSenderBorrowSlips(uint256 price, uint256 _borrowSlipAmount) public {
        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = IERC20(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(address(this));

        uint256 msgSenderStableTokenBalanceBeforeRedeem = ICBBSlip(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(address(this));

        _borrowSlipAmount = bound(_borrowSlipAmount, 0, msgSenderBorrowSlipBalanceBeforeRedeem);

        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);

        uint256 msgSenderStableTokenBalanceAfterRedeem = ICBBSlip(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(address(this));

        assertEq(msgSenderStableTokenBalanceBeforeRedeem - _borrowSlipAmount, msgSenderStableTokenBalanceAfterRedeem);
    }

    function testRedeemBorrowEmitsRedeemBorrowSlip(uint256 price, uint256 _borrowSlipAmount) public {
        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = IERC20(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(address(this));

        _borrowSlipAmount = bound(_borrowSlipAmount, 0, msgSenderBorrowSlipBalanceBeforeRedeem);
        vm.expectEmit(true, true, true, true);
        emit RedeemBorrowSlip(address(this), _borrowSlipAmount);
        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);
    }
}