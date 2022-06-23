pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract DepositBorrow is SBSetup {

    function testSendsSafeTranchesFromMsgSenderToStagingBox(uint256 price, uint256 safeTrancheAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(this));
        uint256 sbSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(s_deployedSB));

        safeTrancheAmount = bound(safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);
        ITranche(s_deployedConvertibleBondBox.safeTranche()).approve(address(s_deployedSB), type(uint256).max);
        ITranche(s_deployedConvertibleBondBox.riskTranche()).approve(address(s_deployedSB), type(uint256).max);

        s_deployedSB.depositBorrow(s_borrower, safeTrancheAmount);

        uint256 userSafeTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(this));
        uint256 sbSafeTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(s_deployedSB));

        assertEq(userSafeTrancheBalanceBeforeDeposit - safeTrancheAmount, userSafeTrancheBalanceAfterDeposit);
        assertEq(sbSafeTrancheBalanceBeforeDeposit + safeTrancheAmount, sbSafeTrancheBalanceAfterDeposit);
    }

    function testSendsRiskTranchesFromMsgSenderToStagingBox(uint256 price, uint256 safeTrancheAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(this));

        uint256 userRiskTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(this));
        uint256 sbRiskTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(s_deployedSB));

        safeTrancheAmount = bound(safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);

        uint256 riskTrancheAmount = (safeTrancheAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

        ITranche(s_deployedConvertibleBondBox.safeTranche()).approve(address(s_deployedSB), type(uint256).max);
        ITranche(s_deployedConvertibleBondBox.riskTranche()).approve(address(s_deployedSB), type(uint256).max);

        s_deployedSB.depositBorrow(s_borrower, safeTrancheAmount);

        uint256 userRiskTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(this));
        uint256 sbRiskTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(s_deployedSB));

        assertEq(userRiskTrancheBalanceBeforeDeposit - riskTrancheAmount, userRiskTrancheBalanceAfterDeposit);
        assertEq(sbRiskTrancheBalanceBeforeDeposit + riskTrancheAmount, sbRiskTrancheBalanceAfterDeposit);
    }

        function testMintsBorrowSlipsToBorrower(uint256 price, uint256 safeTrancheAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(this));
        uint256 borrowerBorrowSlipBalanceBeforeDeposit = ISlip(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(s_borrower);

        safeTrancheAmount = bound(safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);

        ITranche(s_deployedConvertibleBondBox.safeTranche()).approve(address(s_deployedSB), type(uint256).max);
        ITranche(s_deployedConvertibleBondBox.riskTranche()).approve(address(s_deployedSB), type(uint256).max);

        s_deployedSB.depositBorrow(s_borrower, safeTrancheAmount);

        uint256 borrowerBorrowSlipBalanceAfterDeposit = ISlip(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(s_borrower);

        assertEq(borrowerBorrowSlipBalanceBeforeDeposit + safeTrancheAmount, borrowerBorrowSlipBalanceAfterDeposit);
    }

    function testEmitsBorrowDeposit(uint256 price, uint256 safeTrancheAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(this));

        safeTrancheAmount = bound(safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);

        ITranche(s_deployedConvertibleBondBox.safeTranche()).approve(address(s_deployedSB), type(uint256).max);
        ITranche(s_deployedConvertibleBondBox.riskTranche()).approve(address(s_deployedSB), type(uint256).max);

        vm.expectEmit(true, false, false, false);
        emit BorrowDeposit(s_borrower, safeTrancheAmount);
        s_deployedSB.depositBorrow(s_borrower, safeTrancheAmount);
    }
}