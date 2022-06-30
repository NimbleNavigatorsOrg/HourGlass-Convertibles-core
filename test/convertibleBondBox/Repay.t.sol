// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract Repay is CBBSetup {
    // repay()

    function testRepay(
        uint256 time,
        uint256 amount,
        uint256 stableAmount
    ) public {
        address borrowerAddress = address(1);
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        vm.warp(s_maturityDate + time);
        uint256 minAmount = (s_deployedConvertibleBondBox.safeRatio() *
            s_deployedConvertibleBondBox.currentPrice()) / s_priceGranularity;
        amount = bound(amount, minAmount, 1e17);
        stableAmount = bound(stableAmount, minAmount, amount);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(
            borrowerAddress,
            address(2),
            amount,
            0,
            s_price
        );

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            address(2),
            amount
        );

        uint256 userStableBalancedBeforeRepay = s_stableToken.balanceOf(
            borrowerAddress
        );
        uint256 userSafeTrancheBalanceBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(borrowerAddress);
        uint256 userRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
                .riskTranche()
                .balanceOf(borrowerAddress);
        uint256 userRiskSlipBalancedBeforeRepay = ISlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(borrowerAddress);

        uint256 CBBSafeTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        uint256 CBBRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeTranchePayout = (stableAmount * s_priceGranularity) /
            s_deployedConvertibleBondBox.currentPrice();

        uint256 zTranchePaidFor = (safeTranchePayout *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.startPrank(borrowerAddress);

        s_deployedConvertibleBondBox.stableToken().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        vm.expectEmit(true, true, true, true);
        emit Repay(
            borrowerAddress,
            stableAmount,
            zTranchePaidFor,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.repay(stableAmount);
        vm.stopPrank();

        repayStableBalanceAssertions(
            stableAmount,
            s_stableToken,
            userStableBalancedBeforeRepay,
            borrowerAddress
        );

        repaySafeTrancheBalanceAssertions(
            userSafeTrancheBalanceBeforeRepay,
            safeTranchePayout,
            0,
            CBBSafeTrancheBalancedBeforeRepay,
            borrowerAddress
        );

        repayRiskTrancheBalanceAssertions(
            userRiskTrancheBalancedBeforeRepay,
            zTranchePaidFor,
            CBBRiskTrancheBalancedBeforeRepay,
            borrowerAddress
        );

        repayRiskSlipAssertions(
            userRiskSlipBalancedBeforeRepay,
            zTranchePaidFor,
            borrowerAddress
        );
    }

    function testRepayWithFee(
        uint256 time,
        uint256 amount,
        uint256 stableAmount,
        uint256 fee
    ) public {
        address borrowerAddress = address(1);
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        vm.warp(s_maturityDate + time);
        uint256 minAmount = ((s_deployedConvertibleBondBox.safeRatio() *
            s_deployedConvertibleBondBox.currentPrice()) / s_priceGranularity) *
            10000;
        amount = bound(amount, minAmount, 1e17);
        stableAmount = bound(stableAmount, minAmount, amount);
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(
            borrowerAddress,
            address(2),
            amount,
            0,
            s_price
        );

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            address(2),
            amount
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        uint256 userStableBalancedBeforeRepay = s_stableToken.balanceOf(
            borrowerAddress
        );
        uint256 userSafeTrancheBalanceBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(borrowerAddress);
        uint256 userRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
                .riskTranche()
                .balanceOf(borrowerAddress);
        uint256 userRiskSlipBalancedBeforeRepay = ISlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(borrowerAddress);

        uint256 CBBSafeTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        uint256 CBBRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeTranchePayout = ((stableAmount) * s_priceGranularity) /
            s_deployedConvertibleBondBox.currentPrice();

        uint256 safeTrancheFees = (safeTranchePayout * fee) / s_BPS;

        uint256 zTranchePaidFor = (safeTranchePayout *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.startPrank(borrowerAddress);

        s_deployedConvertibleBondBox.stableToken().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        ISlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        vm.expectEmit(true, true, true, true);
        emit Repay(
            borrowerAddress,
            stableAmount,
            zTranchePaidFor,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.repay(stableAmount);
        vm.stopPrank();

        repayStableBalanceAssertions(
            stableAmount,
            s_stableToken,
            userStableBalancedBeforeRepay,
            borrowerAddress
        );

        repaySafeTrancheBalanceAssertions(
            userSafeTrancheBalanceBeforeRepay,
            safeTranchePayout,
            safeTrancheFees,
            CBBSafeTrancheBalancedBeforeRepay,
            borrowerAddress
        );

        repayRiskTrancheBalanceAssertions(
            userRiskTrancheBalancedBeforeRepay,
            zTranchePaidFor,
            CBBRiskTrancheBalancedBeforeRepay,
            borrowerAddress
        );

        repayRiskSlipAssertions(
            userRiskSlipBalancedBeforeRepay,
            zTranchePaidFor,
            borrowerAddress
        );
    }

    function repayStableBalanceAssertions(
        uint256 stableAmount,
        MockERC20 s_stableToken,
        uint256 userStableBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 CBBStableBalance = s_stableToken.balanceOf(
            address(s_deployedConvertibleBondBox)
        );
        uint256 userStableBalancedAfterRepay = s_stableToken.balanceOf(
            borrowerAddress
        );

        assertEq(stableAmount, CBBStableBalance);
        assertEq(
            userStableBalancedBeforeRepay - stableAmount,
            userStableBalancedAfterRepay
        );
    }

    function repaySafeTrancheBalanceAssertions(
        uint256 userSafeTrancheBalanceBeforeRepay,
        uint256 safeTranchePayout,
        uint256 safeTrancheFees,
        uint256 CBBSafeTrancheBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 userSafeTrancheBalancedAfterRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(borrowerAddress);
        uint256 CBBSafeTrancheBalancedAfterRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(
            userSafeTrancheBalanceBeforeRepay +
                safeTranchePayout -
                safeTrancheFees,
            userSafeTrancheBalancedAfterRepay
        );
        assertEq(
            CBBSafeTrancheBalancedBeforeRepay - safeTranchePayout,
            CBBSafeTrancheBalancedAfterRepay
        );
    }

    function repayRiskTrancheBalanceAssertions(
        uint256 userRiskTrancheBalancedBeforeRepay,
        uint256 zTranchePaidFor,
        uint256 CBBRiskTrancheBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 userRiskTrancheBalancedAfterRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(borrowerAddress);
        uint256 CBBRiskTrancheBalanceAfterRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        assertEq(
            userRiskTrancheBalancedBeforeRepay + zTranchePaidFor,
            userRiskTrancheBalancedAfterRepay
        );
        assertEq(
            CBBRiskTrancheBalancedBeforeRepay - zTranchePaidFor,
            CBBRiskTrancheBalanceAfterRepay
        );
    }

    function repayRiskSlipAssertions(
        uint256 userRiskSlipBalancedBeforeRepay,
        uint256 zTranchePaidForWithoutFees,
        address borrowerAddress
    ) private {
        uint256 userRiskSlipBalancedAfterRepay = ISlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(borrowerAddress);

        assertEq(
            userRiskSlipBalancedBeforeRepay - zTranchePaidForWithoutFees,
            userRiskSlipBalancedAfterRepay
        );
    }

    function testCannotRepayConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.repay(100000);
    }
}
