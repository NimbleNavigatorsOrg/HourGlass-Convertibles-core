// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract CurrentPrice is CBBSetup {
    // currentPrice()

    function testCurrentPrice(uint256 time, uint256 startPrice) public {
        startPrice = bound(startPrice, 1, s_priceGranularity - 1);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(startPrice);

        uint256 startDate = s_deployedConvertibleBondBox.s_startDate();
        time = bound(time, startDate, s_endOfUnixTime);
        vm.warp(time);

        uint256 calcPrice;
        if (time < s_maturityDate) {
            calcPrice =
                s_priceGranularity -
                ((s_priceGranularity - startPrice) * (s_maturityDate - time)) /
                (s_maturityDate - startDate);
        } else {
            calcPrice = s_priceGranularity;
        }

        assertEq(calcPrice, s_deployedConvertibleBondBox.currentPrice());
    }
}
