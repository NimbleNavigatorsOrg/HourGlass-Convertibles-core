pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../../src/contracts/StagingBox.sol";
import "../../../src/contracts/StagingBoxFactory.sol";
import "../../../src/contracts/CBBFactory.sol";
import "../../../src/contracts/ConvertibleBondBox.sol";
import "./SBIntegrationSetup.t.sol";

contract TransmitReinitLendIntegration is SBIntegrationSetup {

    function transmitReinitIntegrationSetup (uint256 fuzzPrice) private {
        price = bound(fuzzPrice, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_cbb_owner
        ));

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.cbbTransferOwnership(address(s_deployedSB));

        s_collateralToken.mint(address(s_deployedSB), 1e18);

        vm.prank(address(s_deployedSB));
        s_collateralToken.approve(
            address(s_buttonWoodBondController),
            type(uint256).max
        );

        vm.prank(address(s_deployedSB));
        s_buttonWoodBondController.deposit(1e18);
        (s_safeTranche, s_safeRatio) = s_buttonWoodBondController.tranches(
            s_trancheIndex
        );
        (s_riskTranche, s_riskRatio) = s_buttonWoodBondController.tranches(
            s_buttonWoodBondController.trancheCount() - 1
        );

        maxStableAmount =
            (s_safeTranche.balanceOf(address(s_deployedSB)) * price) /
                s_priceGranularity;

        s_stableToken.mint(address(s_deployedSB), maxStableAmount);

        vm.startPrank(address(s_deployedSB));
        s_safeTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_riskTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.stopPrank();


    }

    function testTransmitReinitIntegrationIsLendTrueEmitsLend(uint256 fuzzPrice) public {
        transmitReinitIntegrationSetup(fuzzPrice);

        bool _isLend = true;

        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_stableToken).balanceOf(address(s_deployedSB));
        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedSB));
        uint256 sbRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit Lend(address(s_deployedSB), address(s_deployedSB), address(s_deployedSB), maxStableAmount, price);
        s_deployedSB.transmitReInit(_isLend);

        uint256 sbSafeTrancheBalanceAfter = s_safeTranche.balanceOf(address(s_deployedSB));
        uint256 sbRiskTrancheBalanceAfter = s_riskTranche.balanceOf(address(s_deployedSB));

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(address(s_deployedSB));
        uint256 borrowerRiskSlipsAfter = ISlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_deployedSB));

        uint256 lenderSafeSlipsAfter = ISlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(s_deployedSB));

        uint256 mintAmount = (sbStableTokenBalanceBeforeLend * s_priceGranularity) /
            s_deployedConvertibleBondBox.currentPrice();
        uint256 expectedZ = (mintAmount * s_ratios[2]) / s_ratios[0];

        assertEq(
            sbSafeTrancheBalanceBefore - mintAmount,
            sbSafeTrancheBalanceAfter
        );
        assertEq(
            sbRiskTrancheBalanceBefore - expectedZ,
            sbRiskTrancheBalanceAfter
        );
        assertEq(borrowerStableBalanceAfter, sbStableTokenBalanceBeforeLend);
        assertEq(borrowerRiskSlipsAfter, expectedZ);
        assertEq(lenderSafeSlipsAfter, mintAmount);
    }
}