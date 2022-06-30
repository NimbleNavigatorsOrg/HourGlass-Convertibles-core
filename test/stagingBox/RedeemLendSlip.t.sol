pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";

contract RedeemLendSlip is SBIntegrationSetup {

    function redeemLendSlipMints() private {
        vm.startPrank(address(s_deployedSB));
        ISlip(s_deployedSB.s_lendSlipTokenAddress()).mint(s_user, s_maxMint);
        vm.stopPrank();

        vm.startPrank(address(s_deployedConvertibleBondBox));
        ISlip(s_deployedSB.safeSlipAddress()).mint(address(s_deployedSB), type(uint256).max);
        vm.stopPrank();
    }

    function testRedeemLendSlipTransfersSafeSlipFromStagingBoxToMsgSender(uint256 _fuzzPrice, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        redeemLendSlipMints();

        uint256 msgSenderLendSlipBalanceBeforeRedeem = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(s_user);
        uint256 msgSenderSafeSlipBalanceBeforeRedeem = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(s_user);
        uint256 stagingBoxSafeSlipBalanceBeforeRedeem = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedSB));

        _lendSlipAmount = bound(_lendSlipAmount, s_deployedSB.initialPrice(), msgSenderLendSlipBalanceBeforeRedeem);

        uint256 lendSlipTransferAmount = (_lendSlipAmount * s_deployedSB.priceGranularity()) / s_deployedSB.initialPrice();

        vm.prank(s_user);
        s_deployedSB.redeemLendSlip(_lendSlipAmount);

        uint256 msgSenderSafeSlipBalanceAfterRedeem = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(s_user);
        uint256 stagingBoxSafeSlipBalanceAfterRedeem = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedSB));

        assertEq(msgSenderSafeSlipBalanceBeforeRedeem + lendSlipTransferAmount, msgSenderSafeSlipBalanceAfterRedeem);
        assertEq(stagingBoxSafeSlipBalanceBeforeRedeem - lendSlipTransferAmount, stagingBoxSafeSlipBalanceAfterRedeem);
        assertFalse(lendSlipTransferAmount == 0);
    }

    function testRedeemLendSlipBurnsMsgSenderLendSlip(uint256 _fuzzPrice, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        redeemLendSlipMints();

        uint256 msgSenderLendSlipBalanceBeforeRedeem = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(s_user);

        _lendSlipAmount = bound(_lendSlipAmount, 1, msgSenderLendSlipBalanceBeforeRedeem);

        vm.prank(s_user);
        s_deployedSB.redeemLendSlip(_lendSlipAmount);

        uint256 msgSenderSafeSlipBalanceAfterRedeem = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(s_user);

        assertEq(msgSenderLendSlipBalanceBeforeRedeem - _lendSlipAmount, msgSenderSafeSlipBalanceAfterRedeem);
        assertFalse(_lendSlipAmount == 0);
    }

    function testRedeemLendSlipEmits(uint256 _fuzzPrice, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        redeemLendSlipMints();

        uint256 msgSenderLendSlipBalanceBeforeRedeem = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(s_user);

        _lendSlipAmount = bound(_lendSlipAmount, 1, msgSenderLendSlipBalanceBeforeRedeem);

        vm.prank(s_user);
        vm.expectEmit(true, true, true, true);
        emit RedeemLendSlip(s_user, _lendSlipAmount);
        s_deployedSB.redeemLendSlip(_lendSlipAmount);

        assertFalse(_lendSlipAmount == 0);
    }
}
