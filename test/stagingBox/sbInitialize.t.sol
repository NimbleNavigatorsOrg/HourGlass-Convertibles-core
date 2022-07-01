pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";

contract sbInitialize is SBIntegrationSetup {

    function testFailInvalidOwnerAddress(uint256 _fuzzPrice) public {
        s_price = bound(_fuzzPrice, 1, s_deployedConvertibleBondBox.s_priceGranularity());
        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_CBBFactory,
            s_slipFactory,
            s_buttonWoodBondController,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            s_price,
            address(0),
            address(0)
        ));
    }

    function testCannotInitialPriceTooHigh(uint256 _fuzzPrice) public {
        s_price = bound(
            _fuzzPrice, 
            s_priceGranularity + 1, 
            type(uint256).max
        );

        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            s_price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_CBBFactory,
            s_slipFactory,
            s_buttonWoodBondController,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            s_price,
            s_owner,
            s_cbb_owner
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
            s_CBBFactory,
            s_slipFactory,
            s_buttonWoodBondController,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            s_price,
            s_owner,
            s_cbb_owner
        ));
    }

    function testEmitsInitialized(uint256 _fuzzPrice) public {
        s_price = bound(_fuzzPrice, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        vm.prank(s_user);
        vm.expectEmit(true, false, false, false);
        emit StagingBoxCreated(ConvertibleBondBox(s_deployedCBBAddress), s_slipFactory, s_price, s_owner, s_user);
        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_CBBFactory,
            s_slipFactory,
            s_buttonWoodBondController,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            s_price,
            s_owner,
            s_cbb_owner
        ));
    }
}