pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RedeemLendSlipsForStables is RedeemLendSlipsForStablesTestSetup {
    function testRedeemLendSlipsForStablesTransfersLendSlipsFromMsgSender(
        uint256 _fuzzPrice,
        uint256 _lendAmount,
        uint256 _timeWarp,
        uint256 _lendSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (
            uint256 borrowRiskSlipBalanceBeforeRepay,
            uint256 lendAmount
        ) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        (
            uint256 safeSlipAmount,
            uint256 lendSlipAmount
        ) = redeemLendSlipsForStablesTestSetup(
                _timeWarp,
                borrowRiskSlipBalanceBeforeRepay,
                _lendSlipAmount
            );

        uint256 lenderLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip())
            .balanceOf(address(s_lender));

        vm.prank(s_lender);
        StagingLoanRouter(s_stagingLoanRouter).redeemLendSlipsForStables(
            s_deployedSB,
            lendSlipAmount
        );

        uint256 lenderLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip())
            .balanceOf(address(s_lender));

        assertEq(
            lenderLendSlipBalanceBefore - lendSlipAmount,
            lenderLendSlipBalanceAfter
        );
        assertFalse(lendSlipAmount == 0);
    }

    function testRedeemLendSlipsForStablesTransfersStablesFromRouterToMsgSender(
        uint256 _fuzzPrice,
        uint256 _lendAmount,
        uint256 _timeWarp,
        uint256 _lendSlipAmount
    ) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (
            uint256 borrowRiskSlipBalanceBeforeRepay,
            uint256 lendAmount
        ) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        (
            uint256 safeSlipAmount,
            uint256 lendSlipAmount
        ) = redeemLendSlipsForStablesTestSetup(
                _timeWarp,
                borrowRiskSlipBalanceBeforeRepay,
                _lendSlipAmount
            );

        uint256 lenderStableBalanceBefore = s_stableToken.balanceOf(
            address(s_lender)
        );
        uint256 cbbStableBalanceBefore = s_stableToken.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        vm.prank(s_lender);
        StagingLoanRouter(s_stagingLoanRouter).redeemLendSlipsForStables(
            s_deployedSB,
            lendSlipAmount
        );

        uint256 lenderStableBalanceAfter = s_stableToken.balanceOf(
            address(s_lender)
        );
        uint256 cbbStableBalanceAfter = s_stableToken.balanceOf(
            address(s_deployedConvertibleBondBox)
        );

        assertEq(
            lenderStableBalanceBefore + safeSlipAmount,
            lenderStableBalanceAfter
        );
        assertEq(
            cbbStableBalanceBefore - safeSlipAmount,
            cbbStableBalanceAfter
        );
        assertFalse(safeSlipAmount == 0);
    }
}
