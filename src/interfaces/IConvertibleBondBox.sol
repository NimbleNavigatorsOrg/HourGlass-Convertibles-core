//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "clones-with-immutable-args/Clone.sol";

/**
 * @dev Convertible Bond Box for a ButtonTranche bond
 */

interface IConvertibleBondBox {
    event Lend(address, address, address, uint256, uint256);
    event Borrow(address, address, address, uint256, uint256);
    event RedeemStable(address, uint256, uint256);
    event RedeemSafeTranche(address, uint256);
    event RedeemRiskTranche(address, uint256);
    event Repay(address, uint256, uint256, uint256);
    event Initialized(address, address, uint256, uint256);
    event FeeUpdate(uint256);

    error PenaltyTooHigh(uint256 given, uint256 maxPenalty);
    error BondIsMature(bool given, bool required);
    error TrancheIndexOutOfBounds(uint256 given, uint256 maxIndex);
    error InitialPriceTooHigh(uint256 given, uint256 maxPrice);
    error ConvertibleBondBoxNotStarted(uint256 given, uint256 minStartDate);
    error BondNotMatureYet(uint256 maturityDate, uint256 currentTime);
    error OnlyLendOrBorrow(uint256 _stableAmount, uint256 _collateralAmount);
    error PayoutExceedsBalance(uint256 safeTranchePayout, uint256 balance);
    error MinimumInput(uint256 input, uint256 reqInput);

    //Need to add getters for state variables

    /**
     * @dev Lends stableAmount of stable-tokens for safe-Tranche slips when provided with matching borrow collateral
     * @param _borrower The address to send the Z* and stableTokens to 
     * @param _lender The address to send the safeSlips to 
     * @param _stableAmount The amount of stable tokens to lend
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
        - initial price of bond must be set
     */

    function lend(
        address _borrower,
        address _lender,
        uint256 _stableAmount
    ) external;

    /**
     * @dev Borrows with collateralAmount of collateral-tokens when provided with a matching amount of stableTokens.
     * Collateral tokens get tranched and any non-convertible bond box tranches get sent back to borrower 
     * @param _borrower The address to send the Z* and stableTokens to 
     * @param _lender The address to send the safeSlips to 
     * @param _collateralAmount The buttonTranche bond tied to this Convertible Bond Box
     * Requirements:
     *  - `msg.sender` must have `approved` `collateralAmount` collateral tokens to this contract
        - initial price of bond must be set
        - must be enough stable tokens inside convertible bond box to borrow 
     */

    function borrow(
        address _borrower,
        address _lender,
        uint256 _collateralAmount
    ) external;

    /**
     * @dev returns time-weighted current price for Tranches, with final price as $1.00 at maturity
     */

    function currentPrice() external view returns (uint256);

    /**
     * @dev allows repayment of loan in exchange for proportional amount of safe-Tranche and Z-tranche
     * - any unpaid amount of Z-slips after maturity will be penalized upon redeeming
     * @param stableAmount The amount of stable-Tokens to repay with
     * Requirements:
     *  - `msg.sender` must have `approved` `zSlipAmount` z-Slip tokens to this contract
     *  - `msg.sender` must have `approved` `stableAmount` of stable tokens to this contract
     */

    function repay(uint256 stableAmount) external;

    /**
     * @dev allows lender to redeem safe-slip for tranches
     * @param safeSlipAmount The amount of safe-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `safeSlipAmount` of safe-Slip tokens to this contract
     */

    function redeemSafeTranche(uint256 safeSlipAmount) external;

    /**
     * @dev allows borrower to redeem risk-slip for tranches without repaying
     * @param riskSlipAmount The amount of risk-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `riskSlipAmount` of safe-Slip tokens to this contract
     */

    function redeemRiskTranche(uint256 riskSlipAmount) external;

    /**
     * @dev allows lender to redeem safe-slip for stables
     * @param safeSlipAmount The amount of safe-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `safeSlipAmount` of safe-Slip tokens to this contract
     */

    function redeemStable(uint256 safeSlipAmount) external;

    /**
     * @dev Updates the fee taken on deposit to the given new fee
     *
     * Requirements
     * - `msg.sender` has admin role
     * - `newFeeBps` is in range [0, 50]
     */

    function setFee(uint256 newFeeBps) external;
}
