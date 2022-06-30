pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";

contract WithdrawLend is SBIntegrationSetup {

    function withdrawLendMints() private {
        vm.startPrank(address(s_deployedSB));
        ISlip(s_deployedSB.s_lendSlipTokenAddress()).mint(s_user, s_maxMint);
        vm.stopPrank();

        vm.startPrank(address(s_deployedConvertibleBondBox));
        s_stableToken.mint(address(s_deployedSB), s_maxMint);
        vm.stopPrank();
    }

    function testWithdrawLendTransfersStableTokensFromStagingBoxToMsgSender(uint256 _fuzzPrice, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        withdrawLendMints();

        uint256 sbStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(s_user);

        _lendSlipAmount = bound(_lendSlipAmount, 1, sbStableTokenBalanceBeforeWithdraw);

        vm.prank(s_user);
        s_deployedSB.withdrawLend(_lendSlipAmount);

        uint256 msgSenderStableTokenBalanceAfterWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(s_user);

        assertEq(msgSenderStableTokenBalanceBeforeWithdraw + _lendSlipAmount, msgSenderStableTokenBalanceAfterWithdraw);
        assertFalse(_lendSlipAmount == 0);
    }

    function testWithdrawLendBurnsMsgSenderLenderSlips(uint256 _fuzzPrice, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        withdrawLendMints();

        uint256 sbStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));
        uint256 msgSenderLendSlipBalanceBeforeWithdraw  = IERC20(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(s_user);

        _lendSlipAmount = bound(_lendSlipAmount, 1, sbStableTokenBalanceBeforeWithdraw);

        vm.prank(s_user);
        s_deployedSB.withdrawLend(_lendSlipAmount);

        uint256 msgSenderLendSlipBalanceAfterWithdraw  = IERC20(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(s_user);

        assertEq(msgSenderLendSlipBalanceBeforeWithdraw - _lendSlipAmount, msgSenderLendSlipBalanceAfterWithdraw);
        assertFalse(_lendSlipAmount == 0);
    }

    function testWithdrawLendEmitsLendWithdraw(uint256 _fuzzPrice, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));
        withdrawLendMints();

        uint256 sbStableTokenBalanceBeforeWithdraw  = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));

        _lendSlipAmount = bound(_lendSlipAmount, 1, sbStableTokenBalanceBeforeWithdraw);

        vm.prank(s_user);
        vm.expectEmit(true, true, true, true);
        emit LendWithdrawal(s_user, _lendSlipAmount);
        s_deployedSB.withdrawLend(_lendSlipAmount);

        assertFalse(_lendSlipAmount == 0);
    }
}