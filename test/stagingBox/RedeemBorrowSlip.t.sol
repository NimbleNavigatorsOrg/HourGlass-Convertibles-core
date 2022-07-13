pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";
import "../../src/interfaces/ISlip.sol";

contract RedeemBorrowSlip is SBIntegrationSetup {
    function redeemBorrowSetupMints() private {
        vm.startPrank(address(s_deployedConvertibleBondBox));
        s_deployedConvertibleBondBox.riskSlip().mint(
            address(s_deployedSB),
            type(uint256).max
        );
        vm.stopPrank();

        vm.startPrank(address(s_deployedSB));
        s_deployedSB.borrowSlip().mint(
            s_user,
            (s_maxMint / s_deployedSB.riskRatio()) * s_deployedSB.safeRatio()
        );
        vm.stopPrank();

        vm.startPrank(address(s_deployedSB));
        s_stableToken.mint(address(s_deployedSB), s_maxMint);
        vm.stopPrank();
    }

    function testRedeemBorrowSlipTransfersRiskSlipsFromStagingBoxToMsgSender(
        uint256 _fuzzPrice,
        uint256 _borrowSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        redeemBorrowSetupMints();

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = s_deployedSB
            .borrowSlip()
            .balanceOf(s_user);

        uint256 stagingBoxRiskSlipBalanceBeforeRedeem = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskSlipBalanceBeforeRedeem = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(s_user);

        _borrowSlipAmount = bound(
            _borrowSlipAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            msgSenderBorrowSlipBalanceBeforeRedeem
        );

        uint256 riskSlipTransferAmount = (_borrowSlipAmount *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.prank(s_user);
        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);

        uint256 stagingBoxRiskSlipBalanceAfterRedeem = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(address(s_deployedSB));
        uint256 msgSenderRiskSlipBalanceAfterRedeem = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(s_user);

        assertEq(
            stagingBoxRiskSlipBalanceBeforeRedeem - riskSlipTransferAmount,
            stagingBoxRiskSlipBalanceAfterRedeem
        );
        assertEq(
            msgSenderRiskSlipBalanceBeforeRedeem + riskSlipTransferAmount,
            msgSenderRiskSlipBalanceAfterRedeem
        );

        assertFalse(riskSlipTransferAmount == 0);
    }

    function testRedeemBorrowSlipTransfersStableTokensFromStagingBoxToMsgSender(
        uint256 _fuzzPrice,
        uint256 _borrowSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        redeemBorrowSetupMints();

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = s_deployedSB
            .borrowSlip()
            .balanceOf(s_user);

        uint256 stagingBoxStableTokenBalanceBeforeRedeem = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(address(s_deployedSB));
        uint256 msgSenderStableTokenBalanceBeforeRedeem = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(s_user);

        _borrowSlipAmount = bound(
            _borrowSlipAmount,
            s_deployedSB.priceGranularity(),
            msgSenderBorrowSlipBalanceBeforeRedeem
        );

        uint256 stableTokenTransferAmount = (_borrowSlipAmount *
            s_deployedSB.initialPrice()) / s_deployedSB.priceGranularity();

        vm.prank(s_user);
        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);

        uint256 stagingBoxStableTokenBalanceAfterRedeem = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(address(s_deployedSB));
        uint256 msgSenderStableTokenBalanceAfterRedeem = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(s_user);

        assertEq(
            stagingBoxStableTokenBalanceBeforeRedeem -
                stableTokenTransferAmount,
            stagingBoxStableTokenBalanceAfterRedeem
        );
        assertEq(
            msgSenderStableTokenBalanceBeforeRedeem + stableTokenTransferAmount,
            msgSenderStableTokenBalanceAfterRedeem
        );

        assertFalse(stableTokenTransferAmount == 0);
    }

    function testRedeemBorrowBurnsMsgSenderBorrowSlips(
        uint256 _fuzzPrice,
        uint256 _borrowSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        redeemBorrowSetupMints();

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = s_deployedSB
            .borrowSlip()
            .balanceOf(s_user);

        _borrowSlipAmount = bound(
            _borrowSlipAmount,
            1,
            msgSenderBorrowSlipBalanceBeforeRedeem
        );

        vm.prank(s_user);
        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);

        uint256 msgSenderBorrowSlipBalanceAfterRedeem = s_deployedSB
            .borrowSlip()
            .balanceOf(s_user);

        assertEq(
            msgSenderBorrowSlipBalanceBeforeRedeem - _borrowSlipAmount,
            msgSenderBorrowSlipBalanceAfterRedeem
        );

        assertFalse(_borrowSlipAmount == 0);
    }

    function testRedeemBorrowEmitsRedeemBorrowSlip(
        uint256 _fuzzPrice,
        uint256 _borrowSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        redeemBorrowSetupMints();

        uint256 msgSenderBorrowSlipBalanceBeforeRedeem = s_deployedSB
            .borrowSlip()
            .balanceOf(s_user);

        _borrowSlipAmount = bound(
            _borrowSlipAmount,
            1,
            msgSenderBorrowSlipBalanceBeforeRedeem
        );

        vm.prank(s_user);
        vm.expectEmit(true, true, true, true);
        emit RedeemBorrowSlip(s_user, _borrowSlipAmount);
        s_deployedSB.redeemBorrowSlip(_borrowSlipAmount);

        assertFalse(_borrowSlipAmount == 0);
    }
}
