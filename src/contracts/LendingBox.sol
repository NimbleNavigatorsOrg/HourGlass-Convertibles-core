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

    uint256 public constant s_tranche_granularity = 1000;
    uint256 public constant s_penalty_granularity = 1000;
    uint256 public constant s_price_granularity = 1000000000;

    function initialize() external initializer {
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
        if (price() > s_price_granularity)
            revert InitialPriceTooHigh({
                given: price(),
                maxPrice: s_price_granularity
            });
        if (startDate() >= bond().maturityDate())
            revert StartDateAfterMaturity({
                given: startDate(),
                maxStartDate: bond().maturityDate()
            });

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
    }

    /**
     * @inheritdoc ILendingBox
     */

    function lend(
        address _borrower,
        address _lender,
        uint256 stableAmount
    ) external override {
        if (startDate() > block.timestamp)
            revert LendingBoxNotStarted({
                given: startDate(),
                minStartDate: block.timestamp
            });

        uint256 _currentPrice = this.currentPrice();
        (, uint256 safeRatio) = bond().tranches(trancheIndex());
        (, uint256 riskRatio) = bond().tranches(bond().trancheCount() - 1);

        // calculate mint amount of A* based on current Price
        uint256 mintAmount = (stableAmount * s_price_granularity) /
            _currentPrice;
        ISlip(s_safeSlipTokenAddress).mint(_lender, mintAmount);

        // transfer collateral from msg.sender into CBB
        uint256 collateralAmount = (mintAmount * s_tranche_granularity) /
            safeRatio;
        TransferHelper.safeTransferFrom(
            bond().collateralToken(),
            _msgSender(),
            address(this),
            collateralAmount
        );

        // tranche it (call deposit on buttonwoodBond)
        bond().deposit(collateralAmount);

        // mint Z* to _borrower
        uint256 zTrancheAmount = (mintAmount * riskRatio) / safeRatio;
        ISlip(s_riskSlipTokenAddress).mint(_borrower, zTrancheAmount);

        // send stables borrower address
        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            _borrower,
            stableAmount
        );

        //send back unused tranches to msg.sender
        //TODO optimize for gas?
        for (uint256 i = 0; i < bond().trancheCount(); i++) {
            if (i != trancheIndex() && i != bond().trancheCount() - 1) {
                (ITranche tranche, ) = bond().tranches(i);
                TransferHelper.safeTransfer(
                    address(tranche),
                    _borrower,
                    tranche.balanceOf(address(this))
                );
            }
        }

        emit Lend(_msgSender(), stableAmount, _currentPrice);
    }

    /**
     * @inheritdoc ILendingBox
     */

    function borrow(
        address _borrower,
        address _lender,
        uint256 collateralAmount
    ) external override {
        if (startDate() > block.timestamp)
            revert LendingBoxNotStarted({
                given: startDate(),
                minStartDate: block.timestamp
            });

        uint256 _currentPrice = this.currentPrice();
        (, uint256 safeRatio) = bond().tranches(trancheIndex());
        (, uint256 riskRatio) = bond().tranches(bond().trancheCount() - 1);

        // transfer collateral from msg.sender
        TransferHelper.safeTransferFrom(
            bond().collateralToken(),
            _msgSender(),
            address(this),
            collateralAmount
        );

        // tranche it (call deposit on buttonwoodBond)
        bond().deposit(collateralAmount);

        // Need to give lender A* slips
        // calculate mint amount of A* based on tranches received
        uint256 mintAmount = (collateralAmount * safeRatio) /
            s_tranche_granularity;
        ISlip(s_safeSlipTokenAddress).mint(_lender, mintAmount);

        //Need to give borrower the stables and Z* slips
        // mint Z* to _borrower
        uint256 zTrancheAmount = (mintAmount * riskRatio) / safeRatio;
        ISlip(s_riskSlipTokenAddress).mint(_borrower, zTrancheAmount);

        //calculate stableAmount and send to borrower address
        uint256 stableAmount = (mintAmount * _currentPrice) /
            s_price_granularity;

        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            _borrower,
            stableAmount
        );

        // send unused tranches to borrower
        //TODO optimize for gas?
        for (uint256 i = 0; i < bond().trancheCount(); i++) {
            if (i != trancheIndex() && i != bond().trancheCount() - 1) {
                (ITranche tranche, ) = bond().tranches(i);
                TransferHelper.safeTransfer(
                    address(tranche),
                    _borrower,
                    tranche.balanceOf(address(this))
                );
            }
        }

        emit Borrow(_msgSender(), collateralAmount, _currentPrice);
    }

    /**
     * @dev returns time-weighted current price for Tranches, with final price as $1.00 at maturity
     */

    function currentPrice() external view override returns (uint256) {
        //load storage variables into memory
        uint256 _price = s_price_granularity;
        uint256 maturityDate = bond().maturityDate();

        if (block.timestamp < maturityDate) {
            _price =
                _price -
                ((_price - price()) * (maturityDate - block.timestamp)) /
                (maturityDate - startDate());
        }

        return _price;
    }

    /**
     * @inheritdoc ILendingBox
     */

    function repay(uint256 stableAmount, uint256 zSlipAmount)
        external
        override
    {
        if (startDate() > block.timestamp)
            revert LendingBoxNotStarted({
                given: startDate(),
                minStartDate: block.timestamp
            });

        //Load into memory
        uint256 _currentPrice = this.currentPrice();
        uint256 maturityDate = bond().maturityDate();

        (ITranche safeTranche, uint256 safeRatio) = bond().tranches(
            trancheIndex()
        );
        (ITranche riskTranche, uint256 riskRatio) = bond().tranches(
            bond().trancheCount() - 1
        );

        // Calculate safeTranche payout
        //TODO: Decimals conversion?
        uint256 safeTranchePayout = (stableAmount * s_price_granularity) /
            _currentPrice;

        if (stableAmount != 0) {
            //Repay stables to LendingBox
            TransferHelper.safeTransferFrom(
                address(stableToken()),
                _msgSender(),
                address(this),
                stableAmount
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
        uint256 zTrancheUnpaid = zSlipAmount - zTranchePaidFor;

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
            stableAmount,
            zTranchePaidFor,
            zTrancheUnpaid,
            _currentPrice
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
        if (startDate() > block.timestamp)
            revert LendingBoxNotStarted({
                given: startDate(),
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
}
