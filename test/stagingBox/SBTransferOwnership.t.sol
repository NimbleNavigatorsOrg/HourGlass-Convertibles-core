pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";

contract SBTransferOwnership is SBIntegrationSetup {

    function testTransferOwnership(uint256 _fuzzPrice) public {
        setupStagingBox(_fuzzPrice);
        address newOwner = address(99);

        vm.startPrank(s_cbb_owner);
        s_deployedSB.sbTransferOwnership(newOwner);
        vm.stopPrank();
        assertEq(newOwner , s_deployedSB.owner());
    }

    function testFailTransferOwnershipOnlyOwner(uint256 _fuzzPrice) public {
        setupStagingBox(_fuzzPrice);
        address newOwner = address(99);

        s_deployedSB.sbTransferOwnership(newOwner);
    }
}