// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract Lend is CBBSetup {
    struct BeforeBalances {
        uint256 borrowerStables;
        uint256 borrowerRiskSlip;
        uint256 lenderSafeSlip;
        uint256 matcherRiskTranche;
        uint256 matcherSafeTranche;
        uint256 matcherStables;
        uint256 CBBRiskTranche;
        uint256 CBBSafeTranche;
    }

    struct LendAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 stableAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotLendConvertibleBondBoxNotStarted() public {
        vm.prank(s_deployedConvertibleBondBox.owner());
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.lend(address(1), address(2), 100e18);
    }

    function testCannotLendMinimumInput(uint256 stableLendAmount) public {
        uint256 minimumInput = 1e6;

        stableLendAmount = bound(stableLendAmount, 0, minimumInput - 1);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            stableLendAmount,
            minimumInput
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.lend(
            s_borrower,
            s_lender,
            stableLendAmount
        );
    }

    function testCannotLendBondIsMature() public {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        vm.warp(s_maturityDate);
        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(uint256,uint256)",
            block.timestamp,
            s_maturityDate
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, 1e6);
    }

    function testLend(
        uint256 stableLendAmount,
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
            s_riskSlip.balanceOf(s_borrower),
            s_safeSlip.balanceOf(s_lender),
            s_riskTranche.balanceOf(address(this)),
            s_safeTranche.balanceOf(address(this)),
            s_stableToken.balanceOf(address(this)),
            s_riskTranche.balanceOf(s_deployedCBBAddress),
            s_safeTranche.balanceOf(s_deployedCBBAddress)
        );

        uint256 tranchesToStables = (before.matcherSafeTranche *
            s_deployedConvertibleBondBox.currentPrice() *
            s_deployedConvertibleBondBox.stableDecimals()) /
            s_deployedConvertibleBondBox.s_priceGranularity() /
            s_deployedConvertibleBondBox.trancheDecimals();

        stableLendAmount = bound(
            stableLendAmount,
            1e6,
            Math.min(before.matcherStables, tranchesToStables)
        );

        uint256 safeTrancheAmount = (stableLendAmount *
            s_deployedConvertibleBondBox.s_priceGranularity() *
            s_deployedConvertibleBondBox.trancheDecimals()) /
            s_deployedConvertibleBondBox.currentPrice() /
            s_deployedConvertibleBondBox.stableDecimals();

        LendAmounts memory adjustments = LendAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            stableLendAmount
        );

        vm.expectEmit(true, true, true, true);
        emit Lend(
            address(this),
            s_borrower,
            s_lender,
            stableLendAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.lend(
            s_borrower,
            s_lender,
            stableLendAmount
        );

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        LendAmounts memory adjustments
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
            before.borrowerRiskSlip + adjustments.riskTrancheAmount,
            s_riskSlip.balanceOf(s_borrower)
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
