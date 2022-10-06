// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract RedeemStable is CBBSetup {
    struct BeforeBalances {
        uint256 lenderBondSlip;
        uint256 lenderStableTokens;
        uint256 ownerBondSlip;
        uint256 CBBStableTokens;
        uint256 repaidBondSlips;
    }

    struct RedeemAmounts {
        uint256 feeSlip;
        uint256 bondSlipAmount;
        uint256 stableAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function initialSetup() internal {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        uint256 stablesToTranches = (s_stableToken.balanceOf(address(this)) *
            s_deployedConvertibleBondBox.s_priceGranularity() *
            s_deployedConvertibleBondBox.trancheDecimals()) /
            s_deployedConvertibleBondBox.currentPrice() /
            s_deployedConvertibleBondBox.stableDecimals();

        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            Math.min(s_safeTranche.balanceOf(address(this)), stablesToTranches)
        );
    }

    function testRedeemStableMinimumInput(uint256 bondSlipAmount) public {
        initialSetup();
        bondSlipAmount = bound(bondSlipAmount, 0, 1e6 - 1);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            bondSlipAmount,
            1e6
        );
        vm.prank(s_lender);
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemStable(bondSlipAmount);
    }

    function testRedeemStable(
        uint256 time,
        uint256 fee,
        uint256 bondSlipAmount
    ) public {
        initialSetup();

        fee = bound(fee, 0, s_maxFeeBPS);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.setFee(fee);

        s_stableToken.mint(
            s_borrower,
            (s_bondSlip.balanceOf(s_lender) * (10**s_stableDecimals)) /
                (10**s_collateralDecimals)
        );

        time = bound(time, block.timestamp, s_endOfUnixTime);

        vm.warp(time);

        vm.startPrank(s_borrower);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        s_deployedConvertibleBondBox.repayMax(s_debtSlip.balanceOf(s_borrower));
        vm.stopPrank();

        BeforeBalances memory before = BeforeBalances(
            s_bondSlip.balanceOf(s_lender),
            s_stableToken.balanceOf(s_lender),
            s_bondSlip.balanceOf(s_cbb_owner),
            s_stableToken.balanceOf(s_deployedCBBAddress),
            s_deployedConvertibleBondBox.s_repaidBondSlips()
        );

        bondSlipAmount = bound(
            bondSlipAmount,
            1e6,
            s_deployedConvertibleBondBox.s_repaidBondSlips()
        );

        uint256 feeSlip = (bondSlipAmount * fee) / s_BPS;

        uint256 stablePayout = ((bondSlipAmount - feeSlip) *
            before.CBBStableTokens) /
            s_deployedConvertibleBondBox.s_repaidBondSlips();

        RedeemAmounts memory adjustments = RedeemAmounts(
            feeSlip,
            bondSlipAmount,
            stablePayout
        );

        vm.startPrank(s_lender);
        s_bondSlip.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit RedeemStable(
            s_lender,
            bondSlipAmount - feeSlip,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.redeemStable(bondSlipAmount);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderBondSlip - adjustments.bondSlipAmount,
            s_bondSlip.balanceOf(s_lender)
        );

        assertEq(
            before.lenderStableTokens + adjustments.stableAmount,
            s_stableToken.balanceOf(s_lender)
        );

        assertEq(
            before.ownerBondSlip + adjustments.feeSlip,
            s_bondSlip.balanceOf(s_cbb_owner)
        );

        assertEq(
            before.CBBStableTokens - adjustments.stableAmount,
            s_stableToken.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.repaidBondSlips -
                adjustments.bondSlipAmount +
                adjustments.feeSlip,
            s_deployedConvertibleBondBox.s_repaidBondSlips()
        );
    }
}
