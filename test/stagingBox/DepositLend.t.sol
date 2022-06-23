pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract DepositBorrow is SBSetup {
    function testTransfersStableTokensFromMsgSenderToStagingBox(uint256 price, uint256 lendAmount) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_owner
        ));

        uint256 userStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));
        uint256 sbStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));

        lendAmount = bound(lendAmount, 0, userStableTokenBalanceBeforeLend);

        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(address(s_deployedSB), lendAmount);

        s_deployedSB.depositLend(s_lender, lendAmount);

        uint256 userStableTokenBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));
        uint256 sbStableTokenBalanceAfterLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(s_deployedSB));

        assertEq(userStableTokenBalanceBeforeLend - lendAmount, userStableTokenBalanceAfterLend);
        assertEq(sbStableTokenBalanceBeforeLend + lendAmount, sbStableTokenBalanceAfterLend);
    }

    function testMintsLendSlipsToLender(uint256 _price, uint256 _lendAmount) public {
        _price = bound(_price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            _price,
            s_owner
        ));
        uint256 userStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));
        uint256 lenderLendSlipBalanceBeforeLend = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(s_lender));

        _lendAmount = bound(_lendAmount, 0, userStableTokenBalanceBeforeLend);

        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(address(s_deployedSB), _lendAmount);

        s_deployedSB.depositLend(s_lender, _lendAmount);

        uint256 lenderLendSlipBalanceAfterLend = ISlip(s_deployedSB.s_lendSlipTokenAddress()).balanceOf(address(s_lender));

        assertEq(lenderLendSlipBalanceBeforeLend + _lendAmount, lenderLendSlipBalanceAfterLend);
    }

    function testEmitsLendDeposit(uint256 _price, uint256 _lendAmount) public {
        _price = bound(_price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            _price,
            s_owner
        ));
        uint256 userStableTokenBalanceBeforeLend = IERC20(s_deployedConvertibleBondBox.stableToken()).balanceOf(address(this));

        _lendAmount = bound(_lendAmount, 0, userStableTokenBalanceBeforeLend);
        
        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(address(s_deployedSB), _lendAmount);

        vm.expectEmit(true, true, true, true);
        emit LendDeposit(s_lender, _lendAmount);
        s_deployedSB.depositLend(s_lender, _lendAmount);
    }
}