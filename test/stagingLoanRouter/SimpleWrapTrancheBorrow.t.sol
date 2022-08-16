pragma solidity 0.8.13;

import "./StagingLoanRouterSetup.t.sol";

contract SimpleWrapTrancheBorrow is StagingLoanRouterSetup {
    struct BeforeBalances {
        uint256 borrowerCollateral;
        uint256 borrowerBorrowSlip;
        uint256 SBRiskTranche;
        uint256 SBSafeTranche;
    }

    struct BorrowAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 stableAmount;
    }

    // function testSimpleWrapTrancheBorrowTransfersUnderlyingFromMsgSender(
    //     uint256 _fuzzPrice,
    //     uint256 _amountRaw
    // ) public {
    //     setupStagingBox(_fuzzPrice);
    //     setupTranches(address(s_deployedSB));
    //     _amountRaw = bound(_amountRaw, 1000000, s_maxUnderlyingMint);
    //     (, uint256 minBorrowSlips) = s_stagingBoxLens
    //         .viewSimpleWrapTrancheBorrow(s_deployedSB, _amountRaw);
    //     uint256 userUnderlyingBalanceBefore = s_underlying.balanceOf(s_user);
    //     uint256 loanRouterUnderlyingBalanceBefore = s_underlying.balanceOf(
    //         address(s_stagingLoanRouter)
    //     );
    //     vm.prank(s_user);
    //     StagingLoanRouter(s_stagingLoanRouter).simpleWrapTrancheBorrow(
    //         s_deployedSB,
    //         _amountRaw,
    //         minBorrowSlips
    //     );
    //     uint256 userUnderlyingBalanceAfter = s_underlying.balanceOf(s_user);
    //     uint256 loanRouterUnderlyingBalanceAfter = s_underlying.balanceOf(
    //         address(s_stagingLoanRouter)
    //     );
    //     assertEq(
    //         userUnderlyingBalanceBefore - _amountRaw,
    //         userUnderlyingBalanceAfter
    //     );
    //     assertEq(loanRouterUnderlyingBalanceAfter, 0);
    //     assertEq(
    //         loanRouterUnderlyingBalanceBefore,
    //         loanRouterUnderlyingBalanceAfter
    //     );
    //     assertFalse(_amountRaw == 0);
    // }
    // function testSimpleWrapTrancheBorrowDepositsUnderlyingFromLoanRouterToWrapper(
    //     uint256 _fuzzPrice,
    //     uint256 _amountRaw
    // ) public {
    //     setupStagingBox(_fuzzPrice);
    //     setupTranches(address(s_deployedSB));
    //     _amountRaw = bound(_amountRaw, 1000000, s_maxUnderlyingMint);
    //     (, uint256 minBorrowSlips) = s_stagingBoxLens
    //         .viewSimpleWrapTrancheBorrow(s_deployedSB, _amountRaw);
    //     IConvertibleBondBox convertibleBondBox = s_deployedSB
    //         .convertibleBondBox();
    //     IBondController bond = convertibleBondBox.bond();
    //     IButtonToken wrapper = IButtonToken(bond.collateralToken());
    //     uint256 underlyingWrapperBalanceBefore = s_underlying.balanceOf(
    //         address(wrapper)
    //     );
    //     uint256 loanRouterUnderlyingBalanceBefore = s_underlying.balanceOf(
    //         address(s_stagingLoanRouter)
    //     );
    //     vm.prank(s_user);
    //     StagingLoanRouter(s_stagingLoanRouter).simpleWrapTrancheBorrow(
    //         s_deployedSB,
    //         _amountRaw,
    //         minBorrowSlips
    //     );
    //     uint256 underlyingWrapperBalanceAfter = s_underlying.balanceOf(
    //         address(wrapper)
    //     );
    //     uint256 loanRouterUnderlyingBalanceAfter = s_underlying.balanceOf(
    //         address(s_stagingLoanRouter)
    //     );
    //     assertEq(
    //         underlyingWrapperBalanceBefore + _amountRaw,
    //         underlyingWrapperBalanceAfter
    //     );
    //     assertEq(loanRouterUnderlyingBalanceAfter, 0);
    //     assertEq(
    //         loanRouterUnderlyingBalanceBefore,
    //         loanRouterUnderlyingBalanceAfter
    //     );
    //     assertFalse(_amountRaw == 0);
    // }
    // function testSimpleWrapTrancheBorrowDepositsWrapperFromLoanRouterToBond(
    //     uint256 _fuzzPrice,
    //     uint256 _amountRaw
    // ) public {
    //     setupStagingBox(_fuzzPrice);
    //     setupTranches(address(s_deployedSB));
    //     _amountRaw = bound(_amountRaw, 1000000, s_maxUnderlyingMint);
    //     (, uint256 minBorrowSlips) = s_stagingBoxLens
    //         .viewSimpleWrapTrancheBorrow(s_deployedSB, _amountRaw);
    //     uint256 wrapperTransferAmount = _amountRaw / 200000;
    //     IConvertibleBondBox convertibleBondBox = s_deployedSB
    //         .convertibleBondBox();
    //     IBondController bond = convertibleBondBox.bond();
    //     IButtonToken wrapper = IButtonToken(bond.collateralToken());
    //     uint256 bondWrapperBalanceBefore = wrapper.balanceOf(address(bond));
    //     uint256 loanRouterWrapperBalanceBefore = wrapper.balanceOf(
    //         address(s_stagingLoanRouter)
    //     );
    //     vm.prank(s_user);
    //     StagingLoanRouter(s_stagingLoanRouter).simpleWrapTrancheBorrow(
    //         s_deployedSB,
    //         _amountRaw,
    //         minBorrowSlips
    //     );
    //     uint256 bondWrapperBalanceAfter = wrapper.balanceOf(address(bond));
    //     uint256 loanRouterWrapperBalanceAfter = wrapper.balanceOf(
    //         address(s_stagingLoanRouter)
    //     );
    //     assertEq(
    //         bondWrapperBalanceBefore + wrapperTransferAmount,
    //         bondWrapperBalanceAfter
    //     );
    //     assertEq(loanRouterWrapperBalanceBefore, loanRouterWrapperBalanceAfter);
    //     assertEq(loanRouterWrapperBalanceAfter, 0);
    //     assertFalse(wrapperTransferAmount == 0);
    // }
    // function testCannotSimpleWrapTrancheBorrowSlippageExceeded(
    //     uint256 _fuzzPrice,
    //     uint256 _amountRaw
    // ) public {
    //     setupStagingBox(_fuzzPrice);
    //     setupTranches(address(s_deployedSB));
    //     _amountRaw = bound(_amountRaw, 1000000, s_maxUnderlyingMint);
    //     uint256 wrapperTransferAmount = _amountRaw / 200000;
    //     IConvertibleBondBox convertibleBondBox = s_deployedSB
    //         .convertibleBondBox();
    //     uint256 safeTrancheAmount = (wrapperTransferAmount *
    //         convertibleBondBox.safeRatio()) /
    //         convertibleBondBox.s_trancheGranularity();
    //     uint256 minBorrowSlips = safeTrancheAmount + 1;
    //     assertFalse(safeTrancheAmount >= minBorrowSlips);
    //     vm.prank(s_user);
    //     bytes memory customError = abi.encodeWithSignature(
    //         "SlippageExceeded(uint256,uint256)",
    //         safeTrancheAmount,
    //         minBorrowSlips
    //     );
    //     vm.expectRevert(customError);
    //     StagingLoanRouter(s_stagingLoanRouter).simpleWrapTrancheBorrow(
    //         s_deployedSB,
    //         _amountRaw,
    //         minBorrowSlips
    //     );
    // }
}
