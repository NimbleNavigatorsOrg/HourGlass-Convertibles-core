//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "clones-with-immutable-args/Clone.sol";

/**
 * @dev Convertible Bond Box for a ButtonTranche bond
 */

interface ILendingBox {

    event Lend(address, uint256, uint256);
    event Borrow(address, uint256, uint256);
    event RedeemA(address, uint256, uint256);
    event Repay(address, uint256, uint256, uint256, uint256);

    error PenaltyTooHigh(uint256 given, uint256 maxPenalty);
    error BondIsMature(bool given, bool required);
    error TrancheIndexOutOfBonds(uint256 given, uint256 maxIndex);
    error InitialPriceTooHigh(uint256 given, uint256 maxPrice);
    error StartDateAfterMaturity(uint256 given, uint256 maxStartDate);
    error LendingBoxNotStarted(uint256 given, uint256 minStartDate);
    error NotEnoughFundsInLendingBox();

    /**
     * @dev Lends stableAmount of stable-tokens for safe-Tranche slips
     * @param stableAmount The amount of stable tokens to lend
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
        - initial price of bond must be set
     */

    function lend(uint256 stableAmount) external;

    /**
     * @dev Borrows with collateralAmount of collateral-tokens. Collateral tokens get tranched
     * and any non-lending box tranches get sent back to msg.sender
     * @param collateralAmount The buttonTranche bond tied to this Convertible Bond Box
     * Requirements:
     *  - `msg.sender` must have `approved` `collateralAmount` collateral tokens to this contract
        - initial price of bond must be set
        - must be enough stable tokens inside lending box to borrow 
     */

    function borrow(uint256 collateralAmount) external;

    /**
     * @dev returns time-weighted current price for Tranches, with final price as $1.00 at maturity
     */

    function currentPrice() external view returns (uint256);

    /**
     * @dev allows repayment of loan in exchange for proportional amount of safe-Tranche and Z-tranche
     * - any unpaid amount of Z-slips after maturity will be penalized upon redeeming
     * @param stableAmount The amount of stable-Tokens to repay with
     * @param zSlipAmount The amount of Z-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `zSlipAmount` z-Slip tokens to this contract
     *  - `msg.sender` must have `approved` `stableAmount` of stable tokens to this contract
     */

    function repay(uint256 stableAmount, uint256 zSlipAmount) external;

    /**
     * @dev allows lender to redeem safe-slip for tranches and/or stables
     * @param safeSlipAmount The amount of safe-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `safeSlipAmount` of safe-Slip tokens to this contract
     */

    function redeemA(uint256 safeSlipAmount) external;
}
