pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RedeemLendSlipsForStables is RedeemLendSlipsForStablesTestSetup {

    function testRedeemLendSlipsForStablesTransfersUnderlyingFromMsgSender(uint256 _fuzzPrice, uint256 _swtbAmountRaw, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        _swtbAmountRaw = bound(_swtbAmountRaw, 1000000, s_maxUnderlyingMint);
        (, uint256 minBorrowSlips) = s_stagingBoxLens.viewSimpleWrapTrancheBorrow(s_deployedSB, _swtbAmountRaw);

        uint256 borrowerBorrowSlipBalanceBeforeSWTB = ISlip(s_deployedSB.borrowSlip()).balanceOf(s_borrower);

        console.log(_swtbAmountRaw, "_swtbAmountRaw");
        console.log(borrowerBorrowSlipBalanceBeforeSWTB, "borrowerBorrowSlipBalanceBeforeSWTB");

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).simpleWrapTrancheBorrow(s_deployedSB, _swtbAmountRaw, minBorrowSlips);
        
        uint256 borrowerBorrowSlipBalanceAfterSWTB = ISlip(s_deployedSB.borrowSlip()).balanceOf(s_borrower);

        console.log(borrowerBorrowSlipBalanceAfterSWTB, "borrowerBorrowSlipBalanceAfterSWTB");

        assertFalse(_swtbAmountRaw == 0);

        uint256 userStableTokenBalanceBeforeLend = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(s_user);

        _lendAmount = bound(_lendAmount, 
        (s_deployedConvertibleBondBox.safeRatio() * s_deployedConvertibleBondBox.currentPrice()) 
        / s_deployedConvertibleBondBox.s_priceGranularity(), 
        userStableTokenBalanceBeforeLend);

        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(
            address(s_deployedSB),
            _lendAmount
        );

        vm.prank(s_user);
        s_deployedSB.depositLend(s_lender, _lendAmount);

        assertFalse(_lendAmount == 0);

        uint256 sbStableTokenBalanceBeforeTrans = s_stableToken.balanceOf(address(s_owner));

        vm.prank(s_owner);
        s_deployedSB.transmitReInit(true);

        uint256 borrowerBorrowSlipBalanceBeforeRedeem = ISlip(s_deployedSB.borrowSlip()).balanceOf(s_borrower);
        console.log(borrowerBorrowSlipBalanceBeforeRedeem, "borrowerBorrowSlipBalanceBeforeRedeem");

        uint256 sbRiskSlipBalanceBeforeRedeem = ISlip(riskSlipAddress()).balanceOf(address(s_deployedSB));

        uint256 calculatedRiskSlipReturn = (borrowerBorrowSlipBalanceBeforeRedeem * s_deployedSB.riskRatio()) / s_deployedSB.safeRatio();
        console.log(calculatedRiskSlipReturn, "calculatedRiskSlipReturn");
        console.log(sbRiskSlipBalanceBeforeRedeem, "sbRiskSlipBalanceBeforeRedeem");

        uint256 sbRiskSlipBalanceBeforeRedeem

        if(calculatedRiskSlipReturn <= sbRiskSlipBalanceBeforeRedeem) {
            vm.prank(s_borrower);
            s_deployedSB.redeemBorrowSlip(borrowerBorrowSlipBalanceBeforeRedeem);
        } else {
            vm.prank(s_borrower);
            s_deployedSB.redeemBorrowSlip(borrowerBorrowSlipBalanceBeforeRedeem);
        }
        


        uint256 borrowerBorrowSlipBalanceAfterRedeem = ISlip(s_deployedSB.borrowSlip()).balanceOf(s_borrower);
        console.log(borrowerBorrowSlipBalanceAfterRedeem, "borrowerBorrowSlipBalanceAfterRedeem");



        //TODO below code is for reference delete soon bear.
        console2.log(ISlip(riskSlipAddress()).balanceOf(address(this)), " riskSlipAddress().balanceOf(address(this))");

        TransferHelper.safeTransfer(
            riskSlipAddress(),
            _msgSender(),
            (_borrowSlipAmount * riskRatio()) / safeRatio()
        );



        uint256 sbStableTokenBalanceBeforeRepay = s_stableToken.balanceOf(address(s_owner));
        uint256 borrowRiskSlipBalanceBeforeRepay = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        s_stableToken.mint(s_borrower, s_maxMint);

        StagingBoxLens s_deployedLens = new StagingBoxLens();

        // (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = IStagingBoxLens(s_deployedLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        // vm.prank(s_borrower);
        // StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
        //     s_deployedSB, 
        //     stablesOwed,
        //     borrowRiskSlipBalanceBeforeRepay
        //     );


        vm.warp(s_deployedConvertibleBondBox.maturityDate());

    }
}