// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/CBBSlip.sol";
import "../../src/contracts/CBBSlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract Lend is CBBSetup {
    address s_borrower = address(1);
    address s_lender = address(2);
    address s_owner = address(100);

    function testCannotLendConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.lend(
            address(1),
            address(2),
            s_depositLimit
        );
    }

    function initializeCBBAndBoundStableLendAmount(uint256 stableLendAmount) private returns(uint256) {
        uint256 minimumInput = (s_deployedConvertibleBondBox.safeRatio() * s_deployedConvertibleBondBox.currentPrice()) /
                s_deployedConvertibleBondBox.s_priceGranularity();

        stableLendAmount = bound(
            stableLendAmount,
            minimumInput,
            (s_safeTranche.balanceOf(address(this)) *
                s_price) /
                s_priceGranularity
        );

        vm.prank(address(this));
        s_deployedConvertibleBondBox.reinitialize(
            s_borrower,
            s_lender,
            0,
            0
        );

        return stableLendAmount;
    }

    function testCannotLendMinimumInput(uint256 stableInitialAmount, uint256 stableLendAmount) public {
        uint256 minimumInput = (s_deployedConvertibleBondBox.safeRatio() * s_deployedConvertibleBondBox.currentPrice()) /
                s_deployedConvertibleBondBox.s_priceGranularity();

        stableInitialAmount = bound(
            stableInitialAmount,
            minimumInput,
            (s_safeTranche.balanceOf(address(this)) *
                s_price) /
                s_priceGranularity
        );

        stableLendAmount = bound(
            stableLendAmount,
            0,
            minimumInput - 1
        );

        vm.prank(address(this));
        s_deployedConvertibleBondBox.reinitialize(
            s_borrower,
            s_lender,
            0,
            stableInitialAmount
        );

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            stableLendAmount,
            minimumInput
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, stableLendAmount);
    }

    function testLendEmitsLends(uint256 stableLendAmount) public {
        stableLendAmount = initializeCBBAndBoundStableLendAmount(stableLendAmount);

        vm.expectEmit(true, true, true, true);
        emit Lend(address(this), s_borrower, s_lender, stableLendAmount, s_deployedConvertibleBondBox.currentPrice());
        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, stableLendAmount);
    }

    function testLendTransfersSafeTranchesToCBB(uint256 stableLendAmount) public {
        stableLendAmount = initializeCBBAndBoundStableLendAmount(stableLendAmount);

        uint256 mintAmount = (stableLendAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();

        uint256 matcherContractSafeTrancheBalanceBeforeLend = s_safeTranche.balanceOf(address(this));
        uint256 CBBSafeTrancheBalanceBeforeLend = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, stableLendAmount);

        uint256 matcherContractSafeTrancheBalanceAfterLend = s_safeTranche.balanceOf(address(this));
        uint256 CBBSafeTrancheBalanceAfterLend = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(matcherContractSafeTrancheBalanceBeforeLend - mintAmount, matcherContractSafeTrancheBalanceAfterLend);
        assertEq(CBBSafeTrancheBalanceBeforeLend + mintAmount, CBBSafeTrancheBalanceAfterLend);
    }

    function testLendTransfersRiskTranchesToCBB(uint256 stableLendAmount) public {
        stableLendAmount = initializeCBBAndBoundStableLendAmount(stableLendAmount);

        uint256 mintAmount = (stableLendAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();
        uint256 zTrancheAmount = (mintAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

        uint256 matcherContractRiskTrancheBalanceBeforeLend = s_riskTranche.balanceOf(address(this));
        uint256 CBBRiskTrancheBalanceBeforeLend = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, stableLendAmount);

        uint256 matcherContractRiskTrancheBalanceAfterLend = s_riskTranche.balanceOf(address(this));
        uint256 CBBRiskTrancheBalanceAfterLend = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(matcherContractRiskTrancheBalanceBeforeLend - zTrancheAmount, matcherContractRiskTrancheBalanceAfterLend);
        assertEq(CBBRiskTrancheBalanceBeforeLend + zTrancheAmount, CBBRiskTrancheBalanceAfterLend);
    }

    function testLendMintsSafeSlipsToLender(uint256 stableLendAmount) public {
        stableLendAmount = initializeCBBAndBoundStableLendAmount(stableLendAmount);

        uint256 mintAmount = (stableLendAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();

        uint256 LenderSafeSlipBalanceBeforeLend = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(s_lender));

        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, stableLendAmount);

        uint256 LenderSafeSlipBalanceAfterLend = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(s_lender));

        assertEq(LenderSafeSlipBalanceBeforeLend + mintAmount, LenderSafeSlipBalanceAfterLend);
    }

    function testLendMintsRiskSlipsToBorrower(uint256 stableLendAmount) public {
        stableLendAmount = initializeCBBAndBoundStableLendAmount(stableLendAmount);

        uint256 mintAmount = (stableLendAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();
        uint256 zTrancheAmount = (mintAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

        uint256 borrowerSafeSlipBalanceBeforeLend = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_borrower));

        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, stableLendAmount);

        uint256 borrowerSafeSlipBalanceAfterLend = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_borrower));

        assertEq(borrowerSafeSlipBalanceBeforeLend + zTrancheAmount, borrowerSafeSlipBalanceAfterLend);
    }

    function testLendTransfersStablesToBorrower(uint256 stableLendAmount) public {
        stableLendAmount = initializeCBBAndBoundStableLendAmount(stableLendAmount);

        uint256 borrowerStableBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_borrower));
        uint256 CBBStableBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

        s_deployedConvertibleBondBox.lend(s_borrower, s_lender, stableLendAmount);

        uint256 borrowerStableBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_borrower));
        uint256 CBBStableBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

        assertEq(borrowerStableBalanceBeforeLend + stableLendAmount, borrowerStableBalanceAfterLend);
        assertEq(CBBStableBalanceBeforeLend - stableLendAmount, CBBStableBalanceAfterLend);
    }
}