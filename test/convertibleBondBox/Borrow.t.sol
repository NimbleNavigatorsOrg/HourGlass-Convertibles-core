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

    function testBorrowTransfersSafeTranchesToCBB(uint256 safeTrancheAmount) public {
        address s_borrower = address(3);
        address s_lender = address(4);
        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(safeTrancheAmount);

        uint256 matcherContractSafeTrancheBalanceBeforeBorrow = s_safeTranche.balanceOf(address(this));
        uint256 CBBSafeTrancheBalanceBeforeBorrow = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

        s_deployedConvertibleBondBox.borrow(s_borrower, s_lender, safeTrancheAmount);

        uint256 matcherContractSafeTrancheBalanceAfterBorrow = s_safeTranche.balanceOf(address(this));
        uint256 CBBSafeTrancheBalanceAfterBorrow = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(matcherContractSafeTrancheBalanceBeforeBorrow - safeTrancheAmount, matcherContractSafeTrancheBalanceAfterBorrow);
        assertEq(CBBSafeTrancheBalanceBeforeBorrow + safeTrancheAmount, CBBSafeTrancheBalanceAfterBorrow);
    }

    // function testBorrowTransfersRiskTranchesToCBB(uint256 safeTrancheAmount) public {
        //         address s_borrower = address(3);
        // address s_lender = address(4);
    //     safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(safeTrancheAmount);

    //     uint256 mintAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();
    //     uint256 zTrancheAmount = (mintAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

    //     uint256 matcherContractRiskTrancheBalanceBeforeBorrow = s_riskTranche.balanceOf(address(this));
    //     uint256 CBBRiskTrancheBalanceBeforeBorrow = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 matcherContractRiskTrancheBalanceAfterBorrow = s_riskTranche.balanceOf(address(this));
    //     uint256 CBBRiskTrancheBalanceAfterBorrow = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

    //     assertEq(matcherContractRiskTrancheBalanceBeforeBorrow - zTrancheAmount, matcherContractRiskTrancheBalanceAfterBorrow);
    //     assertEq(CBBRiskTrancheBalanceBeforeBorrow + zTrancheAmount, CBBRiskTrancheBalanceAfterBorrow);
    // }

    // function testBorrowMintsSafeSlipsToBorrower(uint256 safeTrancheAmount) public {
                // address s_borrower = address(3);
        // address s_lender = address(4);
    //     safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(safeTrancheAmount);

    //     uint256 mintAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();

    //     uint256 BorrowerSafeSlipBalanceBeforeBorrow = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(s_lender));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 BorrowerSafeSlipBalanceAfterBorrow = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(s_lender));

    //     assertEq(BorrowerSafeSlipBalanceBeforeBorrow + mintAmount, BorrowerSafeSlipBalanceAfterBorrow);
    // }

    // function testBorrowMintsRiskSlipsToBorrower(uint256 safeTrancheAmount) public {
        //         address s_borrower = address(3);
        // address s_lender = address(4);
    //     safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(safeTrancheAmount);

    //     uint256 mintAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.s_priceGranularity()) / s_deployedConvertibleBondBox.currentPrice();
    //     uint256 zTrancheAmount = (mintAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

    //     uint256 borrowerSafeSlipBalanceBeforeBorrow = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_borrower));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 borrowerSafeSlipBalanceAfterBorrow = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(s_borrower));

    //     assertEq(borrowerSafeSlipBalanceBeforeBorrow + zTrancheAmount, borrowerSafeSlipBalanceAfterBorrow);
    // }

    // function testBorrowTransfersStablesToBorrower(uint256 safeTrancheAmount) public {
        //         address s_borrower = address(3);
        // address s_lender = address(4);
    //     safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(safeTrancheAmount);

    //     uint256 borrowerStableBalanceBeforeBorrow = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_borrower));
    //     uint256 CBBStableBalanceBeforeBorrow = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

    //     s_deployedConvertibleBondBox.lend(s_borrower, s_lender, safeTrancheAmount);

    //     uint256 borrowerStableBalanceAfterBorrow = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_borrower));
    //     uint256 CBBStableBalanceAfterBorrow = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

    //     assertEq(borrowerStableBalanceBeforeBorrow + safeTrancheAmount, borrowerStableBalanceAfterBorrow);
    //     assertEq(CBBStableBalanceBeforeBorrow - safeTrancheAmount, CBBStableBalanceAfterBorrow);
    // }
    
}