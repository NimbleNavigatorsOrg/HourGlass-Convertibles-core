pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../../src/contracts/StagingBox.sol";
import "../../../src/contracts/StagingBoxFactory.sol";
import "../../../src/contracts/CBBFactory.sol";
import "../../../src/contracts/ConvertibleBondBox.sol";
import "./SBIntegrationSetup.t.sol";

contract TransmitReinitLendIntegration is SBIntegrationSetup {

    function testTransmitReinitIntegrationIsLendTrueEmitsLend(uint256 fuzzPrice) public {
        transmitReinitIntegrationSetup(fuzzPrice, true);

        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_stableToken).balanceOf(address(s_deployedSB));
        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedSB));
        uint256 sbRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit Lend(address(s_deployedSB), address(s_deployedSB), address(s_deployedSB), maxStableAmount, s_price);
        s_deployedSB.transmitReInit(s_isLend);

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