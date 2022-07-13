pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RepayMaxAndUnwrapSimple is RedeemLendSlipsForStablesTestSetup {

    function testRepayMaxAndUnwrapSimpleTransfersStablesFromMsgSender(uint256 _fuzzPrice, uint256 _swtbAmountRaw, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        (uint256 stablesOwed, uint256 borrowRiskSlipBalanceBeforeRepay) = repayMaxAndUnwrapSimpleTestSetup(_swtbAmountRaw, _lendAmount);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowRiskSlipBalanceBeforeRepay
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        assertEq(borrowerStableBalanceBefore - stablesOwed, borrowerStableBalanceAfter);
        assertEq(stagingLoanRouterStableBalanceBefore, stagingLoanRouterStableBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }
}