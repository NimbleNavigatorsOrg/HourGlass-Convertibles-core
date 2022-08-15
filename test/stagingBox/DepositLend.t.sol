pragma solidity 0.8.13;

import "./integration/SBIntegrationSetup.t.sol";

contract DepositLend is SBIntegrationSetup {
    struct BeforeBalances {
        uint256 lenderLendSlips;
        uint256 routerStableTokens;
        uint256 SBStableTokens;
    }

    struct LendAmounts {
        uint256 stableAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotDepositLendCBBNotReinitialized() public {
        setupStagingBox(0);

        vm.prank(s_deployedSBAddress);
        s_deployedConvertibleBondBox.reinitialize(5);

        bytes memory customError = abi.encodeWithSignature(
            "CBBReinitialized(bool,bool)",
            true,
            false
        );
        vm.expectRevert(customError);
        s_deployedSB.depositLend(s_lender, 1);
    }

    function testDepositLend(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);

        BeforeBalances memory before = BeforeBalances(
            s_lendSlip.balanceOf(s_lender),
            s_stableToken.balanceOf(address(this)),
            s_stableToken.balanceOf(s_deployedSBAddress)
        );

        _lendAmount = bound(_lendAmount, 1, before.routerStableTokens);

        LendAmounts memory adjustments = LendAmounts(_lendAmount);

        vm.expectEmit(true, true, true, true);
        emit LendDeposit(s_lender, _lendAmount);
        s_deployedSB.depositLend(s_lender, _lendAmount);

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
            before.SBStableTokens + adjustments.stableAmount,
            s_stableToken.balanceOf(s_deployedSBAddress)
        );
    }
}
