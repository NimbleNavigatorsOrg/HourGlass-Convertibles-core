//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "clones-with-immutable-args/Clone.sol";
import "../interfaces/IButtonWoodBondController.sol";
import "../interfaces/ISlipFactory.sol";
import "../interfaces/ISlip.sol";
import "../../utils/CBBImmutableArgs.sol";
import "../interfaces/IConvertibleBondBox.sol";

import "forge-std/console2.sol";

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
    Clone,
    CBBImmutableArgs,
    IConvertibleBondBox
{
    address public override s_safeSlipTokenAddress;
    address public override s_riskSlipTokenAddress;
    uint256 public override s_startDate = 0;
    uint256 public override s_repaidSafeSlips = 0;
    uint256 public constant override s_trancheGranularity = 1000;
    uint256 public constant override s_penaltyGranularity = 1000;
    uint256 public constant override s_priceGranularity = 1e9;
    uint256 public override feeBps = 0;

    uint256 public s_initialPrice = 0;

    // Denominator for basis points. Used to calculate fees
    uint256 public constant override BPS = 10_000;
    uint256 public constant override maxFeeBPS = 50;

    function initialize(address _owner) external initializer {
        require(
            _owner != address(0),
            "ConvertibleBondBox: invalid owner address"
        );
        __Ownable_init();
        transferOwnership(_owner);

        if (penalty() > s_trancheGranularity)
            revert PenaltyTooHigh({
                given: penalty(),
                maxPenalty: s_penaltyGranularity
            });
        if (bond().isMature())
            revert BondIsMature({given: bond().isMature(), required: false});
        // Safe-Tranche cannot be the Z-Tranche
        if (trancheIndex() >= trancheCount() - 1)
            revert TrancheIndexOutOfBounds({
                given: trancheIndex(),
                maxIndex: trancheCount() - 2
            });

        // clone deploy safe slip
        s_safeSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Safe-CBB-Slip",
            address(safeTranche())
        );

        //clone deploy z slip
        s_riskSlipTokenAddress = slipFactory().createSlip(
            "ASSET-Tranche",
            "Risk-CBB-Slip",
            address(riskTranche())
        );
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function reinitialize(
        address _borrower,
        address _lender,
        uint256 _safeTrancheAmount,
        uint256 _stableAmount,
        uint256 _initialPrice
    ) external reinitializer(2) onlyOwner returns (bool) {
        uint256 priceGranularity = s_priceGranularity;
        if (_stableAmount * _safeTrancheAmount != 0)
            revert OnlyLendOrBorrow({
                _stableAmount: _stableAmount,
                _collateralAmount: _safeTrancheAmount
            });
        if (_initialPrice > priceGranularity)
            revert InitialPriceTooHigh({
                given: _initialPrice,
                maxPrice: priceGranularity
            });
        if (_initialPrice == 0)
            revert InitialPriceIsZero({given: 0, maxPrice: priceGranularity});
        s_initialPrice = _initialPrice;

        //set ConvertibleBondBox Start Date to be time when init() is called
        s_startDate = block.timestamp;

        emit Initialized(_borrower, _lender, _stableAmount, _safeTrancheAmount);
        return true;
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function lend(
        address _borrower,
        address _lender,
        uint256 _stableAmount
    ) external override {
        uint256 priceGranularity = s_priceGranularity;
        uint256 price = this.currentPrice();

        //Need to justify amounts
        if (_stableAmount < (safeRatio() * price) / priceGranularity)
            revert MinimumInput({
                input: _stableAmount,
                reqInput: (safeRatio() * price) / priceGranularity
            });

        uint256 mintAmount = (_stableAmount * priceGranularity) / price;

        uint256 zTrancheAmount = (mintAmount * riskRatio()) / safeRatio();

        _atomicDeposit(
            _borrower,
            _lender,
            _stableAmount,
            mintAmount,
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
    ) external override {
        if (_safeTrancheAmount < safeRatio())
            revert MinimumInput({
                input: _safeTrancheAmount,
                reqInput: safeRatio()
            });

        uint256 price = this.currentPrice();

        uint256 zTrancheAmount = (_safeTrancheAmount * riskRatio()) /
            safeRatio();
        uint256 stableAmount = (_safeTrancheAmount * price) /
            s_priceGranularity;

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

    function currentPrice() external view override returns (uint256) {
        //load storage variables into memory
        console2.log("1");
        uint256 price = s_priceGranularity;
                console2.log("2");

        uint256 maturityDate = maturityDate();
                console2.log("3");

                console2.log(s_initialPrice, "s_initialPrice");
                console2.log(price, "price");
                console2.log(maturityDate, "maturityDate");
                console2.log(block.timestamp, "block.timestamp");
                console2.log(s_startDate, "s_startDate");



        //TODO replace math below with full math to enable larger deposit amounts
        //TODO figure out how to calculate price when line 215 is smaller than line 216&&217
        if (block.timestamp < maturityDate) {

            price =
                price -
                ((price - s_initialPrice) * (maturityDate - block.timestamp)) /
                (maturityDate - s_startDate);
        }
                console2.log("4");

        return price;
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function repay(uint256 _stableAmount) external override {
        //Load into memory
        uint256 price = this.currentPrice();
        uint256 priceGranularity = s_priceGranularity;

        if (_stableAmount < (safeRatio() * price) / priceGranularity)
            revert MinimumInput({
                input: _stableAmount,
                reqInput: (safeRatio() * price) / priceGranularity
            });

        //calculate inputs for internal redeem function
        uint256 stableFees = (_stableAmount * feeBps) / BPS;
        uint256 safeTranchePayout = (_stableAmount * priceGranularity) / price;
        uint256 riskTranchePayout = (safeTranchePayout * riskRatio()) /
            safeRatio();

        _repay(_stableAmount, stableFees, safeTranchePayout, riskTranchePayout);
        emit Repay(_msgSender(), _stableAmount, riskTranchePayout, price);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function repayMax(uint256 _riskSlipAmount) external override {
        // Load params into memory
        uint256 price = this.currentPrice();

        // check min input
        if (_riskSlipAmount < riskRatio())
            revert MinimumInput({
                input: _riskSlipAmount,
                reqInput: riskRatio()
            });

        // Calculate inputs for internal repay function
        uint256 safeTranchePayout = (_riskSlipAmount * safeRatio()) /
            riskRatio();
        uint256 stablesOwed = (safeTranchePayout * price) / s_priceGranularity;
        uint256 stableFees = (stablesOwed * feeBps) / BPS;

        _repay(stablesOwed, stableFees, safeTranchePayout, _riskSlipAmount);

        //emit event
        emit Repay(_msgSender(), stablesOwed, _riskSlipAmount, price);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function redeemRiskTranche(uint256 _riskSlipAmount) external override {
        if (block.timestamp < maturityDate())
            revert BondNotMatureYet({
                maturityDate: maturityDate(),
                currentTime: block.timestamp
            });

        if (_riskSlipAmount < riskRatio())
            revert MinimumInput({
                input: _riskSlipAmount,
                reqInput: riskRatio()
            });

        //transfer fee to owner
        if (feeBps > 0 && _msgSender() != owner()) {
            uint256 feeSlip = (_riskSlipAmount * feeBps) / BPS;
            TransferHelper.safeTransferFrom(
                s_riskSlipTokenAddress,
                _msgSender(),
                owner(),
                feeSlip
            );

            _riskSlipAmount -= feeSlip;
        }

        uint256 zTranchePayout = _riskSlipAmount;
        zTranchePayout =
            (zTranchePayout * (s_penaltyGranularity - penalty())) /
            (s_penaltyGranularity);

        //transfer Z-tranches from ConvertibleBondBox to msg.sender
        TransferHelper.safeTransfer(
            address(riskTranche()),
            _msgSender(),
            zTranchePayout
        );

        ISlip(s_riskSlipTokenAddress).burn(_msgSender(), _riskSlipAmount);

        emit RedeemRiskTranche(_msgSender(), _riskSlipAmount);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function redeemSafeTranche(uint256 _safeSlipAmount) external override {
        if (block.timestamp < maturityDate())
            revert BondNotMatureYet({
                maturityDate: maturityDate(),
                currentTime: block.timestamp
            });

        if (_safeSlipAmount < safeRatio())
            revert MinimumInput({
                input: _safeSlipAmount,
                reqInput: safeRatio()
            });

        address safeSlipTokenAddress = s_safeSlipTokenAddress;

        //transfer fee to owner
        if (feeBps > 0 && _msgSender() != owner()) {
            uint256 feeSlip = (_safeSlipAmount * feeBps) / BPS;
            TransferHelper.safeTransferFrom(
                safeSlipTokenAddress,
                _msgSender(),
                owner(),
                feeSlip
            );

            _safeSlipAmount -= feeSlip;
        }

        uint256 safeSlipSupply = ISlip(safeSlipTokenAddress).totalSupply();

        //burn safe-slips
        ISlip(safeSlipTokenAddress).burn(_msgSender(), _safeSlipAmount);

        //transfer safe-Tranche after maturity only
        TransferHelper.safeTransfer(
            address(safeTranche()),
            _msgSender(),
            (_safeSlipAmount)
        );

        uint256 zPenaltyTotal = riskTranche().balanceOf(address(this)) -
            IERC20(s_riskSlipTokenAddress).totalSupply();

        //transfer risk-Tranche penalty after maturity only
        TransferHelper.safeTransfer(
            address(riskTranche()),
            _msgSender(),
            (_safeSlipAmount * zPenaltyTotal) /
                (safeSlipSupply - s_repaidSafeSlips)
        );

        emit RedeemSafeTranche(_msgSender(), _safeSlipAmount);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function redeemStable(uint256 _safeSlipAmount) external override {
        if (s_startDate == 0)
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        if (_safeSlipAmount < safeRatio())
            revert MinimumInput({
                input: _safeSlipAmount,
                reqInput: safeRatio()
            });

        address safeSlipTokenAddress = s_safeSlipTokenAddress;

        //transfer safeSlips to owner
        if (feeBps > 0 && _msgSender() != owner()) {
            uint256 feeSlip = (_safeSlipAmount * feeBps) / BPS;
            TransferHelper.safeTransferFrom(
                safeSlipTokenAddress,
                _msgSender(),
                owner(),
                feeSlip
            );

            _safeSlipAmount -= feeSlip;
        }

        uint256 stableBalance = stableToken().balanceOf(address(this));

        //burn safe-slips
        ISlip(safeSlipTokenAddress).burn(_msgSender(), _safeSlipAmount);

        //transfer stables
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            (_safeSlipAmount * stableBalance) / (s_repaidSafeSlips)
        );

        emit RedeemStable(_msgSender(), _safeSlipAmount, this.currentPrice());
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function setFee(uint256 newFeeBps) external override onlyOwner {
        if (bond().isMature())
            revert BondIsMature({given: bond().isMature(), required: false});
        if (newFeeBps > maxFeeBPS)
            revert FeeTooLarge({input: newFeeBps, maximum: maxFeeBPS});
        feeBps = newFeeBps;
        emit FeeUpdate(newFeeBps);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function cbbTransferOwnership(address newOwner)
        external
        override
        onlyOwner
    {
        transferOwnership(newOwner);
    }

    function _atomicDeposit(
        address _borrower,
        address _lender,
        uint256 _stableAmount,
        uint256 _safeSlipAmount,
        uint256 _riskSlipAmount
    ) internal {
        if (s_startDate == 0)
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        if (bond().isMature())
            revert BondIsMature({given: bond().isMature(), required: false});

        //Transfer safeTranche to ConvertibleBondBox
        TransferHelper.safeTransferFrom(
            address(safeTranche()),
            _msgSender(),
            address(this),
            _safeSlipAmount
        );

        //Transfer riskTranche to ConvertibleBondBox
        TransferHelper.safeTransferFrom(
            address(riskTranche()),
            _msgSender(),
            address(this),
            _riskSlipAmount
        );

        // //Mint safeSlips to the lender
        ISlip(s_safeSlipTokenAddress).mint(_lender, _safeSlipAmount);

        // //Mint riskSlips to the borrower
        ISlip(s_riskSlipTokenAddress).mint(_borrower, _riskSlipAmount);

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
        // Ensure CBB started
        if (s_startDate == 0)
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

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
        TransferHelper.safeTransfer(
            address(safeTranche()),
            _msgSender(),
            _safeTranchePayout
        );

        s_repaidSafeSlips += _safeTranchePayout;

        // Transfer riskTranches to msg.sender
        TransferHelper.safeTransfer(
            address(riskTranche()),
            _msgSender(),
            _riskTranchePayout
        );

        // Burn riskSlips
        ISlip(s_riskSlipTokenAddress).burn(_msgSender(), _riskTranchePayout);
    }
}
