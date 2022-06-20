pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";


contract sbInitialize is SBSetup {

    function testFailInvalidOwnerAddress() public {
        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            s_price,
            address(0)
        ));
    }

    function testCannotInitialPriceTooHigh(uint256 price) public {
        uint256 price = bound(
            price, 
            s_deployedConvertibleBondBox.s_priceGranularity() + 1, 
            type(uint256).max
        );
        
        // s_owner = address(this);

        // StagingBox stagingBox = new StagingBox();
        
        // StagingBoxFactory stagingBoxFactory = new StagingBoxFactory(address(stagingBox));

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            s_deployedSB.initialPrice(),
            s_deployedSB.priceGranularity()
        );
        vm.expectRevert(customError);
        s_deployedSB.initialize(address(this));
    }
}