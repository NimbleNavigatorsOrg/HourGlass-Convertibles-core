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

contract Borrow is CBBSetup {
    address s_initial_borrower = address(1);
    address s_initial_lender = address(2);
    address s_owner = address(100);

    //borrow()
    // Need to write a test that calls borrow() without calling initialize()

    function testCannotBorrowConvertibleBondBoxNotStarted() public {
        address s_initial_borrower = address(1);
        address s_initial_lender = address(2);

        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.borrow(
            s_initial_borrower,
            s_initial_lender,
            s_depositLimit
        );
    }

    function testCannotBorrowMinimumInput(uint256 safeTrancheAmount) public {
        address s_borrower = address(3);
        address s_lender = address(4);
        address s_owner = address(100);

        safeTrancheAmount = bound(safeTrancheAmount, 0, s_deployedConvertibleBondBox.safeRatio() - 1);

        s_deployedConvertibleBondBox.initialize(
            s_initial_borrower,
            s_initial_lender,
            0,
            0,
            s_owner
        );

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            safeTrancheAmount,
            s_deployedConvertibleBondBox.safeRatio()
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );
    }

    function initializeCBBAndBoundSafeTrancheAmount(uint256 safeTrancheAmount) private returns(uint256) {
        safeTrancheAmount = bound(
            safeTrancheAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_safeTranche.balanceOf(address(this))
        );

        s_deployedConvertibleBondBox.initialize(
            s_initial_borrower,
            s_initial_lender,
            0,
            0,
            s_owner
        );

        return safeTrancheAmount;
    }

    function testBorrowEmitsBorrow(uint256 safeTrancheAmount) public {
        address s_borrower = address(3);
        address s_lender = address(4);
        
        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(safeTrancheAmount);

        vm.expectEmit(true, true, true, true);
        emit Borrow(address(this), s_borrower, s_lender, safeTrancheAmount, s_deployedConvertibleBondBox.currentPrice());
        s_deployedConvertibleBondBox.borrow(s_borrower, s_lender, safeTrancheAmount);
    }

    // function testLendTransfersSafeTranchesToCBB(uint256 safeTrancheAmount) public {
    //     safeTrancheAmount = initializeCBBAndBoundStableLendAmount(safeTrancheAmount);

    //     uint256 mintAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();

    //     uint256 matcherContractSafeTrancheBalanceBeforeLend = s_safeTranche.balanceOf(address(this));
    //     uint256 CBBSafeTrancheBalanceBeforeLend = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 matcherContractSafeTrancheBalanceAfterLend = s_safeTranche.balanceOf(address(this));
    //     uint256 CBBSafeTrancheBalanceAfterLend = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

    //     assertEq(matcherContractSafeTrancheBalanceBeforeLend - mintAmount, matcherContractSafeTrancheBalanceAfterLend);
    //     assertEq(CBBSafeTrancheBalanceBeforeLend + mintAmount, CBBSafeTrancheBalanceAfterLend);
    // }

    // function testLendTransfersRiskTranchesToCBB(uint256 safeTrancheAmount) public {
    //     safeTrancheAmount = initializeCBBAndBoundStableLendAmount(safeTrancheAmount);

    //     uint256 mintAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();
    //     uint256 zTrancheAmount = (mintAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

    //     uint256 matcherContractRiskTrancheBalanceBeforeLend = s_riskTranche.balanceOf(address(this));
    //     uint256 CBBRiskTrancheBalanceBeforeLend = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 matcherContractRiskTrancheBalanceAfterLend = s_riskTranche.balanceOf(address(this));
    //     uint256 CBBRiskTrancheBalanceAfterLend = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

    //     assertEq(matcherContractRiskTrancheBalanceBeforeLend - zTrancheAmount, matcherContractRiskTrancheBalanceAfterLend);
    //     assertEq(CBBRiskTrancheBalanceBeforeLend + zTrancheAmount, CBBRiskTrancheBalanceAfterLend);
    // }

    // function testLendMintsSafeSlipsToLender(uint256 safeTrancheAmount) public {
    //     safeTrancheAmount = initializeCBBAndBoundStableLendAmount(safeTrancheAmount);

    //     uint256 mintAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();

    //     uint256 LenderSafeSlipBalanceBeforeLend = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(s_lender));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 LenderSafeSlipBalanceAfterLend = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(s_lender));

    //     assertEq(LenderSafeSlipBalanceBeforeLend + mintAmount, LenderSafeSlipBalanceAfterLend);
    // }

    // function testLendMintsRiskSlipsToBorrower(uint256 safeTrancheAmount) public {
    //     safeTrancheAmount = initializeCBBAndBoundStableLendAmount(safeTrancheAmount);

    //     uint256 mintAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();
    //     uint256 zTrancheAmount = (mintAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

    //     uint256 borrowerSafeSlipBalanceBeforeLend = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_borrower));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 borrowerSafeSlipBalanceAfterLend = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_borrower));

    //     assertEq(borrowerSafeSlipBalanceBeforeLend + zTrancheAmount, borrowerSafeSlipBalanceAfterLend);
    // }

    // function testLendTransfersStablesToBorrower(uint256 safeTrancheAmount) public {
    //     safeTrancheAmount = initializeCBBAndBoundStableLendAmount(safeTrancheAmount);

    //     uint256 borrowerStableBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_borrower));
    //     uint256 CBBStableBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 borrowerStableBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_borrower));
    //     uint256 CBBStableBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

    //     assertEq(borrowerStableBalanceBeforeLend + safeTrancheAmount, borrowerStableBalanceAfterLend);
    //     assertEq(CBBStableBalanceBeforeLend - safeTrancheAmount, CBBStableBalanceAfterLend);
    // }
    
}