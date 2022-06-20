pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";


contract SBSetup is CBBSetup {

    address s_owner; 
    StagingBox s_deployedSB;

    function stagingSetup() public {
        s_owner = address(this);

        StagingBox stagingBox = new StagingBox(s_owner);
        
        StagingBoxFactory stagingBoxFactory = new StagingBoxFactory(stagingBox);

        s_deployedSB = stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            s_price,
            s_owner
        );
    }
}