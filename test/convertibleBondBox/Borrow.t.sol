// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract Borrow is CBBSetup {
    address s_initial_borrower = address(1);
    address s_initial_lender = address(2);

    //borrow()

    function testCannotBorrowConvertibleBondBoxNotStarted() public {
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

        safeTrancheAmount = bound(
            safeTrancheAmount,
            0,
            s_deployedConvertibleBondBox.safeRatio() - 1
        );
        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.reinitialize(s_price);

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

    function initializeCBBAndBoundSafeTrancheAmount(uint256 safeTrancheAmount)
        private
        returns (uint256)
    {
        safeTrancheAmount = bound(
            safeTrancheAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_safeTranche.balanceOf(s_deployedConvertibleBondBox.owner())
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.reinitialize(s_price);

        return safeTrancheAmount;
    }

    function testBorrowEmitsBorrow(uint256 safeTrancheAmount) public {
        address s_borrower = address(3);
        address s_lender = address(4);

        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(
            safeTrancheAmount
        );
        vm.startPrank(s_deployedConvertibleBondBox.owner());
        vm.expectEmit(true, true, true, true);
        emit Borrow(
            s_deployedConvertibleBondBox.owner(),
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
        vm.stopPrank();
    }

    function testBorrowTransfersSafeTranchesToCBB(uint256 safeTrancheAmount)
        public
    {
        address s_borrower = address(3);
        address s_lender = address(4);
        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(
            safeTrancheAmount
        );

        uint256 matcherContractSafeTrancheBalanceBeforeBorrow = s_safeTranche
            .balanceOf(s_deployedConvertibleBondBox.owner());
        uint256 CBBSafeTrancheBalanceBeforeBorrow = s_safeTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );

        uint256 matcherContractSafeTrancheBalanceAfterBorrow = s_safeTranche
            .balanceOf(s_deployedConvertibleBondBox.owner());
        uint256 CBBSafeTrancheBalanceAfterBorrow = s_safeTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        assertEq(
            matcherContractSafeTrancheBalanceBeforeBorrow - safeTrancheAmount,
            matcherContractSafeTrancheBalanceAfterBorrow
        );
        assertEq(
            CBBSafeTrancheBalanceBeforeBorrow + safeTrancheAmount,
            CBBSafeTrancheBalanceAfterBorrow
        );
    }

    function testBorrowTransfersRiskTranchesToCBB(uint256 safeTrancheAmount)
        public
    {
        address s_borrower = address(3);
        address s_lender = address(4);
        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(
            safeTrancheAmount
        );

        uint256 zTrancheAmount = (safeTrancheAmount *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        uint256 matcherContractRiskTrancheBalanceBeforeBorrow = s_riskTranche
            .balanceOf(s_deployedConvertibleBondBox.owner());
        uint256 CBBRiskTrancheBalanceBeforeBorrow = s_riskTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );

        uint256 matcherContractRiskTrancheBalanceAfterBorrow = s_riskTranche
            .balanceOf(s_deployedConvertibleBondBox.owner());
        uint256 CBBRiskTrancheBalanceAfterBorrow = s_riskTranche.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        assertEq(
            matcherContractRiskTrancheBalanceBeforeBorrow - zTrancheAmount,
            matcherContractRiskTrancheBalanceAfterBorrow
        );
        assertEq(
            CBBRiskTrancheBalanceBeforeBorrow + zTrancheAmount,
            CBBRiskTrancheBalanceAfterBorrow
        );
    }

    function testBorrowMintsSafeSlipsToBorrower(uint256 safeTrancheAmount)
        public
    {
        address s_borrower = address(3);
        address s_lender = address(4);
        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(
            safeTrancheAmount
        );

        uint256 LenderSafeSlipBalanceBeforeBorrow = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(s_lender));

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );

        uint256 LenderSafeSlipBalanceAfterBorrow = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(s_lender));

        assertEq(
            LenderSafeSlipBalanceBeforeBorrow + safeTrancheAmount,
            LenderSafeSlipBalanceAfterBorrow
        );
    }

    function testBorrowMintsRiskSlipsToBorrower(uint256 safeTrancheAmount)
        public
    {
        address s_borrower = address(3);
        address s_lender = address(4);
        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(
            safeTrancheAmount
        );

        uint256 zTrancheAmount = (safeTrancheAmount *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        uint256 borrowerSafeSlipBalanceBeforeBorrow = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(address(s_borrower));

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );

        uint256 borrowerSafeSlipBalanceAfterBorrow = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(address(s_borrower));

        assertEq(
            borrowerSafeSlipBalanceBeforeBorrow + zTrancheAmount,
            borrowerSafeSlipBalanceAfterBorrow
        );
    }

    function testBorrowTransfersStablesToBorrower(uint256 safeTrancheAmount)
        public
    {
        address s_borrower = address(3);
        address s_lender = address(4);
        safeTrancheAmount = initializeCBBAndBoundSafeTrancheAmount(
            safeTrancheAmount
        );

        uint256 borrowerStableBalanceBeforeBorrow = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(address(s_borrower));
        uint256 CBBStableBalanceBeforeBorrow = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(s_deployedConvertibleBondBox.owner());

        uint256 stableAmount = (safeTrancheAmount *
            s_deployedConvertibleBondBox.currentPrice()) /
            s_deployedConvertibleBondBox.s_priceGranularity();

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            safeTrancheAmount
        );

        uint256 borrowerStableBalanceAfterBorrow = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(address(s_borrower));
        uint256 CBBStableBalanceAfterBorrow = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(s_deployedConvertibleBondBox.owner());

        assertEq(
            borrowerStableBalanceBeforeBorrow + stableAmount,
            borrowerStableBalanceAfterBorrow
        );
        assertEq(
            CBBStableBalanceBeforeBorrow - stableAmount,
            CBBStableBalanceAfterBorrow
        );
    }
}
