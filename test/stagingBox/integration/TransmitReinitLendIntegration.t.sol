pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../../src/contracts/StagingBox.sol";
import "../../../src/contracts/StagingBoxFactory.sol";
import "../../../src/contracts/CBBFactory.sol";
import "../../../src/contracts/ConvertibleBondBox.sol";
import "./SBIntegrationSetup.t.sol";

contract TransmitReinitLendIntegration is SBIntegrationSetup {
    function testTransmitReInitIntegrationLend(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(true, address(s_deployedSB), s_deployedCBBAddress);

        uint256 stableAmount = s_deployedSB.stableToken().balanceOf(
            address(s_deployedSB)
        );

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);
        vm.stopPrank();

        assertEq(true, s_deployedSB.s_hasReinitialized());
        assertEq(stableAmount, s_deployedSB.s_reinitLendAmount());
        assertEq(s_cbb_owner, s_deployedSB.owner());
    }

    function testTransmitReinitIntegrationLendEmitsLend(uint256 fuzzPrice)
        public
    {
        setupStagingBox(fuzzPrice);
        setupTranches(true, address(s_deployedSB), s_deployedCBBAddress);

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit Lend(
            address(s_deployedSB),
            address(s_deployedSB),
            address(s_deployedSB),
            maxStableAmount,
            s_price
        );
        s_deployedSB.transmitReInit(s_isLend);
    }

    function testTransmitReinitIntegrationLendTransfersSafeTranchesFromSBToCBB(
        uint256 fuzzPrice
    ) public {
        setupStagingBox(fuzzPrice);
        setupTranches(true, address(s_deployedSB), s_deployedCBBAddress);

        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_stableToken)
            .balanceOf(address(s_deployedSB));
        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            address(s_deployedSB)
        );
        uint256 cbbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 mintAmount = (sbStableTokenBalanceBeforeLend *
            s_priceGranularity) / s_deployedConvertibleBondBox.currentPrice();

        uint256 sbSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            address(s_deployedSB)
        );
        uint256 cbbSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        assertEq(
            sbSafeTrancheBalanceBefore - mintAmount,
            sbSafeTrancheBalanceAfter
        );
        assertEq(
            cbbSafeTrancheBalanceBefore + mintAmount,
            cbbSafeTrancheBalanceAfter
        );
    }

    function testTransmitReinitIntegrationLendTransfersRiskTrancheFromSBToCBB(
        uint256 fuzzPrice
    ) public {
        setupStagingBox(fuzzPrice);
        setupTranches(true, address(s_deployedSB), s_deployedCBBAddress);

        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_stableToken)
            .balanceOf(address(s_deployedSB));
        uint256 sbRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            address(s_deployedSB)
        );
        uint256 cbbRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            address(s_deployedSB)
        );
        uint256 cbbRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        uint256 mintAmount = (sbStableTokenBalanceBeforeLend *
            s_priceGranularity) / s_deployedConvertibleBondBox.currentPrice();
        uint256 expectedZ = (mintAmount * s_ratios[2]) / s_ratios[0];

        assertEq(
            sbRiskTrancheBalanceBefore - expectedZ,
            sbRiskTrancheBalanceAfter
        );
        assertEq(
            cbbRiskTrancheBalanceBefore + expectedZ,
            cbbRiskTrancheBalanceAfter
        );
    }

    function testTransmitReinitIntegrationLendMintsSafeSlipsToStagingBox(
        uint256 fuzzPrice
    ) public {
        setupStagingBox(fuzzPrice);
        setupTranches(true, address(s_deployedSB), s_deployedCBBAddress);

        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_stableToken)
            .balanceOf(address(s_deployedSB));

        uint256 sbSafeSlipBalanceBefore = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbSafeSlipBalanceAfter = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(s_deployedSB));

        uint256 mintAmount = (sbStableTokenBalanceBeforeLend *
            s_priceGranularity) / s_deployedConvertibleBondBox.currentPrice();

        assertEq(sbSafeSlipBalanceBefore + mintAmount, sbSafeSlipBalanceAfter);
    }

    function testTransmitReinitIntegrationLendMintsRiskSlipsToStagingBox(
        uint256 fuzzPrice
    ) public {
        setupStagingBox(fuzzPrice);
        setupTranches(true, address(s_deployedSB), s_deployedCBBAddress);

        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_stableToken)
            .balanceOf(address(s_deployedSB));

        uint256 sbRiskSlipBalanceBefore = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbRiskSlipBalanceAfter = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(address(s_deployedSB));

        uint256 mintAmount = (sbStableTokenBalanceBeforeLend *
            s_priceGranularity) / s_deployedConvertibleBondBox.currentPrice();
        uint256 expectedZ = (mintAmount * s_ratios[2]) / s_ratios[0];

        assertEq(sbRiskSlipBalanceBefore + expectedZ, sbRiskSlipBalanceAfter);
    }

    function testTransmitReinitIntegrationLendDoesNotChangeSBStableBalance(
        uint256 fuzzPrice
    ) public {
        setupStagingBox(fuzzPrice);
        setupTranches(true, address(s_deployedSB), s_deployedCBBAddress);

        uint256 sbStableBalanceBefore = IERC20(s_stableToken).balanceOf(
            address(s_deployedSB)
        );

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbStableBalanceAfter = s_stableToken.balanceOf(
            address(s_deployedSB)
        );

        assertEq(sbStableBalanceBefore, sbStableBalanceAfter);
    }
}
