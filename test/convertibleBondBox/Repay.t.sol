// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract Repay is CBBSetup {
    //tests Repay after maturity
    function testRepay(
        uint256 time,
        uint256 amount,
        uint256 stableAmount
    ) public {
        address borrowerAddress = address(1);
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        amount = bound(amount, s_deployedConvertibleBondBox.safeRatio(), 1e15);
        stableAmount = bound(
            stableAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            amount
        );

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            address(2),
            amount
        );

        s_stableToken.mint(borrowerAddress, stableAmount);

        vm.warp(time);

        uint256 userStableBalancedBeforeRepay = s_stableToken.balanceOf(
            borrowerAddress
        );
        uint256 userSafeTrancheBalanceBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(borrowerAddress);
        uint256 userRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
                .riskTranche()
                .balanceOf(borrowerAddress);
        uint256 userRiskSlipBalancedBeforeRepay = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(borrowerAddress);

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
            0,
            userStableBalancedBeforeRepay,
            0,
            borrowerAddress
        );

        repaySafeTrancheBalanceAssertions(
            userSafeTrancheBalanceBeforeRepay,
            safeTranchePayout,
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

    //tests Repay after maturity with fee
    function testRepayWithFee(
        uint256 time,
        uint256 amount,
        uint256 stableAmount,
        uint256 fee
    ) public {
        address borrowerAddress = address(1);
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        amount = bound(amount, s_deployedConvertibleBondBox.safeRatio(), 1e15);
        stableAmount = bound(
            stableAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            amount
        );
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            address(2),
            amount
        );

        s_stableToken.mint(borrowerAddress, stableAmount);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.setFee(fee);

        vm.warp(time);

        uint256 userStableBalancedBeforeRepay = s_stableToken.balanceOf(
            borrowerAddress
        );
        uint256 ownerStableBalancedBeforeRepay = s_stableToken.balanceOf(
            s_cbb_owner
        );
        uint256 userSafeTrancheBalanceBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(borrowerAddress);
        uint256 userRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
                .riskTranche()
                .balanceOf(borrowerAddress);
        uint256 userRiskSlipBalancedBeforeRepay = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(borrowerAddress);

        uint256 CBBSafeTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        uint256 CBBRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeTranchePayout = ((stableAmount) * s_priceGranularity) /
            s_deployedConvertibleBondBox.currentPrice();

        uint256 zTranchePaidFor = (safeTranchePayout *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.startPrank(borrowerAddress);

        s_deployedConvertibleBondBox.stableToken().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.riskSlip().approve(
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
            fee,
            userStableBalancedBeforeRepay,
            ownerStableBalancedBeforeRepay,
            borrowerAddress
        );

        repaySafeTrancheBalanceAssertions(
            userSafeTrancheBalanceBeforeRepay,
            safeTranchePayout,
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
        uint256 fee,
        uint256 userStableBalancedBeforeRepay,
        uint256 ownerStableBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 CBBStableBalance = s_stableToken.balanceOf(
            address(s_deployedConvertibleBondBox)
        );
        uint256 userStableBalancedAfterRepay = s_stableToken.balanceOf(
            borrowerAddress
        );
        uint256 ownerStableBalancedAfterRepay = s_stableToken.balanceOf(
            s_cbb_owner
        );

        uint256 stableFees = (stableAmount * fee) / s_BPS;

        assertEq(stableAmount, CBBStableBalance);
        assertEq(
            userStableBalancedBeforeRepay - stableAmount - stableFees,
            userStableBalancedAfterRepay
        );
        if (stableFees > 0) {
            assertEq(
                ownerStableBalancedBeforeRepay + stableFees,
                ownerStableBalancedAfterRepay
            );
        }
    }

    function repaySafeTrancheBalanceAssertions(
        uint256 userSafeTrancheBalanceBeforeRepay,
        uint256 safeTranchePayout,
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
            userSafeTrancheBalanceBeforeRepay + safeTranchePayout,
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
        uint256 userRiskSlipBalancedAfterRepay = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(borrowerAddress);

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
