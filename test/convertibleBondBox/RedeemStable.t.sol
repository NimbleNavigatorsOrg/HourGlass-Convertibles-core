// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/CBBSlip.sol";
import "../../src/contracts/CBBSlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract RedeemStable is CBBSetup {
    // testFail for redeemStable before any repay function

    // redeemStable()

    function testRedeemStable(uint256 safeSlipAmount) public {
        // initializing the CBB
        vm.prank(address(this));
        emit Initialized(address(1), address(2), 0, s_depositLimit);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );

        //getting lender + borrower balances after initialization deposit
        uint256 userSafeSlipBalanceBeforeRedeem = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));

        uint256 userStableBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(2));

        uint256 repayAmount = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(1));

        //borrower repays full amount immediately
        vm.startPrank(address(1));
        s_stableToken.approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        IERC20(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.repay(repayAmount);
        vm.stopPrank();

        safeSlipAmount = bound(
            safeSlipAmount,
            s_safeRatio,
            IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress())
                .balanceOf(address(2))
        );

        console2.log(
            IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress())
                .balanceOf(address(2)),
            "upperBound"
        );

        console2.log(safeSlipAmount, "afterBound");

        uint256 CBBStableBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(s_deployedConvertibleBondBox));

        uint256 repaidSafeSlips = s_deployedConvertibleBondBox
            .s_repaidSafeSlips();

        uint256 stableTransferAmount = (safeSlipAmount *
            CBBStableBalanceBeforeRedeem) / (repaidSafeSlips);

        // lender redeems stable
        vm.startPrank(address(2));

        IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        vm.expectEmit(true, true, true, true);
        emit RedeemStable(
            address(2),
            safeSlipAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);

        vm.stopPrank();

        uint256 userSafeSlipBalanceAfterRedeem = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));
        uint256 userStableBalanceAfterRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(2));
        uint256 CBBStableBalanceAfterRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(
            userSafeSlipBalanceBeforeRedeem - safeSlipAmount,
            userSafeSlipBalanceAfterRedeem
        );
        assertEq(
            userStableBalanceBeforeRedeem + stableTransferAmount,
            userStableBalanceAfterRedeem
        );
        assertEq(
            CBBStableBalanceBeforeRedeem - stableTransferAmount,
            CBBStableBalanceAfterRedeem
        );
    }

    function testCannotRedeemStableConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemStable(s_safeSlipAmount);
    }

    function testCannotRedeemStableMinimumInput(uint time, uint256 safeSlipAmount) public {
        time = bound(time, 1, s_maturityDate - 1);
        vm.warp(time);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            0,
            0
        );

        safeSlipAmount = bound(safeSlipAmount, 0, s_deployedConvertibleBondBox.safeRatio() - 1);
        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            safeSlipAmount,
            s_deployedConvertibleBondBox.safeRatio()
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);
    }

    function redeemStableSetup(
    uint256 time,     
    uint256 depositAmount,
    uint256 fee,
    uint256 repayAmount,
    uint256 safeSlipAmount,
    address borrower,
    address lender) private returns(uint256) {
        depositAmount = bound(depositAmount, 
        400,
        s_safeTranche.balanceOf(address(this)));

        time = bound(time, 1, s_endOfUnixTime);
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.warp(time);

        s_deployedConvertibleBondBox.reinitialize(
            borrower,
            lender,
            depositAmount,
            0
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        repayAmount = bound(repayAmount,
         s_deployedConvertibleBondBox.safeRatio(),
         IERC20(address(s_deployedConvertibleBondBox.stableToken())).balanceOf(borrower));

        vm.startPrank(borrower);
        s_stableToken.approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        IERC20(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.repay(repayAmount);
        vm.stopPrank();

        safeSlipAmount = bound(
            safeSlipAmount, s_deployedConvertibleBondBox.safeRatio(), 
            IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedConvertibleBondBox))
            );

            return safeSlipAmount;
    }

