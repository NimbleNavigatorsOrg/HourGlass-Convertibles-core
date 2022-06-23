pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract SBTransferOwnership is SBSetup {

    function testTransferOwnership(uint256 price) public {
        address _newOwner = address(99);
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_cbb_owner
        ));

        vm.startPrank(s_cbb_owner);
        s_deployedSB.sbTransferOwnership(_newOwner);
        vm.stopPrank();
        assertEq(_newOwner , s_deployedSB.owner());
    }

    function testFailTransferOwnershipOnlyOwner(uint256 price) public {
        address _newOwner = address(99);
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_cbb_owner
        ));

        s_deployedSB.sbTransferOwnership(_newOwner);
    }
}