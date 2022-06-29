pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";

contract DepositBorrow is SBIntegrationSetup {

    function testSendsSafeTranchesFromMsgSenderToStagingBox(uint256 _fuzzPrice, uint256 _safeTrancheAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));

        uint256 sbSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(s_deployedSB));
        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(s_user);

        _safeTrancheAmount = bound(_safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);

        vm.prank(s_user);
        s_deployedSB.depositBorrow(s_borrower, _safeTrancheAmount);

        uint256 userSafeTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(s_user);
        uint256 sbSafeTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(s_deployedSB));

        assertEq(userSafeTrancheBalanceBeforeDeposit - _safeTrancheAmount, userSafeTrancheBalanceAfterDeposit);
        assertEq(sbSafeTrancheBalanceBeforeDeposit + _safeTrancheAmount, sbSafeTrancheBalanceAfterDeposit);
    }

    function testSendsRiskTranchesFromMsgSenderToStagingBox(uint256 _fuzzPrice, uint256 _safeTrancheAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));

        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(s_user);

        uint256 userRiskTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(s_user);
        uint256 sbRiskTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(s_deployedSB));

        _safeTrancheAmount = bound(_safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);

        uint256 riskTrancheAmount = (_safeTrancheAmount * s_deployedConvertibleBondBox.riskRatio()) / s_deployedConvertibleBondBox.safeRatio();

        ITranche(s_deployedConvertibleBondBox.safeTranche()).approve(address(s_deployedSB), type(uint256).max);
        ITranche(s_deployedConvertibleBondBox.riskTranche()).approve(address(s_deployedSB), type(uint256).max);

        vm.prank(s_user);
        s_deployedSB.depositBorrow(s_borrower, _safeTrancheAmount);

        uint256 userRiskTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(s_user);
        uint256 sbRiskTrancheBalanceAfterDeposit = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(s_deployedSB));

        assertEq(userRiskTrancheBalanceBeforeDeposit - riskTrancheAmount, userRiskTrancheBalanceAfterDeposit);
        assertEq(sbRiskTrancheBalanceBeforeDeposit + riskTrancheAmount, sbRiskTrancheBalanceAfterDeposit);
    }

    function testMintsBorrowSlipsToBorrower(uint256 _fuzzPrice, uint256 _safeTrancheAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));

        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(s_user);
        uint256 borrowerBorrowSlipBalanceBeforeDeposit = ISlip(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(s_borrower);

        _safeTrancheAmount = bound(_safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);

        ITranche(s_deployedConvertibleBondBox.safeTranche()).approve(address(s_deployedSB), type(uint256).max);
        ITranche(s_deployedConvertibleBondBox.riskTranche()).approve(address(s_deployedSB), type(uint256).max);

        vm.prank(s_user);
        s_deployedSB.depositBorrow(s_borrower, _safeTrancheAmount);

        uint256 borrowerBorrowSlipBalanceAfterDeposit = ISlip(s_deployedSB.s_borrowSlipTokenAddress()).balanceOf(s_borrower);

        assertEq(borrowerBorrowSlipBalanceBeforeDeposit + _safeTrancheAmount, borrowerBorrowSlipBalanceAfterDeposit);
    }

    function testEmitsBorrowDeposit(uint256 _fuzzPrice, uint256 _safeTrancheAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        
        uint256 userSafeTrancheBalanceBeforeDeposit = s_deployedConvertibleBondBox.safeTranche().balanceOf(s_user);

        _safeTrancheAmount = bound(_safeTrancheAmount, 0, userSafeTrancheBalanceBeforeDeposit);

        ITranche(s_deployedConvertibleBondBox.safeTranche()).approve(address(s_deployedSB), type(uint256).max);
        ITranche(s_deployedConvertibleBondBox.riskTranche()).approve(address(s_deployedSB), type(uint256).max);

        vm.prank(s_user);
        vm.expectEmit(true, false, false, false);
        emit BorrowDeposit(s_borrower, _safeTrancheAmount);
        s_deployedSB.depositBorrow(s_borrower, _safeTrancheAmount);
    }
}