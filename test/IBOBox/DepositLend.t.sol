pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract DepositLend is iboBoxSetup {
    struct BeforeBalances {
        uint256 lenderLendSlips;
        uint256 routerStableTokens;
        uint256 IBOStableTokens;
    }

    struct LendAmounts {
        uint256 stableAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotDepositLendCBBNotActivated() public {
        setupIBOBox(0);

        vm.prank(s_deployedIBOBAddress);
        s_deployedConvertibleBondBox.activate(5);

        bytes memory customError = abi.encodeWithSignature(
            "CBBActivated(bool,bool)",
            true,
            false
        );
        vm.expectRevert(customError);
        s_deployedIBOB.depositLend(s_lender, 1);
    }

    function testDepositLend(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupIBOBox(_fuzzPrice);

        BeforeBalances memory before = BeforeBalances(
            s_lendSlip.balanceOf(s_lender),
            s_stableToken.balanceOf(address(this)),
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );

        _lendAmount = bound(_lendAmount, 1, before.routerStableTokens);

        LendAmounts memory adjustments = LendAmounts(_lendAmount);

        vm.expectEmit(true, true, true, true);
        emit LendDeposit(s_lender, _lendAmount);
        s_deployedIBOB.depositLend(s_lender, _lendAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        LendAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderLendSlips + adjustments.stableAmount,
            s_lendSlip.balanceOf(s_lender)
        );

        assertEq(
            before.routerStableTokens - adjustments.stableAmount,
            s_stableToken.balanceOf(address(this))
        );

        assertEq(
            before.IBOStableTokens + adjustments.stableAmount,
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );
    }
}
