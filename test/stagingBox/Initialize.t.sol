pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";


contract Initialize is SBSetup {

    function testFailInitializeInvalidOwnerAddress() public {
        stagingSetup();
        s_deployedSB.initialize(address(0));
    }
}