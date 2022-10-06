// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IConvertiblesDVLens.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "@buttonwood-protocol/tranche/contracts/external/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev View functions only - for front-end use
 */

contract ConvertiblesDVLens is IConvertiblesDVLens {
    struct DecimalPair {
        uint256 tranche;
        uint256 stable;
    }

    struct CollateralBalance {
        uint256 safe;
        uint256 risk;
    }

    struct IBOBalances {
        uint256 safeTranche;
        uint256 riskTranche;
        uint256 safeSlip;
        uint256 issuerSlip;
        uint256 stablesBorrow;
        uint256 stablesLend;
        uint256 stablesTotal;
    }

    function viewIBOStatsIBO(IIBOBox _IBOBox)
        external
        view
        returns (IBODataIBO memory)
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond
        ) = fetchElasticStack(_IBOBox);
        CollateralBalance memory simTrancheCollateral = calcTrancheCollateral(
            convertibleBondBox,
            bond,
            _IBOBox.safeTranche().balanceOf(address(_IBOBox)),
            _IBOBox.riskTranche().balanceOf(address(_IBOBox))
        );
        uint256 stableBalance = _IBOBox.stableToken().balanceOf(
            address(_IBOBox)
        );

        DecimalPair memory decimals = DecimalPair(
            ERC20(address(_IBOBox.safeTranche())).decimals(),
            ERC20(address(_IBOBox.stableToken())).decimals()
        );

        IBODataIBO memory data = IBODataIBO(
            NumFixedPoint(_IBOBox.lendSlip().totalSupply(), decimals.stable),
            NumFixedPoint(_IBOBox.borrowSlip().totalSupply(), decimals.stable),
            NumFixedPoint(
                _IBOBox.safeTranche().balanceOf(address(_IBOBox)),
                decimals.tranche
            ),
            NumFixedPoint(
                _IBOBox.riskTranche().balanceOf(address(_IBOBox)),
                decimals.tranche
            ),
            NumFixedPoint(stableBalance, decimals.stable),
            NumFixedPoint(simTrancheCollateral.safe, decimals.tranche),
            NumFixedPoint(simTrancheCollateral.risk, decimals.tranche),
            NumFixedPoint(
                (simTrancheCollateral.safe + simTrancheCollateral.risk),
                decimals.tranche
            ),
            NumFixedPoint(stableBalance, decimals.stable)
        );

        return data;
    }

    function viewIBOStatsActive(IIBOBox _IBOBox)
        external
        view
        returns (IBODataActive memory)
    {
        (
            IConvertibleBondBox convertibleBondBox,
            IBondController bond
        ) = fetchElasticStack(_IBOBox);
        CollateralBalance memory simTrancheCollateral = calcTrancheCollateral(
            convertibleBondBox,
            bond,
            _IBOBox.safeTranche().balanceOf(address(_IBOBox)),
            _IBOBox.riskTranche().balanceOf(address(_IBOBox))
        );
        CollateralBalance memory simSlipCollateral = calcTrancheCollateral(
            convertibleBondBox,
            bond,
            convertibleBondBox.safeSlip().balanceOf(address(_IBOBox)),
            convertibleBondBox.issuerSlip().balanceOf(address(_IBOBox))
        );

        DecimalPair memory decimals = DecimalPair(
            ERC20(address(_IBOBox.safeTranche())).decimals(),
            ERC20(address(_IBOBox.stableToken())).decimals()
        );

        IBOBalances memory IBO_Balances = IBOBalances(
            _IBOBox.safeTranche().balanceOf(address(_IBOBox)),
            _IBOBox.riskTranche().balanceOf(address(_IBOBox)),
            _IBOBox.convertibleBondBox().safeSlip().balanceOf(address(_IBOBox)),
            _IBOBox.convertibleBondBox().issuerSlip().balanceOf(
                address(_IBOBox)
            ),
            _IBOBox.s_activateLendAmount(),
            (_IBOBox.stableToken().balanceOf(address(_IBOBox)) -
                _IBOBox.s_activateLendAmount()),
            _IBOBox.stableToken().balanceOf(address(_IBOBox))
        );

        IBODataActive memory data = IBODataActive(
            NumFixedPoint(_IBOBox.lendSlip().totalSupply(), decimals.stable),
            NumFixedPoint(_IBOBox.borrowSlip().totalSupply(), decimals.stable),
            NumFixedPoint(IBO_Balances.safeTranche, decimals.tranche),
            NumFixedPoint(IBO_Balances.riskTranche, decimals.tranche),
            NumFixedPoint(IBO_Balances.safeSlip, decimals.tranche),
            NumFixedPoint(IBO_Balances.issuerSlip, decimals.tranche),
            NumFixedPoint(IBO_Balances.stablesBorrow, decimals.stable),
            NumFixedPoint(IBO_Balances.stablesLend, decimals.stable),
            NumFixedPoint(simTrancheCollateral.safe, decimals.tranche),
            NumFixedPoint(simTrancheCollateral.risk, decimals.tranche),
            NumFixedPoint(simSlipCollateral.safe, decimals.tranche),
            NumFixedPoint(simSlipCollateral.risk, decimals.tranche),
            NumFixedPoint(
                ((simTrancheCollateral.safe +
                    simTrancheCollateral.risk +
                    simSlipCollateral.risk) *
                    10**decimals.stable +
                    _IBOBox.s_activateLendAmount() *
                    10**decimals.tranche),
                decimals.tranche + decimals.stable
            ),
            NumFixedPoint(
                (IBO_Balances.stablesLend) +
                    (IBO_Balances.safeSlip *
                        convertibleBondBox.currentPrice() *
                        (10**decimals.stable)) /
                    convertibleBondBox.s_priceGranularity() /
                    (10**decimals.tranche),
                decimals.stable
            )
        );
        return data;
    }

    function viewCBBStatsActive(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataActive memory)
    {
        CollateralBalance memory simTrancheCollateral = calcTrancheCollateral(
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

        DecimalPair memory decimals = DecimalPair(
            ERC20(address(_convertibleBondBox.safeTranche())).decimals(),
            ERC20(address(_convertibleBondBox.stableToken())).decimals()
        );

        CBBDataActive memory data = CBBDataActive(
            NumFixedPoint(
                _convertibleBondBox.safeSlip().totalSupply(),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.issuerSlip().totalSupply(),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.s_repaidSafeSlips(),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.safeTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.riskTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                decimals.tranche
            ),
            NumFixedPoint(stableBalance, decimals.stable),
            NumFixedPoint(simTrancheCollateral.safe, decimals.tranche),
            NumFixedPoint(simTrancheCollateral.risk, decimals.tranche),
            NumFixedPoint(
                _convertibleBondBox.currentPrice(),
                _convertibleBondBox.s_priceGranularity()
            ),
            NumFixedPoint(simTrancheCollateral.risk, decimals.tranche),
            NumFixedPoint(
                (simTrancheCollateral.safe *
                    (10**decimals.stable) +
                    stableBalance *
                    (10**decimals.tranche)),
                decimals.tranche + decimals.stable
            )
        );

        return data;
    }

    function viewCBBStatsMature(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataMature memory)
    {
        CollateralBalance memory simTrancheCollateral = calcTrancheCollateral(
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

        uint256 zPenaltyTrancheCollateral = ((riskTrancheBalance -
            _convertibleBondBox.issuerSlip().totalSupply()) *
            simTrancheCollateral.risk) / riskTrancheBalance;

        DecimalPair memory decimals = DecimalPair(
            ERC20(address(_convertibleBondBox.safeTranche())).decimals(),
            ERC20(address(_convertibleBondBox.stableToken())).decimals()
        );

        CBBDataMature memory data = CBBDataMature(
            NumFixedPoint(
                _convertibleBondBox.safeSlip().totalSupply(),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.issuerSlip().totalSupply(),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.s_repaidSafeSlips(),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.safeTranche().balanceOf(
                    address(_convertibleBondBox)
                ),
                decimals.tranche
            ),
            NumFixedPoint(
                _convertibleBondBox.issuerSlip().totalSupply(),
                decimals.tranche
            ),
            NumFixedPoint(
                (riskTrancheBalance -
                    _convertibleBondBox.issuerSlip().totalSupply()),
                decimals.tranche
            ),
            NumFixedPoint(stableBalance, decimals.stable),
            NumFixedPoint(simTrancheCollateral.safe, decimals.tranche),
            NumFixedPoint(
                (_convertibleBondBox.issuerSlip().totalSupply() *
                    simTrancheCollateral.risk) / riskTrancheBalance,
                decimals.tranche
            ),
            NumFixedPoint(zPenaltyTrancheCollateral, decimals.tranche),
            NumFixedPoint(
                _convertibleBondBox.currentPrice(),
                _convertibleBondBox.s_priceGranularity()
            ),
            NumFixedPoint(
                simTrancheCollateral.risk - zPenaltyTrancheCollateral,
                decimals.tranche
            ),
            NumFixedPoint(
                (simTrancheCollateral.safe + zPenaltyTrancheCollateral) *
                    10**decimals.stable +
                    stableBalance *
                    10**decimals.tranche,
                decimals.stable + decimals.tranche
            )
        );

        return data;
    }

    function calcTrancheCollateral(
        IConvertibleBondBox convertibleBondBox,
        IBondController bond,
        uint256 safeTrancheAmount,
        uint256 riskTrancheAmount
    ) internal view returns (CollateralBalance memory) {
        uint256 riskTrancheCollateral = 0;
        uint256 safeTrancheCollateral = 0;

        uint256 collateralBalance = convertibleBondBox
            .collateralToken()
            .balanceOf(address(bond));

        if (collateralBalance > 0) {
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
                convertibleBondBox.safeTranche().totalSupply();

            riskTrancheCollateral =
                (riskTrancheCollateral * riskTrancheAmount) /
                convertibleBondBox.riskTranche().totalSupply();
        }

        CollateralBalance memory collateral = CollateralBalance(
            safeTrancheCollateral,
            riskTrancheCollateral
        );

        return collateral;
    }

    function fetchElasticStack(IIBOBox _IBOBox)
        internal
        view
        returns (IConvertibleBondBox, IBondController)
    {
        IConvertibleBondBox convertibleBondBox = _IBOBox.convertibleBondBox();
        IBondController bond = convertibleBondBox.bond();
        return (convertibleBondBox, bond);
    }
}
