pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./StagingLoanRouterSetup.t.sol";


import "forge-std/console2.sol";

contract FetchElasticStack is Test, StagingLoanRouter, StagingLoanRouterSetup {

    function testSimpleWrapTrancheBorrow(uint256 _fuzzPrice) public {
        console.log("test start");
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        console.log("after setup");
        StagingLoanRouter stagingLoanRouter = new StagingLoanRouter();
        
        vm.prank(s_user);
        s_underlying.approve(address(stagingLoanRouter), type(uint256).max);

        console.log(s_underlying.balanceOf(s_user), "s_underlying.balanceOf(s_user)");
        vm.prank(s_user);
        IStagingLoanRouter(stagingLoanRouter).simpleWrapTrancheBorrow(s_deployedSB, 1000000, 1);
    }
}