// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract RedeemRiskTranche is CBBSetup {
    struct BeforeBalances {
        uint256 borrowerRiskSlip;
        uint256 borrowerRiskTranche;
        uint256 ownerRiskSlip;
        uint256 CBBRiskTranche;
    }

    struct RedeemAmounts {
        uint256 feeSlip;
        uint256 riskSlipAmount;
        uint256 riskTranchePayout;
    }

    address s_borrowerAddress = address(1);
    address s_lenderAddress = address(2);

    function testCannotRedeemRiskTrancheBondNotMatureYet(
        uint256 time,
        uint256 riskSlipAmount
    ) public {
        time = bound(time, 0, s_maturityDate - 1);

        vm.warp(time);
        bytes memory customError = abi.encodeWithSignature(
            "BondNotMatureYet(uint256,uint256)",
            s_maturityDate,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmount);
    }

    function testCannotRedeemRiskTrancheMinimumInput(
        uint256 time,
        uint256 riskSlipAmount
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        riskSlipAmount = bound(riskSlipAmount, 0, 1e6 - 1);
        vm.warp(time);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            riskSlipAmount,
            1e6
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmount);
    }

    function testRedeemRiskTranche(
        uint256 time,
        uint256 depositAmount,
        uint256 riskSlipAmountToRedeem,
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
            s_riskSlip.balanceOf(s_borrowerAddress),
            s_riskTranche.balanceOf(s_borrowerAddress),
            s_riskSlip.balanceOf(s_cbb_owner),
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        riskSlipAmountToRedeem = bound(
            riskSlipAmountToRedeem,
            1e6,
            before.borrowerRiskSlip
        );

        uint256 feeSlip = (riskSlipAmountToRedeem * fee) / s_BPS;

        RedeemAmounts memory adjustments = RedeemAmounts(
            feeSlip,
            riskSlipAmountToRedeem,
            ((riskSlipAmountToRedeem - feeSlip) *
                (s_penaltyGranularity - s_penalty)) / s_penaltyGranularity
        );

        vm.startPrank(s_borrowerAddress);
        s_riskSlip.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit RedeemRiskTranche(
            s_borrowerAddress,
            adjustments.riskSlipAmount - adjustments.feeSlip
        );
        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmountToRedeem);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertEq(
            before.ownerRiskSlip + adjustments.feeSlip,
            s_riskSlip.balanceOf(s_cbb_owner)
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
            before.borrowerRiskSlip - adjustments.riskSlipAmount,
            s_riskSlip.balanceOf(s_borrowerAddress)
        );
    }
}
