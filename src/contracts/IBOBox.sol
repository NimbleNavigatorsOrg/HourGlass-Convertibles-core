//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../utils/IBOImmutableArgs.sol";
import "../interfaces/IIBOBox.sol";

/**
 * @dev IBO Box for activating a ConvertibleBondBox
 *
 * Invariants:
 *  - `initial Price must be < $1.00`
 */
contract IBOBox is OwnableUpgradeable, IBOImmutableArgs, IIBOBox {
    uint256 public s_activateLendAmount;

    modifier beforeActivate() {
        if (convertibleBondBox().s_startDate() != 0) {
            revert CBBActivated({state: true, requiredState: false});
        }
        _;
    }

    function initialize(address _owner) external initializer {
        require(_owner != address(0), "IBOBox: invalid owner address");
        //check if valid initialPrice immutable arg
        if (initialPrice() > priceGranularity())
            revert InitialPriceTooHigh({
                given: initialPrice(),
                maxPrice: priceGranularity()
            });
        if (initialPrice() == 0)
            revert InitialPriceIsZero({given: 0, maxPrice: priceGranularity()});

        //Setup ownership
        __Ownable_init();
        transferOwnership(_owner);

        //Add event stuff
        emit Initialized(_owner);
    }

    function depositBorrow(address _borrower, uint256 _borrowAmount)
        external
        override
        beforeActivate
    {
        //- transfers `_safeTrancheAmount` of SafeTranche Tokens from msg.sender to IBO

        uint256 safeTrancheAmount = (_borrowAmount *
            priceGranularity() *
            trancheDecimals()) /
            initialPrice() /
            stableDecimals();

        safeTranche().transferFrom(
            _msgSender(),
            address(this),
            safeTrancheAmount
        );

        //- transfers `_safeTrancheAmount * riskRatio() / safeRatio()`  of RiskTranches from msg.sender to IBO

        riskTranche().transferFrom(
            _msgSender(),
            address(this),
            (safeTrancheAmount * riskRatio()) / safeRatio()
        );

        //- mints `_safeTrancheAmount` of BorrowerSlips to `_borrower`
        borrowSlip().mint(_borrower, _borrowAmount);

        //add event stuff
        emit BorrowDeposit(_borrower, _borrowAmount);
    }

    function depositLend(address _lender, uint256 _lendAmount)
        external
        override
        beforeActivate
    {
        //- transfers `_lendAmount`of Stable Tokens from msg.sender to IBO
        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            address(this),
            _lendAmount
        );

        //- mints `_lendAmount`of LenderSlips to `_lender`
        buyOrder().mint(_lender, _lendAmount);

        //add event stuff
        emit LendDeposit(_lender, _lendAmount);
    }

    function withdrawBorrow(uint256 _borrowSlipAmount) external override {
        //- Reverse of depositBorrow() function
        //- transfers `_borrowSlipAmount` of SafeTranche Tokens from IBO to msg.sender

        uint256 safeTrancheAmount = (_borrowSlipAmount *
            priceGranularity() *
            trancheDecimals()) /
            initialPrice() /
            stableDecimals();

        safeTranche().transfer(_msgSender(), (safeTrancheAmount));

        //- transfers `_borrowSlipAmount*riskRatio()/safeRatio()` of RiskTranche Tokens from IBO to msg.sender

        riskTranche().transfer(
            _msgSender(),
            (safeTrancheAmount * riskRatio()) / safeRatio()
        );

        //- burns `_borrowSlipAmount` of msg.sender’s BorrowSlips
        borrowSlip().burn(_msgSender(), _borrowSlipAmount);

        //event stuff
        emit BorrowWithdrawal(_msgSender(), _borrowSlipAmount);
    }

    function withdrawLend(uint256 _buyOrderAmount) external override {
        //- Reverse of depositBorrow() function

        //revert check for _buyOrderAmount after CBB activated
        if (convertibleBondBox().s_startDate() != 0) {
            uint256 maxWithdrawAmount = stableToken().balanceOf(address(this)) -
                s_activateLendAmount;
            if (_buyOrderAmount > maxWithdrawAmount) {
                revert WithdrawAmountTooHigh({
                    requestAmount: _buyOrderAmount,
                    maxAmount: maxWithdrawAmount
                });
            }
        }

        //- transfers `_buyOrderAmount` of Stable Tokens from IBO to msg.sender
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            _buyOrderAmount
        );

        //- burns `_buyOrderAmount` of msg.sender’s LenderSlips
        buyOrder().burn(_msgSender(), _buyOrderAmount);

        //event stuff
        emit LendWithdrawal(_msgSender(), _buyOrderAmount);
    }

    function redeemBorrowSlip(uint256 _borrowSlipAmount) external override {
        // Transfer `_borrowSlipAmount*riskRatio()/safeRatio()` of DebtSlips to msg.sender
        ISlip(debtSlipAddress()).transfer(
            _msgSender(),
            ((_borrowSlipAmount *
                priceGranularity() *
                riskRatio() *
                trancheDecimals()) /
                initialPrice() /
                safeRatio() /
                stableDecimals())
        );

        // Transfer `_borrowSlipAmount*initialPrice()/priceGranularity()` of StableToken to msg.sender
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            _borrowSlipAmount
        );

        // burns `_borrowSlipAmount` of msg.sender’s BorrowSlips
        borrowSlip().burn(_msgSender(), _borrowSlipAmount);

        //decrement s_activateLendAmount
        s_activateLendAmount -= _borrowSlipAmount;

        //event stuff
        emit RedeemBorrowSlip(_msgSender(), _borrowSlipAmount);
    }

    function redeemBuyOrder(uint256 _buyOrderAmount) external override {
        //- Transfer `_buyOrderAmount*priceGranularity()/initialPrice()`  of BondSlips to msg.sender
        ISlip(bondSlipAddress()).transfer(
            _msgSender(),
            (_buyOrderAmount * priceGranularity() * trancheDecimals()) /
                initialPrice() /
                stableDecimals()
        );

        //- burns `_buyOrderAmount` of msg.sender’s BuyOrders
        buyOrder().burn(_msgSender(), _buyOrderAmount);

        emit RedeemBuyOrder(_msgSender(), _buyOrderAmount);
    }

    function transmitActivate(bool _isLend) external override onlyOwner {
        /*
        - calls `CBB.activate(…)`
            - `Address(this)` as borrower + lender
            - if `_isLend` is true: calls CBB with balance of StableAmount
            - if `_isLend` is false: calls CBB with balance of SafeTrancheAmount
        */

        safeTranche().approve(address(convertibleBondBox()), type(uint256).max);
        riskTranche().approve(address(convertibleBondBox()), type(uint256).max);

        if (_isLend) {
            uint256 stableAmount = stableToken().balanceOf(address(this));
            s_activateLendAmount = stableAmount;
            convertibleBondBox().activate(initialPrice());
            convertibleBondBox().lend(
                address(this),
                address(this),
                stableAmount
            );
        }

        if (!_isLend) {
            uint256 safeTrancheBalance = safeTranche().balanceOf(address(this));
            s_activateLendAmount =
                (safeTrancheBalance * initialPrice() * stableDecimals()) /
                priceGranularity() /
                trancheDecimals();

            convertibleBondBox().activate(initialPrice());

            convertibleBondBox().borrow(
                address(this),
                address(this),
                safeTrancheBalance
            );
        }

        //- calls `CBB.transferOwner(owner())` to transfer ownership of CBB back to Owner()
        convertibleBondBox().transferOwnership(owner());
    }

    function transferOwnership(address newOwner)
        public
        override(IIBOBox, OwnableUpgradeable)
        onlyOwner
    {
        _transferOwnership(newOwner);
    }

    function transferCBBOwnership(address newOwner) public override onlyOwner {
        convertibleBondBox().transferOwnership(newOwner);
    }
}
