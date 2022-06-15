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
        address s_initial_borrower = address(1);
        address s_initial_lender = address(2);
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

    
}