function testRedeemStableSendsSafeSlipFeesToOwner(
    uint256 time, 
    uint256 depositAmount,
    uint256 fee,
    uint256 repayAmount,
    uint256 safeSlipAmount) public {
        address borrower = address(1);
        address lender = address(2);

        safeSlipAmount = redeemStableSetup(time, depositAmount, fee, repayAmount, safeSlipAmount, borrower, lender);

        uint256 feeSlipAmount = (safeSlipAmount * s_deployedConvertibleBondBox.feeBps()) / s_BPS;
        uint256 ownerSafeSlipBalanceBeforeRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(s_deployedConvertibleBondBox.owner());

        vm.startPrank(lender);
        IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);
        vm.stopPrank();

        uint256 ownerSafeSlipBalanceAfterRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(s_deployedConvertibleBondBox.owner());

        assertEq(ownerSafeSlipBalanceBeforeRedeem + feeSlipAmount, ownerSafeSlipBalanceAfterRedeem);
    }

    function testRedeemStableBurnsMsgSenderSafeSlips(
    uint time, 
    uint256 depositAmount,
    uint256 fee,
    uint256 repayAmount,
    uint256 safeSlipAmount) public {
        address borrower = address(1);
        address lender = address(2);

        safeSlipAmount = redeemStableSetup(time, depositAmount, fee, repayAmount, safeSlipAmount, borrower, lender);

        uint256 lenderSafeSlipBalanceBeforeRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(lender);

        vm.startPrank(lender);
        IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);
        vm.stopPrank();

        uint256 lenderSafeSlipBalanceAfterRedeem = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(lender);

        assertEq(lenderSafeSlipBalanceBeforeRedeem - safeSlipAmount, lenderSafeSlipBalanceAfterRedeem);
    }

    function testRedeemStableSendsStableTokensToMsgSenderFromCBB(
        uint time, 
        uint256 depositAmount,
        uint256 fee,
        uint256 repayAmount,
        uint256 safeSlipAmount
        ) public {
            address borrower = address(1);
            address lender = address(2);

            safeSlipAmount = redeemStableSetup(time, depositAmount, fee, repayAmount, safeSlipAmount, borrower, lender);

            uint256 feeSlipAmount = (safeSlipAmount * s_deployedConvertibleBondBox.feeBps()) / s_BPS;
            uint256 SafeSlipAmountMinusFee = safeSlipAmount - feeSlipAmount;

            uint256 CBBStableSlipBalanceBeforeRedeem = IERC20(s_stableToken).balanceOf(address(s_deployedConvertibleBondBox));
            uint256 lenderStableSlipBalanceBeforeRedeem = IERC20(s_stableToken).balanceOf(lender);

            uint256 StableAmountToSend = (SafeSlipAmountMinusFee * CBBStableSlipBalanceBeforeRedeem) / s_deployedConvertibleBondBox.s_repaidSafeSlips();

            vm.startPrank(lender);
            IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);
            vm.stopPrank();

            uint256 lenderStableSlipBalanceAfterRedeem = IERC20(s_stableToken).balanceOf(lender);
            uint256 CBBStableSlipBalanceAfterRedeem = IERC20(s_stableToken).balanceOf(address(s_deployedConvertibleBondBox));

            assertEq(CBBStableSlipBalanceBeforeRedeem - StableAmountToSend, CBBStableSlipBalanceAfterRedeem);
            assertEq(lenderStableSlipBalanceBeforeRedeem + StableAmountToSend, lenderStableSlipBalanceAfterRedeem);
        }

        function testRedeemStableEmitsRedeemStable(
        uint time, 
        uint256 depositAmount,
        uint256 fee,
        uint256 repayAmount,
        uint256 safeSlipAmount
        ) public {
            address borrower = address(1);
            address lender = address(2);

            safeSlipAmount = redeemStableSetup(time, depositAmount, fee, repayAmount, safeSlipAmount, borrower, lender);

            uint256 feeSlipAmount = (safeSlipAmount * s_deployedConvertibleBondBox.feeBps()) / s_BPS;
            uint256 SafeSlipAmountMinusFee = safeSlipAmount - feeSlipAmount;

            vm.startPrank(lender);
            IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            vm.expectEmit(true, true, true, true);
            emit RedeemStable(
                lender,
                SafeSlipAmountMinusFee,
                s_deployedConvertibleBondBox.currentPrice()
            );
            s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);
            vm.stopPrank();
        }
}
