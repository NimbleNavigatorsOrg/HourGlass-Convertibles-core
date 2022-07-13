pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";

contract WithdrawBorrow is SBIntegrationSetup {
    function WithdrawBorrowMints() private {
        vm.startPrank(address(s_buttonWoodBondController));
        s_safeTranche.mint(
            address(s_deployedSB),
            (s_maxMint / s_deployedSB.riskRatio()) * s_deployedSB.safeRatio()
        );
        vm.stopPrank();

        vm.startPrank(address(s_buttonWoodBondController));
        s_riskTranche.mint(address(s_deployedSB), s_maxMint);
        vm.stopPrank();

        vm.startPrank(address(s_deployedSB));
        s_deployedSB.borrowSlip().mint(s_user, s_maxMint);
        vm.stopPrank();
    }

    function testTransfersSafeTrancheFromStagingBoxToMsgSender(
        uint256 _fuzzPrice,
        uint256 _borrowSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        WithdrawBorrowMints();

        uint256 sbSafeTrancheBalanceBeforeWithdraw = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(address(s_deployedSB));
        uint256 msgSenderSafeTrancheBalanceBeforeWithdraw = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(s_user);

        _borrowSlipAmount = bound(
            _borrowSlipAmount,
            1,
            sbSafeTrancheBalanceBeforeWithdraw
        );

        vm.prank(s_user);
        s_deployedSB.withdrawBorrow(_borrowSlipAmount);

        uint256 sbSafeTrancheBalanceAfterWithdraw = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(address(s_deployedSB));
        uint256 msgSenderSafeTrancheBalanceAfterWithdraw = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(s_user);

        assertEq(
            sbSafeTrancheBalanceBeforeWithdraw - _borrowSlipAmount,
            sbSafeTrancheBalanceAfterWithdraw
        );
        assertEq(
            msgSenderSafeTrancheBalanceBeforeWithdraw + _borrowSlipAmount,
            msgSenderSafeTrancheBalanceAfterWithdraw
        );
        assertFalse(_borrowSlipAmount == 0);
    }

    function testTransfersRiskTrancheFromStagingBoxToMsgSender(
        uint256 _fuzzPrice,
        uint256 _borrowSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        WithdrawBorrowMints();

        uint256 sbSafeTrancheBalanceBeforeWithdraw = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(address(s_deployedSB));

        uint256 sbRiskTrancheBalanceBeforeWithdraw = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskTrancheBalanceBeforeWithdraw = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(s_user);

        _borrowSlipAmount = bound(
            _borrowSlipAmount,
            1,
            sbSafeTrancheBalanceBeforeWithdraw
        );

        uint256 riskTrancheAmount = (_borrowSlipAmount *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.prank(s_user);
        s_deployedSB.withdrawBorrow(_borrowSlipAmount);

        uint256 sbRiskTrancheBalanceAfterWithdraw = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskTrancheBalanceAfterWithdraw = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(s_user);

        assertEq(
            sbRiskTrancheBalanceBeforeWithdraw - riskTrancheAmount,
            sbRiskTrancheBalanceAfterWithdraw
        );
        assertEq(
            msgSenderRiskTrancheBalanceBeforeWithdraw + riskTrancheAmount,
            msgSenderRiskTrancheBalanceAfterWithdraw
        );
        assertFalse(riskTrancheAmount == 0);
    }

    function testEmitsBorrowWithdrawal(
        uint256 _fuzzPrice,
        uint256 _borrowSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        WithdrawBorrowMints();

        uint256 sbSafeTrancheBalanceBeforeWithdraw = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(address(s_deployedSB));

        _borrowSlipAmount = bound(
            _borrowSlipAmount,
            1,
            sbSafeTrancheBalanceBeforeWithdraw
        );

        vm.prank(s_user);
        vm.expectEmit(true, true, true, true);
        emit BorrowWithdrawal(s_user, _borrowSlipAmount);
        s_deployedSB.withdrawBorrow(_borrowSlipAmount);

        assertFalse(_borrowSlipAmount == 0);
    }
}
