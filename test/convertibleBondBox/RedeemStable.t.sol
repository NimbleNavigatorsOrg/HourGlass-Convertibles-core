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

        uint256 safeTrancheBalance = IERC20(
            address(s_deployedConvertibleBondBox.safeTranche())
        ).balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeSlipSupply = IERC20(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).totalSupply();

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
}
