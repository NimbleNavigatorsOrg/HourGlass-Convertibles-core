//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../interfaces/ICBBSlipFactory.sol";
import "../interfaces/ICBBSlip.sol";
import "../../utils/SBImmutableArgs.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "../interfaces/IStagingBox.sol";

import "forge-std/console2.sol";

/**
 * @dev Staging Box for reinitializing a ConvertibleBondBox
 *
 * Invariants:
 *  - `initial Price must be < $1.00`
 *  - penalty ratio must be < 1.0
 *  - safeTranche index must not be Z-tranche
 */

contract StagingBox is OwnableUpgradeable, Clone, SBImmutableArgs, IStagingBox {
    function initialize(address _owner) external initializer {
        require(
            _owner != address(0),
            "ConvertibleBondBox: invalid owner address"
        );
        __Ownable_init();
        transferOwnership(_owner);

        //Check if valid ICBB immutable arg?
        //check if valid initialPrice immutable arg?
    }

    function depositBorrow(address _borrower, uint256 _safeTrancheAmount)
        external
        override
    {
        /*
        - Ensure CBB not reinitialized
        - transfers `_safeTrancheAmount` of SafeTranche Tokens from msg.sender to SB
        - transfers `_safeTrancheAmount * riskRatio() / safeRatio()`  of RiskTranches from msg.sender to CBB
        - mints `_safeTrancheAmount` of BorrowerSlips to `_borrower`
        */
    }

    function depositLend(address _lender, uint256 _lendAmount)
        external
        override
    {
        /*
        - Ensure CBB not reinitialized 
        - transfers `_stableAmount`of SafeTranche Tokens from msg.sender to SB
        - mints `_stableAmount`of LenderSlips to `_lender`
        */
    }

    function withdrawBorrow(uint256 _borrowSlipAmount) external override {
        /* 
        - Reverse of depositBorrow() function 
        - transfers `_borrowSlipAmount` of SafeTranche Tokens from CB to msg.sender
        - transfers `_borrowSlipAmount*riskRatio()/safeRatio()` of RiskTranche Tokens from CB to msg.sender
        - burns `_borrowSlipAmount` of msg.sender’s BorrowSlips
        */
    }

    function withdrawLend(uint256 _lendSlipAmount) external override {
        /* 
        - Reverse of depositBorrow() function
        - transfers `_lendSlipAmount` of Stable Tokens from SB to msg.sender
        - burns `_lendSlipAmount` of msg.sender’s LenderSlips
        */
    }

    function redeemBorrowSlip(uint256 _borrowSlipAmount) external override {
        /* 
        - Ensure CBB is reinitialized (may not be necessary)
        - Transfer `_borrowSlipAmount*riskRatio()/safeRatio()`  of RiskSlips to msg.sender
        - Transfer `_borrowSlipAmount*initialPrice()/priceGranularity()` of StableToken to msg.sender
        - burns `_borrowSlipAmount` of msg.sender’s BorrowSlips
        */
    }

    function redeemLendSlip(uint256 _lendSlipAmount) external override {
        /* 
        - Ensure CBB is reinitialized (may not be necessary since reinitializer already covers)
        - Transfer `_lendSlipAmount*priceGranularity()/initialPrice()`  of SafeSlips to msg.sender
        - burns `_lendSlipAmount` of msg.sender’s LendSlips
        */
    }

    function transmitReInit(bool _lendOrBorrow) external override onlyOwner {
        /*
        - calls `CBB.reinitialize(…)`
            - `Address(this)` as borrower + lender
            - if `_lendOrBorrow` is true: calls CBB with balance of StableAmount
            - if `_lendOrBorrow` is false: calls CBB with balance of SafeTrancheAmount
        - calls `CBB.transferOwner(owner())` to transfer ownership of CBB back to Owner()
        */
    }

    function sbTransferOwnership(address _newOwner)
        external
        override
        onlyOwner
    {
        transferOwnership(_newOwner);
    }
}
