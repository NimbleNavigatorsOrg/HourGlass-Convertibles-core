pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract RedeemLendSlip is SBSetup {

    function testRedeemLendSlipTransfersSafeSlipFromStagingBoxToMsgSender(uint256 price, uint256 _lendSlipAmount) public {

        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 msgSenderLendSlipBalanceBeforeRedeem = ICBBSlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(this));
        uint256 msgSenderSafeSlipBalanceBeforeRedeem = ICBBSlip(s_deployedSB.safeSlipAddress()).balanceOf(address(this));
        uint256 stagingBoxSafeSlipBalanceBeforeRedeem = ICBBSlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedSB));

        _lendSlipAmount = bound(_lendSlipAmount, 0, msgSenderLendSlipBalanceBeforeRedeem);

        uint256 lendSlipTransferAmount = (_lendSlipAmount * s_deployedSB.priceGranularity()) / s_deployedSB.initialPrice();

        s_deployedSB.redeemLendSlip(_lendSlipAmount);

        uint256 msgSenderSafeSlipBalanceAfterRedeem = ICBBSlip(s_deployedSB.safeSlipAddress()).balanceOf(address(this));
        uint256 stagingBoxSafeSlipBalanceAfterRedeem = ICBBSlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedSB));

        assertEq(msgSenderSafeSlipBalanceBeforeRedeem + lendSlipTransferAmount, msgSenderSafeSlipBalanceAfterRedeem);
        assertEq(stagingBoxSafeSlipBalanceBeforeRedeem - lendSlipTransferAmount, stagingBoxSafeSlipBalanceAfterRedeem);
    }

    function testRedeemLendBurnsMsgSenderLendSlip(uint256 price, uint256 _lendSlipAmount) public {

        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 msgSenderLendSlipBalanceBeforeRedeem = ICBBSlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(this));

        _lendSlipAmount = bound(_lendSlipAmount, 0, msgSenderLendSlipBalanceBeforeRedeem);

        s_deployedSB.redeemLendSlip(_lendSlipAmount);

        uint256 msgSenderSafeSlipBalanceAfterRedeem = ICBBSlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(this));

        assertEq(msgSenderLendSlipBalanceBeforeRedeem - _lendSlipAmount, msgSenderSafeSlipBalanceAfterRedeem);
    }

    function testRedeemLendEmits(uint256 price, uint256 _lendSlipAmount) public {

        price = bound(price, 0, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 msgSenderLendSlipBalanceBeforeRedeem = ICBBSlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(this));

        _lendSlipAmount = bound(_lendSlipAmount, 0, msgSenderLendSlipBalanceBeforeRedeem);

        vm.expectEmit(true, true, true, true);
        emit RedeemLendSlip(address(this), _lendSlipAmount);
        s_deployedSB.redeemLendSlip(_lendSlipAmount);
    }
}
