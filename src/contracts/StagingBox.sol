//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../interfaces/ISlipFactory.sol";
import "../interfaces/ISlip.sol";
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

    uint256 public s_reinitLendAmount = 0;
    bool public s_hasReinitialized = false;

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
        if (initialPrice() == 0)
            revert InitialPriceIsZero({
                given: 0,
                maxPrice: priceGranularity()
            });

        //Setup ownership
        __Ownable_init();
        transferOwnership(_owner);

        //Deploy Borrow Lend Slips
        //TODO: Need to use ERC20 meta-data and revise slip factory inputs
        // clone deploy safe slip
        s_lendSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Staging-Lender-Slip",
            address(this)
        );

        //clone deploy z slip
        s_borrowSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Staging-Borrower-Slip",
            address(this)
        );

        //Check if valid ICBB immutable arg?

        //Add event stuff
        emit Initialized(
            _owner,
            s_borrowSlipTokenAddress,
            s_lendSlipTokenAddress
        );
    }

    function depositBorrow(address _borrower, uint256 _safeTrancheAmount)
        external
        override
    {
        //- Ensure CBB not reinitialized
        bool hasReinitialized = s_hasReinitialized;
        if (hasReinitialized) {
            revert CBBReinitialized({
                state: hasReinitialized,
                requiredState: false
            });
        }

        //- transfers `_safeTrancheAmount` of SafeTranche Tokens from msg.sender to SB
        TransferHelper.safeTransferFrom(
            address(safeTranche()),
            _msgSender(),
            address(this),
            _safeTrancheAmount
        );

        //- transfers `_safeTrancheAmount * riskRatio() / safeRatio()`  of RiskTranches from msg.sender to SB
        TransferHelper.safeTransferFrom(
            address(riskTranche()),
            _msgSender(),
            address(this),
            (_safeTrancheAmount * riskRatio()) / safeRatio()
        );

        //- mints `_safeTrancheAmount` of BorrowerSlips to `_borrower`
        // TODO shouldn't we be minting to the same address that the SB took tranches from. ie. _msgSender()
        ISlip(s_borrowSlipTokenAddress).mint(_borrower, _safeTrancheAmount);

        //add event stuff
        emit BorrowDeposit(_borrower, _safeTrancheAmount);
    }

    function depositLend(address _lender, uint256 _lendAmount)
        external
        override
    {
        //- Ensure CBB not reinitialized
        bool hasReinitialized = s_hasReinitialized;
        if (hasReinitialized) {
            revert CBBReinitialized({
                state: hasReinitialized,
                requiredState: false
            });
        }

        //- transfers `_lendAmount`of Stable Tokens from msg.sender to SB
        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            address(this),
            _lendAmount
        );

        //- mints `_lendAmount`of LenderSlips to `_lender`
        ISlip(s_lendSlipTokenAddress).mint(_lender, _lendAmount);

        //add event stuff
        emit LendDeposit(_lender, _lendAmount);
    }

    function withdrawBorrow(uint256 _borrowSlipAmount) external override {
        //- Reverse of depositBorrow() function
        //- transfers `_borrowSlipAmount` of SafeTranche Tokens from SB to msg.sender
        TransferHelper.safeTransfer(
            address(safeTranche()),
            _msgSender(),
            (_borrowSlipAmount)
        );

        //- transfers `_borrowSlipAmount*riskRatio()/safeRatio()` of RiskTranche Tokens from SB to msg.sender
        TransferHelper.safeTransfer(
            address(riskTranche()),
            _msgSender(),
            (_borrowSlipAmount * riskRatio()) / safeRatio()
        );

        //- burns `_borrowSlipAmount` of msg.sender’s BorrowSlips
        ISlip(s_borrowSlipTokenAddress).burn(
            _msgSender(),
            _borrowSlipAmount
        );

        //event stuff
        emit BorrowWithdrawal(_msgSender(), _borrowSlipAmount);
    }

    function withdrawLend(uint256 _lendSlipAmount) external override {
        //- Reverse of depositBorrow() function

        //revert check for _lendSlipAmount after CBB reinitialized
        if (s_hasReinitialized) {
            uint256 reinitAmount = s_reinitLendAmount;
            if (_lendSlipAmount < reinitAmount) {
                revert WithdrawAmountTooHigh({
                    requestAmount: _lendSlipAmount,
                    maxAmount: reinitAmount
                });
            }
        }

        //- transfers `_lendSlipAmount` of Stable Tokens from SB to msg.sender
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            _lendSlipAmount
        );

        //- burns `_lendSlipAmount` of msg.sender’s LenderSlips
        ISlip(s_lendSlipTokenAddress).burn(_msgSender(), _lendSlipAmount);

        //event stuff
        emit LendWithdrawal(_msgSender(), _lendSlipAmount);
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
        ISlip(s_borrowSlipTokenAddress).burn(
            _msgSender(),
            _borrowSlipAmount
        );

        //event stuff
        emit RedeemBorrowSlip(_msgSender(), _borrowSlipAmount);
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
        ISlip(s_lendSlipTokenAddress).burn(_msgSender(), _lendSlipAmount);

        emit RedeemLendSlip(_msgSender(), _lendSlipAmount);
    }

    function transmitReInit(bool _isLend) external override onlyOwner {
        /*
        - calls `CBB.reinitialize(…)`
            - `Address(this)` as borrower + lender
            - if `_isLend` is true: calls CBB with balance of StableAmount
            - if `_isLend` is false: calls CBB with balance of SafeTrancheAmount
        */

        if (_isLend) {
            uint256 stableAmount = stableToken().balanceOf(address(this));
            s_reinitLendAmount = stableAmount;
            s_hasReinitialized = convertibleBondBox().reinitialize(
                address(this),
                address(this),
                0,
                stableAmount,
                initialPrice()
            );

            convertibleBondBox().lend(address(this), address(this), stableAmount);
        }

        if (!_isLend) {
            uint256 safeTrancheBalance = safeTranche().balanceOf(address(this));
            s_reinitLendAmount = (safeTrancheBalance * initialPrice()) / priceGranularity();

            s_hasReinitialized = convertibleBondBox().reinitialize(
                address(this),
                address(this),
                safeTrancheBalance,
                0,
                initialPrice()
            );

            convertibleBondBox().borrow(address(this), address(this), safeTrancheBalance);
        }

        //- calls `CBB.transferOwner(owner())` to transfer ownership of CBB back to Owner()
        convertibleBondBox().cbbTransferOwnership(owner());
    }

    function sbTransferOwnership(address _newOwner) external override onlyOwner {
        transferOwnership(_newOwner);
    }
}
