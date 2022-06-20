pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../convertibleBondBox/CBBSetup.sol";

contract SBSetup is CBBSetup {

    address s_owner; 
    StagingBoxFactory stagingBoxFactory;
    StagingBox s_deployedSB;

    function setUp() public override {
        super.setUp();

        s_owner = address(this);

        StagingBox stagingBox = new StagingBox();
        
        stagingBoxFactory = new StagingBoxFactory(address(stagingBox));
    }
}