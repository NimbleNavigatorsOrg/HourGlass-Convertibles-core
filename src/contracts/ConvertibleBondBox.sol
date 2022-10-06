//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../utils/CBBImmutableArgs.sol";
import "../interfaces/IConvertibleBondBox.sol";

/**
 * @dev Convertible Bond Box for a ButtonTranche bond
 *
 * Invariants:
 *  - `initial Price must be < $1.00`
 *  - penalty ratio must be < 1.0
 *  - safeTranche index must not be Z-tranche
 */
contract ConvertibleBondBox is
    OwnableUpgradeable,
    CBBImmutableArgs,
    IConvertibleBondBox
{
    // Set when activated
    uint256 public override s_startDate;
    uint256 public s_initialPrice;

    uint256 public override s_repaidBondSlips;

    // Changeable by owner
    uint256 public override feeBps;

    uint256 public constant override s_trancheGranularity = 1000;
    uint256 public constant override s_penaltyGranularity = 1000;
    uint256 public constant override s_priceGranularity = 1e8;

    // Denominator for basis points. Used to calculate fees
    uint256 public constant override BPS = 10_000;
    uint256 public constant override maxFeeBPS = 50;

    modifier afterActivate() {
        if (s_startDate == 0) {
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });
        }
        _;
    }

    modifier beforeBondMature() {
        if (block.timestamp >= maturityDate()) {
            revert BondIsMature({
                currentTime: block.timestamp,
                maturity: maturityDate()
            });
        }
        _;
    }

    modifier afterBondMature() {
        if (block.timestamp < maturityDate()) {
            revert BondNotMatureYet({
                maturityDate: maturityDate(),
                currentTime: block.timestamp
            });
        }
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount < 1e6) {
            revert MinimumInput({input: amount, reqInput: 1e6});
        }
        _;
    }

    function initialize(address _owner) external initializer beforeBondMature {
        require(
            _owner != address(0),
            "ConvertibleBondBox: invalid owner address"
        );

        // Revert if penalty too high
        if (penalty() > s_penaltyGranularity) {
            revert PenaltyTooHigh({
                given: penalty(),
                maxPenalty: s_penaltyGranularity
            });
        }

        // Set owner
        __Ownable_init();
        transferOwnership(_owner);

        emit Initialized(_owner);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function activate(uint256 _initialPrice)
        external
        reinitializer(2)
        onlyOwner
        beforeBondMature
    {
        if (_initialPrice > s_priceGranularity)
            revert InitialPriceTooHigh({
                given: _initialPrice,
                maxPrice: s_priceGranularity
            });
        if (_initialPrice == 0)
            revert InitialPriceIsZero({given: 0, maxPrice: s_priceGranularity});

        s_initialPrice = _initialPrice;

        //set ConvertibleBondBox Start Date to be time when init() is called
        s_startDate = block.timestamp;

        emit Activated(_initialPrice, block.timestamp);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function lend(
        address _borrower,
        address _lender,
        uint256 _stableAmount
    )
        external
        override
        afterActivate
        beforeBondMature
        validAmount(_stableAmount)
    {
        uint256 price = currentPrice();

        uint256 bondSlipAmount = (_stableAmount *
            s_priceGranularity *
            trancheDecimals()) /
            price /
            stableDecimals();

        uint256 zTrancheAmount = (bondSlipAmount * riskRatio()) / safeRatio();

        _atomicDeposit(
            _borrower,
            _lender,
            _stableAmount,
            bondSlipAmount,
            zTrancheAmount
        );

        emit Lend(_msgSender(), _borrower, _lender, _stableAmount, price);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function borrow(
        address _borrower,
        address _lender,
        uint256 _safeTrancheAmount
    )
        external
        override
        afterActivate
        beforeBondMature
        validAmount(_safeTrancheAmount)
    {
        uint256 price = currentPrice();

        uint256 zTrancheAmount = (_safeTrancheAmount * riskRatio()) /
            safeRatio();
        uint256 stableAmount = (_safeTrancheAmount * price * stableDecimals()) /
            s_priceGranularity /
            trancheDecimals();

        _atomicDeposit(
            _borrower,
            _lender,
            stableAmount,
            _safeTrancheAmount,
            zTrancheAmount
        );

        emit Borrow(
            _msgSender(),
            _borrower,
            _lender,
            _safeTrancheAmount,
            price
        );
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function currentPrice() public view override returns (uint256) {
        if (block.timestamp < maturityDate()) {
            uint256 price = s_priceGranularity -
                ((s_priceGranularity - s_initialPrice) *
                    (maturityDate() - block.timestamp)) /
                (maturityDate() - s_startDate);

            return price;
        } else {
            return s_priceGranularity;
        }
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function repay(uint256 _stableAmount)
        external
        override
        afterActivate
        validAmount(_stableAmount)
    {
        //Load into memory
        uint256 price = currentPrice();

        //calculate inputs for internal redeem function
        uint256 stableFees = (_stableAmount * feeBps) / BPS;
        uint256 safeTranchePayout = (_stableAmount *
            s_priceGranularity *
            trancheDecimals()) /
            price /
            stableDecimals();
        uint256 riskTranchePayout = (safeTranchePayout * riskRatio()) /
            safeRatio();

        _repay(_stableAmount, stableFees, safeTranchePayout, riskTranchePayout);
        emit Repay(_msgSender(), _stableAmount, riskTranchePayout, price);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function repayMax(uint256 _debtSlipAmount)
        external
        override
        afterActivate
        validAmount(_debtSlipAmount)
    {
        // Load params into memory
        uint256 price = currentPrice();

        // Calculate inputs for internal repay function
        uint256 safeTranchePayout = (_debtSlipAmount * safeRatio()) /
            riskRatio();
        uint256 stablesOwed = (safeTranchePayout * price * stableDecimals()) /
            s_priceGranularity /
            trancheDecimals();
        uint256 stableFees = (stablesOwed * feeBps) / BPS;

        _repay(stablesOwed, stableFees, safeTranchePayout, _debtSlipAmount);

        //emit event
        emit Repay(_msgSender(), stablesOwed, _debtSlipAmount, price);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function redeemRiskTranche(uint256 _debtSlipAmount)
        external
        override
        afterBondMature
        validAmount(_debtSlipAmount)
    {
        //transfer fee to owner
        if (feeBps > 0 && _msgSender() != owner()) {
            uint256 feeSlip = (_debtSlipAmount * feeBps) / BPS;
            debtSlip().transferFrom(_msgSender(), owner(), feeSlip);
            _debtSlipAmount -= feeSlip;
        }

        uint256 zTranchePayout = (_debtSlipAmount *
            (s_penaltyGranularity - penalty())) / (s_penaltyGranularity);

        //transfer Z-tranches from ConvertibleBondBox to msg.sender
        riskTranche().transfer(_msgSender(), zTranchePayout);

        debtSlip().burn(_msgSender(), _debtSlipAmount);

        emit RedeemRiskTranche(_msgSender(), _debtSlipAmount);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function redeemSafeTranche(uint256 _bondSlipAmount)
        external
        override
        afterBondMature
        validAmount(_bondSlipAmount)
    {
        //transfer fee to owner
        if (feeBps > 0 && _msgSender() != owner()) {
            uint256 feeSlip = (_bondSlipAmount * feeBps) / BPS;
            bondSlip().transferFrom(_msgSender(), owner(), feeSlip);
            _bondSlipAmount -= feeSlip;
        }

        uint256 bondSlipSupply = bondSlip().totalSupply();

        //burn safe-slips
        bondSlip().burn(_msgSender(), _bondSlipAmount);

        //transfer safe-Tranche after maturity only
        safeTranche().transfer(_msgSender(), _bondSlipAmount);

        uint256 zPenaltyTotal = riskTranche().balanceOf(address(this)) -
            debtSlip().totalSupply();

        //transfer risk-Tranche penalty after maturity only
        riskTranche().transfer(
            _msgSender(),
            (_bondSlipAmount * zPenaltyTotal) /
                (bondSlipSupply - s_repaidBondSlips)
        );

        emit RedeemSafeTranche(_msgSender(), _bondSlipAmount);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function redeemStable(uint256 _bondSlipAmount)
        external
        override
        validAmount(_bondSlipAmount)
    {
        //transfer bondSlips to owner
        if (feeBps > 0 && _msgSender() != owner()) {
            uint256 feeSlip = (_bondSlipAmount * feeBps) / BPS;
            bondSlip().transferFrom(_msgSender(), owner(), feeSlip);
            _bondSlipAmount -= feeSlip;
        }

        uint256 stableBalance = stableToken().balanceOf(address(this));

        //transfer stables
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            (_bondSlipAmount * stableBalance) / (s_repaidBondSlips)
        );

        //burn safe-slips
        bondSlip().burn(_msgSender(), _bondSlipAmount);
        s_repaidBondSlips -= _bondSlipAmount;

        emit RedeemStable(_msgSender(), _bondSlipAmount, currentPrice());
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function setFee(uint256 newFeeBps)
        external
        override
        onlyOwner
        beforeBondMature
    {
        if (newFeeBps > maxFeeBPS)
            revert FeeTooLarge({input: newFeeBps, maximum: maxFeeBPS});

        feeBps = newFeeBps;
        emit FeeUpdate(newFeeBps);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */
    function transferOwnership(address newOwner)
        public
        override(IConvertibleBondBox, OwnableUpgradeable)
        onlyOwner
    {
        _transferOwnership(newOwner);
    }

    function _atomicDeposit(
        address _borrower,
        address _lender,
        uint256 _stableAmount,
        uint256 _bondSlipAmount,
        uint256 _debtSlipAmount
    ) internal {
        //Transfer safeTranche to ConvertibleBondBox
        safeTranche().transferFrom(
            _msgSender(),
            address(this),
            _bondSlipAmount
        );

        //Transfer riskTranche to ConvertibleBondBox
        riskTranche().transferFrom(
            _msgSender(),
            address(this),
            _debtSlipAmount
        );

        // //Mint bondSlips to the lender
        bondSlip().mint(_lender, _bondSlipAmount);

        // //Mint debtSlips to the borrower
        debtSlip().mint(_borrower, _debtSlipAmount);

        // // Transfer stables to borrower
        if (_msgSender() != _borrower) {
            TransferHelper.safeTransferFrom(
                address(stableToken()),
                _msgSender(),
                _borrower,
                _stableAmount
            );
        }
    }

    function _repay(
        uint256 _stablesOwed,
        uint256 _stableFees,
        uint256 _safeTranchePayout,
        uint256 _riskTranchePayout
    ) internal {
        // Update total repaid bondSlips
        s_repaidBondSlips += _safeTranchePayout;

        // Transfer fees to owner
        if (feeBps > 0 && _msgSender() != owner()) {
            TransferHelper.safeTransferFrom(
                address(stableToken()),
                _msgSender(),
                owner(),
                _stableFees
            );
        }

        // Transfers stables to CBB
        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            address(this),
            _stablesOwed
        );

        // Transfer safeTranches to msg.sender (increment state)
        safeTranche().transfer(_msgSender(), _safeTranchePayout);

        // Transfer riskTranches to msg.sender
        riskTranche().transfer(_msgSender(), _riskTranchePayout);

        // Burn debtSlips
        debtSlip().burn(_msgSender(), _riskTranchePayout);
    }
}
