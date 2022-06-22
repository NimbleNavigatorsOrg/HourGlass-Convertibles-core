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

        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));
    }

    function testCannotInitialPriceIsZero() public {
        uint256 price = 0;

        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceIsZero(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));
    }

    function testEmitsInitialized(uint256 price) public {
        vm.expectEmit(true, false, false, false);
        emit Initialized(s_owner, address(1), address(2));
        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            s_price,
            s_owner
        ));
    }
}