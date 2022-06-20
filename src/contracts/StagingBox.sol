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
 */

contract StagingBox is OwnableUpgradeable, Clone, SBImmutableArgs, IStagingBox {
    address public override s_lendSlipTokenAddress;
    address public override s_borrowSlipTokenAddress;

    function initialize(address _owner) external initializer {
        require(
            _owner != address(0),
            "ConvertibleBondBox: invalid owner address"
        );
        //check if valid initialPrice immutable arg
        if (initialPrice() > priceGranularity())
            revert InitialPriceTooHigh({
                given: initialPrice(),
                maxPrice: priceGranularity()
            });

            console2.log("What?");

        //Setup ownership
        __Ownable_init();

                    console2.log("Huh?");

        transferOwnership(_owner);

                            console2.log("Kapow?");


        //Deploy Borrow Lend Slips
        //TODO: Need to use ERC20 meta-data and revise slip factory inputs
        // clone deploy safe slip
        s_lendSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Staging-Lender-Slip",
            address(this)
        );

                                    console2.log("shbabm?");


        //clone deploy z slip
        s_borrowSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Staging-Borrower-Slip",
            address(this)
        );

                                    console2.log("dfage?");

        //Check if valid ICBB immutable arg?

        //Add event stuff
    }

    function depositBorrow(address _borrower, uint256 _safeTrancheAmount)
        external
        override
    {
        //- Ensure CBB not reinitialized

        //- transfers `_safeTrancheAmount` of SafeTranche Tokens from msg.sender to SB
        TransferHelper.safeTransferFrom(
            address(safeTranche()),
            _msgSender(),
            address(this),
            _safeTrancheAmount
        );

        //- transfers `_safeTrancheAmount * riskRatio() / safeRatio()`  of RiskTranches from msg.sender to CBB
        TransferHelper.safeTransferFrom(
            address(riskTranche()),
            _msgSender(),
            address(this),
            (_safeTrancheAmount * riskRatio()) / safeRatio()
        );

        //- mints `_safeTrancheAmount` of BorrowerSlips to `_borrower`
        ICBBSlip(s_borrowSlipTokenAddress).mint(_borrower, _safeTrancheAmount);

        //add event stuff
    }

    function depositLend(address _lender, uint256 _lendAmount)
        external
        override
    {
        //- Ensure CBB not reinitialized

        //- transfers `_lendAmount`of Stable Tokens from msg.sender to SB
        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            address(this),
            _lendAmount
        );

        //- mints `_lendAmount`of LenderSlips to `_lender`
        ICBBSlip(s_lendSlipTokenAddress).mint(_lender, _lendAmount);

        //add event stuff
    }

    function withdrawBorrow(uint256 _borrowSlipAmount) external override {
        //- Reverse of depositBorrow() function
        //- transfers `_borrowSlipAmount` of SafeTranche Tokens from CB to msg.sender
        TransferHelper.safeTransfer(
            address(safeTranche()),
            _msgSender(),
            (_borrowSlipAmount)
        );

        //- transfers `_borrowSlipAmount*riskRatio()/safeRatio()` of RiskTranche Tokens from CB to msg.sender
        TransferHelper.safeTransfer(
            address(safeTranche()),
            _msgSender(),
            (_borrowSlipAmount * riskRatio()) / safeRatio()
        );

        //- burns `_borrowSlipAmount` of msg.sender’s BorrowSlips
        ICBBSlip(s_borrowSlipTokenAddress).burn(
            _msgSender(),
            _borrowSlipAmount
        );

        //event stuff
    }

    function withdrawLend(uint256 _lendSlipAmount) external override {
        //- Reverse of depositBorrow() function
        //- transfers `_lendSlipAmount` of Stable Tokens from SB to msg.sender
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            _lendSlipAmount
        );

        //- burns `_lendSlipAmount` of msg.sender’s LenderSlips
        ICBBSlip(s_lendSlipTokenAddress).burn(_msgSender(), _lendSlipAmount);

        //event stuff
    }

    function redeemBorrowSlip(uint256 _borrowSlipAmount) external override {
        // Ensure CBB is reinitialized (may not be necessary)
        // Transfer `_borrowSlipAmount*riskRatio()/safeRatio()` of RiskSlips to msg.sender
        TransferHelper.safeTransfer(
            riskSlipAddress(),
            _msgSender(),
            (_borrowSlipAmount * riskRatio()) / safeRatio()
        );

        // Transfer `_borrowSlipAmount*initialPrice()/priceGranularity()` of StableToken to msg.sender
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            (_borrowSlipAmount * initialPrice()) / priceGranularity()
        );

        // burns `_borrowSlipAmount` of msg.sender’s BorrowSlips
        ICBBSlip(s_borrowSlipTokenAddress).burn(
            _msgSender(),
            _borrowSlipAmount
        );

        //event stuff
    }

    function redeemLendSlip(uint256 _lendSlipAmount) external override {
        //- Ensure CBB is reinitialized (may not be necessary since reinitializer already covers)

        //- Transfer `_lendSlipAmount*priceGranularity()/initialPrice()`  of SafeSlips to msg.sender
        TransferHelper.safeTransfer(
            safeSlipAddress(),
            _msgSender(),
            (_lendSlipAmount * priceGranularity()) / initialPrice()
        );

        //- burns `_lendSlipAmount` of msg.sender’s LendSlips
        ICBBSlip(s_lendSlipTokenAddress).burn(_msgSender(), _lendSlipAmount);

        //event stuff
    }

    function transmitReInit(bool _isLend) external override onlyOwner {
        /*
        - calls `CBB.reinitialize(…)`
            - `Address(this)` as borrower + lender
            - if `_lendOrBorrow` is true: calls CBB with balance of StableAmount
            - if `_lendOrBorrow` is false: calls CBB with balance of SafeTrancheAmount
        */

        if (_isLend) {
            uint256 stableAmount = stableToken().balanceOf(address(this));
            convertibleBondBox().reinitialize(
                address(this),
                address(this),
                0,
                stableAmount,
                initialPrice()
            );
        }

        if (!_isLend) {
            uint256 safeTrancheBalance = safeTranche().balanceOf(address(this));
            convertibleBondBox().reinitialize(
                address(this),
                address(this),
                safeTrancheBalance,
                0,
                initialPrice()
            );
        }

        //- calls `CBB.transferOwner(owner())` to transfer ownership of CBB back to Owner()

        convertibleBondBox().cbbTransferOwnership(owner());
    }

    function sbTransferOwnership(address _newOwner)
        external
        override
        onlyOwner
    {
        transferOwnership(_newOwner);
    }
}
