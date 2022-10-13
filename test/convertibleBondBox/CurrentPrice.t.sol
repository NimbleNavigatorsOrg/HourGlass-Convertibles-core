// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract CurrentPrice is CBBSetup {
    // Table Test Values for Current Price (Needs to be updated whenever s_maturityDate is updated)
    //Spreadsheet: https://docs.google.com/spreadsheets/d/1k5zc9_9qPJHCWKxKF5j6OytEFL3IswSV3QN1MNoz2YI/edit?usp=sharing

    uint256[] public tt_startDate = [
        489827199,
        606555303,
        104592999,
        1533896823,
        1377899531,
        36734092,
        1666337762,
        1137561688,
        1789729815,
        981453647,
        981453647
    ];
    uint256[] public tt_time = [
        629198447,
        1610460106,
        539410349,
        1887611003,
        1508842372,
        801193985,
        1742303050,
        1475102714,
        1838025208,
        1524123256,
        1524123256
    ];
    uint256[] public tt_startPrice = [
        1558048,
        46650009,
        82944222,
        78096736,
        1696215,
        76710019,
        67243873,
        95083541,
        8295194,
        1031966,
        1031966
    ];
    uint256[] public tt_calcPrice = [
        11538497,
        89225632,
        87158135,
        100000000,
        28148811,
        86450946,
        79800107,
        97366373,
        67519045,
        61851177,
        61851177
    ];

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

    function testCurrentPriceTableTest() public {
        uint256 runCount = tt_startDate.length;

        for (uint256 i = 0; i < runCount; i++) {
            vm.warp(tt_startDate[i]);
            address localCBBAddress = s_CBBFactory.createConvertibleBondBox(
                s_buttonWoodBondController,
                s_slipFactory,
                s_penalty,
                address(s_stableToken),
                s_trancheIndex,
                s_cbb_owner
            );

            ConvertibleBondBox localCBB = ConvertibleBondBox(localCBBAddress);

            vm.prank(s_cbb_owner);
            localCBB.reinitialize(tt_startPrice[i]);

            vm.warp(tt_time[i]);

            assertApproxEqAbs(tt_calcPrice[i], localCBB.currentPrice(), 1);
        }
    }

    function testCurrentPriceRevertsBeforeReinitialize() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.currentPrice();
    }
}
