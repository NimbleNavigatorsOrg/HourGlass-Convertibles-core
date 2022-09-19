pragma solidity 0.8.13;

import "./integration/SBIntegrationSetup.t.sol";

contract sbInitialize is SBIntegrationSetup {
    function testFailInvalidOwnerAddress() public {
        s_deployedSB = StagingBox(
            stagingBoxFactory.createStagingBoxWithCBB(
                s_CBBFactory,
                s_slipFactory,
                s_buttonWoodBondController,
                s_penalty,
                address(s_stableToken),
                s_trancheIndex,
                s_initialPrice,
                address(0)
            )
        );
    }

    function testCannotInitialPriceTooHigh(uint256 _fuzzPrice) public {
        _fuzzPrice = bound(
            _fuzzPrice,
            s_priceGranularity + 1,
            type(uint256).max
        );
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            _fuzzPrice,
            s_priceGranularity
        );
        vm.expectRevert(customError);

        s_deployedSB = StagingBox(
            stagingBoxFactory.createStagingBoxWithCBB(
                s_CBBFactory,
                s_slipFactory,
                s_buttonWoodBondController,
                s_penalty,
                address(s_stableToken),
                s_trancheIndex,
                _fuzzPrice,
                s_cbb_owner
            )
        );
    }

    function testCannotInitialPriceIsZero() public {
        uint256 price = 0;
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceIsZero(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedSB = StagingBox(
            stagingBoxFactory.createStagingBoxWithCBB(
                s_CBBFactory,
                s_slipFactory,
                s_buttonWoodBondController,
                s_penalty,
                address(s_stableToken),
                s_trancheIndex,
                0,
                s_cbb_owner
            )
        );
    }

    function testEmitsInitialized(uint256 _fuzzPrice) public {
        _fuzzPrice = bound(_fuzzPrice, 1, s_priceGranularity);

        vm.startPrank(s_cbb_owner);
        vm.expectEmit(true, true, true, false);
        emit StagingBoxCreated(
            address(this),
            address(0),
            address(s_slipFactory)
        );
        s_deployedSB = StagingBox(
            stagingBoxFactory.createStagingBoxOnly(
                s_slipFactory,
                ConvertibleBondBox(s_deployedCBBAddress),
                _fuzzPrice,
                s_cbb_owner
            )
        );
        vm.stopPrank();
    }
}
