pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../convertibleBondBox/CBBSetup.sol";

contract SBSetup is CBBSetup {

    address s_owner; 
    address s_borrower;
    address s_lender;

    StagingBoxFactory stagingBoxFactory;
    StagingBox s_deployedSB;
    event LendDeposit(address, uint256);
    event BorrowDeposit(address, uint256);
    event LendWithdrawal(address, uint256);
    event BorrowWithdrawal(address, uint256);
    event RedeemBorrowSlip(address, uint256);
    event RedeemLendSlip(address, uint256);
    event TrasmitReint(bool, uint256);
    event Initialized(address index, address, address);


    function setUp() public override {
        super.setUp();

        s_owner = address(55);
        s_borrower = address(1);
        s_lender = address(2);

        StagingBox stagingBox = new StagingBox();
        
        stagingBoxFactory = new StagingBoxFactory(address(stagingBox));
    }
}