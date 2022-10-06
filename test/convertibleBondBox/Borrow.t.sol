// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract Borrow is CBBSetup {
    struct BeforeBalances {
        uint256 borrowerStables;
        uint256 borrowerIssuerSlip;
        uint256 lenderSafeSlip;
        uint256 matcherRiskTranche;
        uint256 matcherSafeTranche;
        uint256 matcherStables;
        uint256 CBBRiskTranche;
        uint256 CBBSafeTranche;
    }

    struct BorrowAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 stableAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotBorrowConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.borrow(s_borrower, s_lender, 100e18);
    }

    function testCannotBorrowMinimumInput(uint256 safeTrancheAmount) public {
        safeTrancheAmount = bound(safeTrancheAmount, 0, 1e6 - 1);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            safeTrancheAmount,
            1e6
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );
    }

    function testCannotBorrowBondIsMature() public {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        vm.warp(s_maturityDate);
        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(uint256,uint256)",
            block.timestamp,
            s_maturityDate
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.borrow(s_borrower, s_lender, 1e6);
    }

    function testBorrow(
        uint256 safeTrancheAmount,
        uint256 startPrice,
        uint256 time
    ) public {
        startPrice = bound(
            startPrice,
            s_priceGranularity / 10,
            s_priceGranularity - 1
        );

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(startPrice);

        time = bound(
            time,
            s_deployedConvertibleBondBox.s_startDate(),
            s_maturityDate
        );
        vm.warp(time);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_issuerSlip.balanceOf(s_borrower),
            s_safeSlip.balanceOf(s_lender),
            s_riskTranche.balanceOf(address(this)),
            s_safeTranche.balanceOf(address(this)),
            s_stableToken.balanceOf(address(this)),
            s_riskTranche.balanceOf(s_deployedCBBAddress),
            s_safeTranche.balanceOf(s_deployedCBBAddress)
        );

        uint256 stablesToTranches = (before.matcherStables *
            s_deployedConvertibleBondBox.s_priceGranularity() *
            s_deployedConvertibleBondBox.trancheDecimals()) /
            s_deployedConvertibleBondBox.currentPrice() /
            s_deployedConvertibleBondBox.stableDecimals();

        safeTrancheAmount = bound(
            safeTrancheAmount,
            1e6,
            Math.min(before.matcherSafeTranche, stablesToTranches)
        );

        uint256 stableAmount = (safeTrancheAmount *
            s_deployedConvertibleBondBox.currentPrice() *
            s_deployedConvertibleBondBox.stableDecimals()) /
            s_deployedConvertibleBondBox.s_priceGranularity() /
            s_deployedConvertibleBondBox.trancheDecimals();

        BorrowAmounts memory adjustments = BorrowAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            stableAmount
        );

        vm.expectEmit(true, true, true, true);
        emit Borrow(
            address(this),
            s_borrower,
            s_lender,
            safeTrancheAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        BorrowAmounts memory adjustments
    ) internal {
        assertEq(
            before.matcherSafeTranche - adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(address(this))
        );
        assertEq(
            before.CBBSafeTranche + adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.matcherRiskTranche - adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(address(this))
        );
        assertEq(
            before.CBBRiskTranche + adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.lenderSafeSlip + adjustments.safeTrancheAmount,
            s_safeSlip.balanceOf(s_lender)
        );

        assertEq(
            before.borrowerIssuerSlip + adjustments.riskTrancheAmount,
            s_issuerSlip.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerStables + adjustments.stableAmount,
            s_stableToken.balanceOf(s_borrower)
        );
        assertEq(
            before.matcherStables - adjustments.stableAmount,
            s_stableToken.balanceOf(address(this))
        );
    }
}
