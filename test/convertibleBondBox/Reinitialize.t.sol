// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract Reinitialize is CBBSetup {
    function testFailReinitializeNotOwner() public {
        vm.prank(address(1));
        s_deployedConvertibleBondBox.reinitialize(s_initialPrice);
    }

    function testCannotReinitializeInitialPriceTooHigh(uint256 price) public {
        price = bound(price, s_priceGranularity + 1, type(uint256).max);

        vm.prank(s_cbb_owner);
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.reinitialize(price);
    }

    function testCannotReinitializeInitialPriceIsZero() public {
        vm.prank(s_cbb_owner);
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceIsZero(uint256,uint256)",
            0,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.reinitialize(0);
    }

    function testCannotReinitializeBondIsMature(uint256 time) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);

        vm.warp(time);

        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(uint256,uint256)",
            time,
            s_maturityDate
        );

        vm.prank(s_cbb_owner);
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.reinitialize(s_initialPrice);
    }

    function testReinitialize(uint256 time, uint256 startPrice) public {
        time = bound(time, block.timestamp, s_maturityDate);
        startPrice = bound(startPrice, 1, s_priceGranularity);

        vm.warp(time);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(startPrice);

        assertEq(s_deployedConvertibleBondBox.s_startDate(), time);
        assertEq(s_deployedConvertibleBondBox.s_initialPrice(), startPrice);
    }
}
