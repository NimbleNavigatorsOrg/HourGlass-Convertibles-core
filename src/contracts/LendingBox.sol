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
     * @dev Lends stableAmount of stable-tokens for safe-Tranche slips
     * @param stableAmount The amount of stable tokens to lend
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
        - initial price of bond must be set
     */

    function lend(uint256 stableAmount) external override {
        if (startDate() > block.timestamp)
            revert LendingBoxNotStarted({
                given: startDate(),
                minStartDate: block.timestamp
            });

        uint256 _currentPrice = this.currentPrice();

        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            address(this),
            stableAmount
        );

        uint256 mintAmount = (stableAmount * s_price_granularity) /
            _currentPrice;

        ISlip(s_safeSlipTokenAddress).mint(_msgSender(), mintAmount);
        emit Lend(_msgSender(), stableAmount, _currentPrice);
    }

    /**
     * @dev Borrows with collateralAmount of collateral-tokens. Collateral tokens get tranched
     * and any non-lending box tranches get sent back to msg.sender
     * @param collateralAmount The buttonTranche bond tied to this Convertible Bond Box
     * Requirements:
     *  - `msg.sender` must have `approved` `collateralAmount` collateral tokens to this contract
        - initial price of bond must be set
        - must be enough stable tokens inside lending box to borrow 
     */

    function borrow(uint256 collateralAmount) external override {
        if (startDate() > block.timestamp)
            revert LendingBoxNotStarted({
                given: startDate(),
                minStartDate: block.timestamp
            });

        //load storage into memory

        uint256 price_granularity = s_price_granularity;
        uint256 tranche_granularity = s_tranche_granularity;
        uint256 _currentPrice = this.currentPrice();

        (, uint256 safeRatio) = bond().tranches(trancheIndex());
        (, uint256 riskRatio) = bond().tranches(bond().trancheCount() - 1);
        if (
            stableToken().balanceOf(address(this)) <
            (collateralAmount * safeRatio * _currentPrice) /
                price_granularity /
                tranche_granularity
        ) revert NotEnoughFundsInLendingBox();

        TransferHelper.safeTransferFrom(
            address(collateralToken()),
            _msgSender(),
            address(this),
            collateralAmount
        );
        TransferHelper.safeApprove(
            address(collateralToken()),
            address(bond()),
            collateralAmount
        );
        bond().deposit(collateralAmount);

        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            (collateralAmount * safeRatio * _currentPrice) /
                tranche_granularity /
                price_granularity
        );

        //send back unused tranches to msg.sender
        for (uint256 i = 0; i < bond().trancheCount(); i++) {
            if (i != trancheIndex() && i != bond().trancheCount() - 1) {
                (ITranche tranche, ) = bond().tranches(i);
                TransferHelper.safeTransfer(
                    address(tranche),
                    _msgSender(),
                    tranche.balanceOf(address(this))
                );
            }
        }

        ISlip(s_riskSlipTokenAddress).mint(
            _msgSender(),
            (collateralAmount * riskRatio) / tranche_granularity
        );
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
     * @dev allows repayment of loan in exchange for proportional amount of safe-Tranche and Z-tranche
     * - any unpaid amount of Z-slips after maturity will be penalized upon redeeming
     * @param stableAmount The amount of stable-Tokens to repay with
     * @param zSlipAmount The amount of Z-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `zSlipAmount` z-Slip tokens to this contract
     *  - `msg.sender` must have `approved` `stableAmount` of stable tokens to this contract
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

        //Require statement for "overpayment"?

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
     * @dev allows lender to redeem safe-slip for tranches
     * @param safeSlipAmount The amount of safe-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `safeSlipAmount` of safe-Slip tokens to this contract
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
     * @dev allows lender to redeem safe-slip for stables
     * @param safeSlipAmount The amount of safe-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `safeSlipAmount` of safe-Slip tokens to this contract
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
