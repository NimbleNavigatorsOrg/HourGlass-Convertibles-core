// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract RedeemRiskTranche is CBBSetup {
    struct BeforeBalances {
        uint256 borrowerIssuerSlip;
        uint256 borrowerRiskTranche;
        uint256 ownerIssuerSlip;
        uint256 CBBRiskTranche;
    }

    struct RedeemAmounts {
        uint256 feeSlip;
        uint256 issuerSlipAmount;
        uint256 riskTranchePayout;
    }

    address s_borrowerAddress = address(1);
    address s_lenderAddress = address(2);

    function testCannotRedeemRiskTrancheBondNotMatureYet(
        uint256 time,
        uint256 issuerSlipAmount
    ) public {
        time = bound(time, 0, s_maturityDate - 1);

        vm.warp(time);
        bytes memory customError = abi.encodeWithSignature(
            "BondNotMatureYet(uint256,uint256)",
            s_maturityDate,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemRiskTranche(issuerSlipAmount);
    }

    function testCannotRedeemRiskTrancheMinimumInput(
        uint256 time,
        uint256 issuerSlipAmount
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        issuerSlipAmount = bound(issuerSlipAmount, 0, 1e6 - 1);
        vm.warp(time);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            issuerSlipAmount,
            1e6
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemRiskTranche(issuerSlipAmount);
    }

    function testRedeemRiskTranche(
        uint256 time,
        uint256 depositAmount,
        uint256 issuerSlipAmountToRedeem,
        uint256 fee
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);

        depositAmount = bound(
            depositAmount,
            1e6,
            s_safeTranche.balanceOf(address(this))
        );
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        s_deployedConvertibleBondBox.borrow(
            s_borrowerAddress,
            s_lenderAddress,
            depositAmount
        );

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.setFee(fee);

        vm.warp(time);

        BeforeBalances memory before = BeforeBalances(
            s_issuerSlip.balanceOf(s_borrowerAddress),
            s_riskTranche.balanceOf(s_borrowerAddress),
            s_issuerSlip.balanceOf(s_cbb_owner),
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        issuerSlipAmountToRedeem = bound(
            issuerSlipAmountToRedeem,
            1e6,
            before.borrowerIssuerSlip
        );

        uint256 feeSlip = (issuerSlipAmountToRedeem * fee) / s_BPS;

        RedeemAmounts memory adjustments = RedeemAmounts(
            feeSlip,
            issuerSlipAmountToRedeem,
            ((issuerSlipAmountToRedeem - feeSlip) *
                (s_penaltyGranularity - s_penalty)) / s_penaltyGranularity
        );

        vm.startPrank(s_borrowerAddress);
        s_issuerSlip.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit RedeemRiskTranche(
            s_borrowerAddress,
            adjustments.issuerSlipAmount - adjustments.feeSlip
        );
        s_deployedConvertibleBondBox.redeemRiskTranche(
            issuerSlipAmountToRedeem
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertEq(
            before.ownerIssuerSlip + adjustments.feeSlip,
            s_issuerSlip.balanceOf(s_cbb_owner)
        );

        assertEq(
            before.CBBRiskTranche - adjustments.riskTranchePayout,
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.borrowerRiskTranche + adjustments.riskTranchePayout,
            s_riskTranche.balanceOf(s_borrowerAddress)
        );

        assertEq(
            before.borrowerIssuerSlip - adjustments.issuerSlipAmount,
            s_issuerSlip.balanceOf(s_borrowerAddress)
        );
    }
}
