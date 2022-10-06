pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract CreateBuyOrder is iboBoxSetup {
    struct BeforeBalances {
        uint256 lenderBuyOrders;
        uint256 routerStableTokens;
        uint256 IBOStableTokens;
    }

    struct LendAmounts {
        uint256 stableAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotCreateBuyOrderCBBNotActivated() public {
        setupIBOBox(0);

        vm.prank(s_deployedIBOBAddress);
        s_deployedConvertibleBondBox.activate(5);

        bytes memory customError = abi.encodeWithSignature(
            "CBBActivated(bool,bool)",
            true,
            false
        );
        vm.expectRevert(customError);
        s_deployedIBOB.createBuyOrder(s_lender, 1);
    }

    function testCreateBuyOrder(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupIBOBox(_fuzzPrice);

        BeforeBalances memory before = BeforeBalances(
            s_buyOrder.balanceOf(s_lender),
            s_stableToken.balanceOf(address(this)),
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );

        _lendAmount = bound(_lendAmount, 1, before.routerStableTokens);

        LendAmounts memory adjustments = LendAmounts(_lendAmount);

        vm.expectEmit(true, true, true, true);
        emit BuyOrderCreated(s_lender, _lendAmount);
        s_deployedIBOB.createBuyOrder(s_lender, _lendAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        LendAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderBuyOrders + adjustments.stableAmount,
            s_buyOrder.balanceOf(s_lender)
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
