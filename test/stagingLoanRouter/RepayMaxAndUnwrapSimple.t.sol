pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RepayMaxAndUnwrapSimple is RedeemLendSlipsForStablesTestSetup {

    function testRedeemLendSlipsForStablesTransfersUnderlyingFromMsgSender(uint256 _fuzzPrice, uint256 _swtbAmountRaw, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        (uint256 stablesOwed, uint256 borrowRiskSlipBalanceBeforeRepay)= repayMaxAndUnwrapSimpleTestSetup(_swtbAmountRaw, _lendAmount);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowRiskSlipBalanceBeforeRepay
            );

        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }
}