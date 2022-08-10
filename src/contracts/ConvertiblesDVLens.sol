// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IConvertiblesDVLens.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract ConvertiblesDVLens is IConvertiblesDVLens {
    function viewStagingStatsIBO(IStagingBox _stagingBox)
        external
        view
        returns (StagingDataIBO memory)
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond
        ) = fetchElasticStack(_stagingBox);
        (
            uint256 safeTrancheCollateral,
            uint256 riskTrancheCollateral
        ) = calcTrancheCollateral(
                convertibleBondBox,
                bond,
                _stagingBox.safeTranche().balanceOf(address(_stagingBox)),
                _stagingBox.riskTranche().balanceOf(address(_stagingBox))
            );
        uint256 stableBalance = _stagingBox.stableToken().balanceOf(
            address(_stagingBox)
        );
        uint256 trancheDecimals = 10 **
            ERC20(address(_stagingBox.safeTranche())).decimals();
        uint256 stableDecimals = 10 **
            ERC20(address(_stagingBox.stableToken())).decimals();

        StagingDataIBO memory data = StagingDataIBO(
            NumFixedPoint(
                _stagingBox.lendSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _stagingBox.borrowSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _stagingBox.safeTranche().balanceOf(address(_stagingBox)),
                trancheDecimals
            ),
            NumFixedPoint(
                _stagingBox.riskTranche().balanceOf(address(_stagingBox)),
                trancheDecimals
            ),
            NumFixedPoint(safeTrancheCollateral, trancheDecimals),
            NumFixedPoint(riskTrancheCollateral, trancheDecimals),
            NumFixedPoint(stableBalance, stableDecimals),
            NumFixedPoint(
                (safeTrancheCollateral + riskTrancheCollateral) *
                    stableDecimals +
                    stableBalance *
                    trancheDecimals,
                trancheDecimals * stableDecimals
            ),
            NumFixedPoint(stableBalance, stableDecimals)
        );

        return data;
    }

    function viewStagingStatsActive(IStagingBox _stagingBox)
        external
        view
        returns (StagingDataActive memory)
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond
        ) = fetchElasticStack(_stagingBox);
        (
            uint256 safeTrancheCollateral,
            uint256 riskTrancheCollateral
        ) = calcTrancheCollateral(
                convertibleBondBox,
                bond,
                _stagingBox.safeTranche().balanceOf(address(_stagingBox)),
                _stagingBox.riskTranche().balanceOf(address(_stagingBox))
            );
        uint256 stableBalance = _stagingBox.stableToken().balanceOf(
            address(_stagingBox)
        );

        uint256 trancheDecimals = 10 **
            ERC20(address(_stagingBox.safeTranche())).decimals();
        uint256 stableDecimals = 10 **
            ERC20(address(_stagingBox.stableToken())).decimals();

        StagingDataActive memory data = StagingDataActive(
            NumFixedPoint(
                _stagingBox.lendSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _stagingBox.borrowSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _stagingBox.safeTranche().balanceOf(address(_stagingBox)),
                trancheDecimals
            ),
            NumFixedPoint(
                _stagingBox.riskTranche().balanceOf(address(_stagingBox)),
                trancheDecimals
            ),
            NumFixedPoint(safeTrancheCollateral, trancheDecimals),
            NumFixedPoint(riskTrancheCollateral, trancheDecimals),
            NumFixedPoint(stableBalance, stableDecimals),
            NumFixedPoint(
                (safeTrancheCollateral + riskTrancheCollateral) *
                    stableDecimals +
                    stableBalance *
                    trancheDecimals,
                trancheDecimals * stableDecimals
            ),
            NumFixedPoint(_stagingBox.s_reinitLendAmount(), stableDecimals),
            NumFixedPoint(
                _stagingBox.convertibleBondBox().safeSlip().balanceOf(
                    address(this)
                ),
                trancheDecimals
            ),
            NumFixedPoint(
                _stagingBox.convertibleBondBox().riskSlip().balanceOf(
                    address(this)
                ),
                trancheDecimals
            )
        );
        return data;
    }

    function viewCBBStatsActive(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataActive memory)
    {
        (
            uint256 safeTrancheCollateral,
            uint256 riskTrancheCollateral
        ) = calcTrancheCollateral(
                _convertibleBondBox,
                _convertibleBondBox.bond(),
                _convertibleBondBox.safeTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                _convertibleBondBox.riskTranche().balanceOf(
                    address(_convertibleBondBox)
                )
            );
        uint256 stableBalance = _convertibleBondBox.stableToken().balanceOf(
            address(_convertibleBondBox)
        );

        uint256 trancheDecimals = 10 **
            ERC20(address(_convertibleBondBox.safeTranche())).decimals();
        uint256 stableDecimals = 10 **
            ERC20(address(_convertibleBondBox.stableToken())).decimals();

        CBBDataActive memory data = CBBDataActive(
            NumFixedPoint(
                _convertibleBondBox.safeSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.riskSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.s_repaidSafeSlips(),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.safeTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.riskTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                trancheDecimals
            ),
            NumFixedPoint(safeTrancheCollateral, trancheDecimals),
            NumFixedPoint(riskTrancheCollateral, trancheDecimals),
            NumFixedPoint(stableBalance, stableDecimals),
            NumFixedPoint(
                _convertibleBondBox.currentPrice(),
                _convertibleBondBox.s_priceGranularity()
            ),
            NumFixedPoint(
                (safeTrancheCollateral + riskTrancheCollateral) *
                    stableDecimals +
                    stableBalance *
                    trancheDecimals,
                trancheDecimals * stableDecimals
            ),
            NumFixedPoint(
                (_convertibleBondBox.safeSlip().totalSupply() *
                    _convertibleBondBox.s_initialPrice()) /
                    _convertibleBondBox.s_priceGranularity(),
                trancheDecimals
            )
        );

        return data;
    }

    function viewCBBStatsMature(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataMature memory)
    {
        (
            uint256 safeTrancheCollateral,
            uint256 riskTrancheCollateral
        ) = calcTrancheCollateral(
                _convertibleBondBox,
                _convertibleBondBox.bond(),
                _convertibleBondBox.safeTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                _convertibleBondBox.riskTranche().balanceOf(
                    address(_convertibleBondBox)
                )
            );
        uint256 stableBalance = _convertibleBondBox.stableToken().balanceOf(
            address(_convertibleBondBox)
        );

        uint256 riskTrancheBalance = _convertibleBondBox
            .riskTranche()
            .balanceOf(address(_convertibleBondBox));

        uint256 trancheDecimals = 10 **
            ERC20(address(_convertibleBondBox.safeTranche())).decimals();
        uint256 stableDecimals = 10 **
            ERC20(address(_convertibleBondBox.stableToken())).decimals();

        CBBDataMature memory data = CBBDataMature(
            NumFixedPoint(
                _convertibleBondBox.safeSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.riskSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.s_repaidSafeSlips(),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.safeTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                trancheDecimals
            ),
            NumFixedPoint(
                _convertibleBondBox.riskSlip().totalSupply(),
                trancheDecimals
            ),
            NumFixedPoint(
                (riskTrancheBalance -
                    _convertibleBondBox.riskSlip().totalSupply()),
                trancheDecimals
            ),
            NumFixedPoint(safeTrancheCollateral, trancheDecimals),
            NumFixedPoint(
                (_convertibleBondBox.riskSlip().totalSupply() *
                    riskTrancheCollateral) / riskTrancheBalance,
                trancheDecimals
            ),
            NumFixedPoint(
                ((riskTrancheBalance -
                    _convertibleBondBox.riskSlip().totalSupply()) *
                    riskTrancheCollateral) / riskTrancheBalance,
                trancheDecimals
            ),
            NumFixedPoint(stableBalance, stableDecimals),
            NumFixedPoint(
                _convertibleBondBox.currentPrice(),
                _convertibleBondBox.s_priceGranularity()
            ),
            NumFixedPoint(
                (safeTrancheCollateral + riskTrancheCollateral) *
                    stableDecimals +
                    stableBalance *
                    trancheDecimals,
                trancheDecimals * stableDecimals
            ),
            NumFixedPoint(
                safeTrancheCollateral *
                    stableDecimals +
                    stableBalance *
                    trancheDecimals,
                stableDecimals * trancheDecimals
            )
        );

        return data;
    }

    function calcTrancheCollateral(
        IConvertibleBondBox convertibleBondBox,
        IBondController bond,
        uint256 safeTrancheAmount,
        uint256 riskTrancheAmount
    ) internal view returns (uint256, uint256) {
        uint256 riskTrancheCollateral = 0;
        uint256 safeTrancheCollateral = 0;

        uint256 collateralBalance = convertibleBondBox
            .collateralToken()
            .balanceOf(address(bond));

        if (bond.isMature()) {
            riskTrancheCollateral = convertibleBondBox
                .collateralToken()
                .balanceOf(address(convertibleBondBox.riskTranche()));

            safeTrancheCollateral = convertibleBondBox
                .collateralToken()
                .balanceOf(address(convertibleBondBox.safeTranche()));
        } else {
            for (
                uint256 i = 0;
                i < bond.trancheCount() - 1 && collateralBalance > 0;
                i++
            ) {
                (ITranche tranche, ) = bond.tranches(i);
                uint256 amount = Math.min(
                    tranche.totalSupply(),
                    collateralBalance
                );
                collateralBalance -= amount;

                if (i == convertibleBondBox.trancheIndex()) {
                    safeTrancheCollateral = amount;
                }
            }

            riskTrancheCollateral = collateralBalance;
        }

        safeTrancheCollateral =
            (safeTrancheCollateral * safeTrancheAmount) /
            convertibleBondBox.riskTranche().totalSupply();

        riskTrancheCollateral =
            (riskTrancheCollateral * riskTrancheAmount) /
            convertibleBondBox.riskTranche().totalSupply();

        return (safeTrancheCollateral, riskTrancheCollateral);
    }

    function fetchElasticStack(IStagingBox _stagingBox)
        internal
        view
        returns (IConvertibleBondBox, IBondController)
    {
        IConvertibleBondBox convertibleBondBox = _stagingBox
            .convertibleBondBox();
        IBondController bond = convertibleBondBox.bond();
        return (convertibleBondBox, bond);
    }
}
