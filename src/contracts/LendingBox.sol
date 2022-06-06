//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "clones-with-immutable-args/Clone.sol";
import "../interfaces/IButtonWoodBondController.sol";
import "../interfaces/ISlipFactory.sol";
import "../interfaces/ISlip.sol";
import "../../utils/CBBImmutableArgs.sol";
import "../interfaces/ILendingBox.sol";

/**
 * @dev Convertible Bond Box for a ButtonTranche bond
 *
 * Invariants:
 *  - `initial Price must be < $1.00`
 *  - penalty ratio must be < 1.0
 *  - safeTranche index must not be Z-tranche
 */

contract LendingBox is
    OwnableUpgradeable,
    Clone,
    CBBImmutableArgs,
    ILendingBox
{
    address public s_safeSlipTokenAddress;
    address public s_riskSlipTokenAddress;
    address public s_matcherAddress;

    uint256 public s_startDate = 0;

    uint256 public constant s_tranche_granularity = 1000;
    uint256 public constant s_penalty_granularity = 1000;
    uint256 public constant s_price_granularity = 1000000000;

    function initialize(
        address _borrower,
        address _lender,
        uint256 _collateralAmount,
        uint256 _stableAmount
    ) external initializer {
        if (penalty() > s_penalty_granularity)
            revert PenaltyTooHigh({
                given: penalty(),
                maxPenalty: s_price_granularity
            });
        if (bond().isMature())
            revert BondIsMature({given: bond().isMature(), required: false});
        // Safe-Tranche cannot be the Z-Tranche
        if (trancheIndex() >= bond().trancheCount() - 1)
            revert TrancheIndexOutOfBonds({
                given: trancheIndex(),
                maxIndex: bond().trancheCount() - 2
            });
        if (initialPrice() > s_price_granularity)
            revert InitialPriceTooHigh({
                given: initialPrice(),
                maxPrice: s_price_granularity
            });

        if (_stableAmount * _collateralAmount != 0)
            revert OnlyLendOrBorrow({
                calcProduct: _stableAmount * _collateralAmount,
                expectedProduct: 0
            });

        s_matcherAddress = msg.sender;

        (ITranche safeTranche, ) = bond().tranches(trancheIndex());
        (ITranche riskTranche, ) = bond().tranches(bond().trancheCount() - 1);

        // clone deploy safe slip
        s_safeSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Safe-CBB-Slip",
            address(safeTranche)
        );

        //clone deploy z slip
        s_riskSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Risk-CBB-Slip",
            address(riskTranche)
        );

        //set LendingBox Start Date to be time when init() is called
        s_startDate = block.timestamp;

        // initial borrow/lend at initialPrice, provided matching order is provided

        if (_stableAmount != 0) {
            this.lend(_borrower, _lender, _stableAmount, s_matcherAddress);
        }

        if (_collateralAmount != 0) {
            this.borrow(_borrower, _lender, _collateralAmount, s_matcherAddress);
        }
    }

    /**
     * @inheritdoc ILendingBox
     */

    function lend(
        address _borrower,
        address _lender,
        uint256 _stableAmount,
        address _matcherAddress
    ) external override {
        if (s_startDate == 0)
            revert LendingBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        (, uint256 safeRatio) = bond().tranches(trancheIndex());
        (, uint256 riskRatio) = bond().tranches(bond().trancheCount() - 1);

        uint256 price = this.currentPrice();

        uint256 mintAmount = (_stableAmount * s_price_granularity) / price;
        uint256 collateralAmount = (mintAmount * s_tranche_granularity) /
            safeRatio;

        uint256 zTrancheAmount = (mintAmount * riskRatio) / safeRatio;

        _atomicDeposit(
            _borrower,
            _lender,
            collateralAmount,
            _stableAmount,
            mintAmount,
            zTrancheAmount,
            _matcherAddress
        );

        emit Lend(_msgSender(), _borrower, _lender, _stableAmount, price);
    }

    /**
     * @inheritdoc ILendingBox
     */

    function borrow(
        address _borrower,
        address _lender,
        uint256 _collateralAmount,
        address _matcherAddress
    ) external override {
        if (s_startDate == 0)
            revert LendingBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        uint256 price = this.currentPrice();

        (, uint256 safeRatio) = bond().tranches(trancheIndex());
        (, uint256 riskRatio) = bond().tranches(bond().trancheCount() - 1);

        uint256 mintAmount = (_collateralAmount * safeRatio) /
            s_tranche_granularity;

        uint256 zTrancheAmount = (mintAmount * riskRatio) / safeRatio;
        uint256 stableAmount = (mintAmount * price) / s_price_granularity;

        _atomicDeposit(
            _borrower,
            _lender,
            _collateralAmount,
            stableAmount,
            mintAmount,
            zTrancheAmount,
            _matcherAddress
        );

        emit Borrow(_msgSender(), _borrower, _lender, _collateralAmount, price);
    }

    /**
     * @dev returns time-weighted current price for Tranches, with final price as $1.00 at maturity
     */

    function currentPrice() external view override returns (uint256) {
        //load storage variables into memory
        uint256 price = s_price_granularity;
        uint256 maturityDate = bond().maturityDate();

        if (block.timestamp < maturityDate) {
            price =
                price -
                ((price - initialPrice()) * (maturityDate - block.timestamp)) /
                (maturityDate - s_startDate);
        }

        return price;
    }

    /**
     * @inheritdoc ILendingBox
     */

    function repay(uint256 _stableAmount, uint256 _zSlipAmount)
        external
        override
    {
        if (s_startDate == 0)
            revert LendingBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        //Load into memory
        uint256 price = this.currentPrice();
        uint256 maturityDate = bond().maturityDate();

        (ITranche safeTranche, uint256 safeRatio) = bond().tranches(
            trancheIndex()
        );
        (ITranche riskTranche, uint256 riskRatio) = bond().tranches(
            bond().trancheCount() - 1
        );

        // Calculate safeTranche payout
        //TODO: Decimals conversion?
        uint256 safeTranchePayout = (_stableAmount * s_price_granularity) /
            price;

        if (_stableAmount != 0) {
            //Repay stables to LendingBox
            TransferHelper.safeTransferFrom(
                address(stableToken()),
                _msgSender(),
                address(this),
                _stableAmount
            );

            //transfer A-tranches from LendingBox to msg.sender
            TransferHelper.safeTransfer(
                address(safeTranche),
                _msgSender(),
                safeTranchePayout
            );
        }

        //calculate Z-tranche payout
        uint256 zTranchePaidFor = (safeTranchePayout * riskRatio) / safeRatio;
        uint256 zTrancheUnpaid = _zSlipAmount - zTranchePaidFor;

        //Apply penalty to any Z-tranches that have not been repaid for after maturity
        if (block.timestamp >= maturityDate) {
            zTrancheUnpaid =
                zTrancheUnpaid -
                (zTrancheUnpaid * penalty()) /
                s_penalty_granularity;
        }

        //Should not allow redeeming Z-tranches before maturity without repaying
        if (block.timestamp < maturityDate) {
            zTrancheUnpaid = 0;
        }

        // //transfer Z-tranches from LendingBox to msg.sender
        TransferHelper.safeTransfer(
            address(riskTranche),
            _msgSender(),
            zTranchePaidFor + zTrancheUnpaid
        );

        ISlip(s_riskSlipTokenAddress).burn(
            _msgSender(),
            zTranchePaidFor + zTrancheUnpaid
        );

        emit Repay(
            _msgSender(),
            _stableAmount,
            zTranchePaidFor,
            zTrancheUnpaid,
            price
        );
    }

    /**
     * @inheritdoc ILendingBox
     */

    function redeemTranche(uint256 safeSlipAmount) external override {
        if (block.timestamp < bond().maturityDate())
            revert BondNotMatureYet({
                maturityDate: bond().maturityDate(),
                currentTime: block.timestamp
            });

        (ITranche safeTranche, ) = bond().tranches(trancheIndex());
        (ITranche riskTranche, ) = bond().tranches(bond().trancheCount() - 1);

        address safeSlipTokenAddress = s_safeSlipTokenAddress;
        uint256 safeTrancheBalance = IERC20(address(safeTranche)).balanceOf(
            address(this)
        );

        //burn safe-slips
        ISlip(safeSlipTokenAddress).burn(_msgSender(), safeSlipAmount);

        //transfer safe-Tranche after maturity only
        TransferHelper.safeTransfer(
            address(safeTranche),
            _msgSender(),
            (safeSlipAmount)
        );

        uint256 zPenaltyTotal = IERC20(address(riskTranche)).balanceOf(
            address(this)
        ) - IERC20(s_riskSlipTokenAddress).totalSupply();

        //transfer risk-Tranche penalty after maturity only
        TransferHelper.safeTransfer(
            address(riskTranche),
            _msgSender(),
            (safeSlipAmount * zPenaltyTotal) / safeTrancheBalance
        );

        emit RedeemTranche(_msgSender(), safeSlipAmount);
    }

    /**
     * @inheritdoc ILendingBox
     */

    function redeemStable(uint256 safeSlipAmount) external override {
        if (s_startDate == 0)
            revert LendingBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        (ITranche safeTranche, ) = bond().tranches(trancheIndex());

        address safeSlipTokenAddress = s_safeSlipTokenAddress;

        uint256 stableBalance = stableToken().balanceOf(address(this));
        uint256 safeSlipSupply = IERC20(safeSlipTokenAddress).totalSupply();
        uint256 safeTrancheBalance = IERC20(address(safeTranche)).balanceOf(
            address(this)
        );

        //grief risk?
        uint256 repaidSafeSlips = (safeSlipSupply - safeTrancheBalance);

        //burn safe-slips
        ISlip(safeSlipTokenAddress).burn(_msgSender(), safeSlipAmount);

        //transfer stables
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            (safeSlipAmount * stableBalance) / (repaidSafeSlips)
        );

        emit RedeemStable(_msgSender(), safeSlipAmount, this.currentPrice());
    }

    function _atomicDeposit(
        address _borrower,
        address _lender,
        uint256 _collateralAmount,
        uint256 _stableAmount,
        uint256 _safeSlipAmount,
        uint256 _riskSlipAmount,
        address _matcherAddress
    ) internal {

        //Transfer collateral to ConvertibleBondBox
        TransferHelper.safeTransferFrom(
            address(collateralToken()),
            _matcherAddress,
            address(this),
            _collateralAmount
        );

        //Tranche the collateral
        // bond().deposit(_collateralAmount);

        // //Mint safeSlips to the lender
        // ISlip(s_safeSlipTokenAddress).mint(_lender, _safeSlipAmount);

        // //Mint riskSlips to the lender
        // ISlip(s_riskSlipTokenAddress).mint(_borrower, _riskSlipAmount);

        // //Transfer stables to borrower
        // TransferHelper.safeTransferFrom(
        //     address(stableToken()),
        //     _msgSender(),
        //     _borrower,
        //     _stableAmount
        // );

        // //Transfer unused tranches to borrower
        // for (uint256 i = 0; i < bond().trancheCount(); i++) {
        //     if (i != trancheIndex() && i != bond().trancheCount() - 1) {
        //         (ITranche tranche, ) = bond().tranches(i);
        //         TransferHelper.safeTransfer(
        //             address(tranche),
        //             _borrower,
        //             tranche.balanceOf(address(this))
        //         );
        //     }
        // }
    }
}
