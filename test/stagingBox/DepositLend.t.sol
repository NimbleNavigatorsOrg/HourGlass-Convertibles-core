pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./integration/SBIntegrationSetup.t.sol";

contract DepositLend is SBIntegrationSetup {
    function testTransfersStableTokensFromMsgSenderToStagingBox(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));

        uint256 userStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(s_user);
        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));

        _lendAmount = bound(_lendAmount, 1, userStableTokenBalanceBeforeLend);

        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(address(s_deployedSB), _lendAmount);

        vm.prank(s_user);
        s_deployedSB.depositLend(s_lender, _lendAmount);

        uint256 userStableTokenBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(s_user);
        uint256 sbStableTokenBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));

        assertEq(userStableTokenBalanceBeforeLend - _lendAmount, userStableTokenBalanceAfterLend);
        assertEq(sbStableTokenBalanceBeforeLend + _lendAmount, sbStableTokenBalanceAfterLend);

        assertFalse(_lendAmount == 0);
    }

    function testMintsLendSlipsToLender(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));

        uint256 userStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(s_user);
        uint256 lenderLendSlipBalanceBeforeLend = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(s_lender));

        _lendAmount = bound(_lendAmount, 1, userStableTokenBalanceBeforeLend);

        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(address(s_deployedSB), _lendAmount);

        vm.prank(s_user);
        s_deployedSB.depositLend(s_lender, _lendAmount);

        uint256 lenderLendSlipBalanceAfterLend = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(s_lender));

        assertEq(lenderLendSlipBalanceBeforeLend + _lendAmount, lenderLendSlipBalanceAfterLend);

        assertFalse(_lendAmount == 0);
    }

    function testEmitsLendDeposit(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(true, s_user, address(s_deployedSB));

        uint256 userStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(s_user);

        _lendAmount = bound(_lendAmount, 1, userStableTokenBalanceBeforeLend);
        
        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(address(s_deployedSB), _lendAmount);

        vm.prank(s_user);
        vm.expectEmit(true, true, true, true);
        emit LendDeposit(s_lender, _lendAmount);
        s_deployedSB.depositLend(s_lender, _lendAmount);

        assertFalse(_lendAmount == 0);
    }
}