//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "clones-with-immutable-args/Clone.sol";
import "../interfaces/IButtonWoodBondController.sol";
import "../interfaces/ICBBSlipFactory.sol";
import "../interfaces/ICBBSlip.sol";
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
    }

    function reinitialize(
        address _borrower,
        address _lender,
        uint256 _safeTrancheAmount,
        uint256 _stableAmount
    ) external reinitializer(2) onlyOwner() {
        uint256 priceGranularity = s_priceGranularity;
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
        if (initialPrice() > priceGranularity)
            revert InitialPriceTooHigh({
                given: initialPrice(),
                maxPrice: priceGranularity
            });
        if (_stableAmount * _safeTrancheAmount != 0)
            revert OnlyLendOrBorrow({
                _stableAmount: _stableAmount,
                _collateralAmount: _safeTrancheAmount
            });

        ITranche safeTranche = safeTranche();
        ITranche riskTranche = riskTranche();

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

        //set ConvertibleBondBox Start Date to be time when init() is called
        s_startDate = block.timestamp;

        // initial borrow/lend at initialPrice, provided matching order is provided

        if (_stableAmount != 0) {
            (bool success, ) = address(this).delegatecall(
                abi.encodeWithSignature(
                    "lend(address,address,uint256)",
                    _borrower,
                    _lender,
                    _stableAmount
                )
            );
            require(success);
        }

        if (_safeTrancheAmount != 0) {
            (bool success, ) = address(this).delegatecall(
                abi.encodeWithSignature(
                    "borrow(address,address,uint256)",
                    _borrower,
                    _lender,
                    _safeTrancheAmount
                )
            );
            require(success);
        }

        emit Initialized(_borrower, _lender, _stableAmount, _safeTrancheAmount);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function lend(
        address _borrower,
        address _lender,
        uint256 _stableAmount
    ) external override {
        if (s_startDate == 0)
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });
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
        if (s_startDate == 0)
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        //revert for bond already mature (move to atomic deposit)

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
     * @dev returns time-weighted current price for Tranches, with final price as $1.00 at maturity
     */

    function currentPrice() external view override returns (uint256) {
        //load storage variables into memory
        uint256 price = s_priceGranularity;
        uint256 maturityDate = maturityDate();

        if (block.timestamp < maturityDate) {
            price =
                price -
                ((price - initialPrice()) * (maturityDate - block.timestamp)) /
                (maturityDate - s_startDate);
        }

        return price;
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function repay(uint256 _stableAmount) external override {
        if (s_startDate == 0)
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        //Load into memory
        uint256 price = this.currentPrice();
        uint256 priceGranularity = s_priceGranularity;

        if (_stableAmount < (safeRatio() * price) / priceGranularity)
            revert MinimumInput({
                input: _stableAmount,
                reqInput: (safeRatio() * price) / priceGranularity
            });

        // Calculate safeTranche payout
        //TODO: Decimals conversion?
        uint256 safeTranchePayout = (_stableAmount * priceGranularity) / price;

        //Repay stables to ConvertibleBondBox
        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            address(this),
            _stableAmount
        );

        if (safeTranche().balanceOf(address(this)) < safeTranchePayout) {
            revert PayoutExceedsBalance({
                safeTranchePayout: safeTranchePayout,
                balance: safeTranche().balanceOf(address(this))
            });
        }

        //transfer A-tranches from ConvertibleBondBox to msg.sender
        TransferHelper.safeTransfer(
            address(safeTranche()),
            _msgSender(),
            safeTranchePayout
        );

        s_repaidSafeSlips += safeTranchePayout;

        //calculate Z-tranche payout
        uint256 zTranchePaidFor = (safeTranchePayout * riskRatio()) /
            safeRatio();

        //transfer fee to owner
        uint256 feeSlip = (zTranchePaidFor * feeBps) / BPS;
        TransferHelper.safeTransferFrom(
            s_riskSlipTokenAddress,
            _msgSender(),
            owner(),
            feeSlip
        );

        //calculate Z-tranche payout
        zTranchePaidFor -= feeSlip;

        //transfer Z-tranches from ConvertibleBondBox to msg.sender
        TransferHelper.safeTransfer(
            address(riskTranche()),
            _msgSender(),
            zTranchePaidFor
        );

        ICBBSlip(s_riskSlipTokenAddress).burn(_msgSender(), zTranchePaidFor);

        emit Repay(_msgSender(), _stableAmount, zTranchePaidFor, price);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function redeemRiskTranche(uint256 riskSlipAmount) external override {
        if (block.timestamp < maturityDate())
            revert BondNotMatureYet({
                maturityDate: maturityDate(),
                currentTime: block.timestamp
            });

        if (riskSlipAmount < riskRatio())
            revert MinimumInput({input: riskSlipAmount, reqInput: riskRatio()});

        //transfer fee to owner
        uint256 feeSlip = (riskSlipAmount * feeBps) / BPS;
        TransferHelper.safeTransferFrom(
            s_riskSlipTokenAddress,
            _msgSender(),
            owner(),
            feeSlip
        );

        riskSlipAmount -= feeSlip;

        uint256 zTranchePayout = riskSlipAmount;
        zTranchePayout =
            (zTranchePayout * (s_penaltyGranularity - penalty())) /
            (s_penaltyGranularity);

        //transfer Z-tranches from ConvertibleBondBox to msg.sender
        TransferHelper.safeTransfer(
            address(riskTranche()),
            _msgSender(),
            zTranchePayout
        );

        ICBBSlip(s_riskSlipTokenAddress).burn(_msgSender(), riskSlipAmount);

        emit RedeemRiskTranche(_msgSender(), riskSlipAmount);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function redeemSafeTranche(uint256 safeSlipAmount) external override {
        if (block.timestamp < maturityDate())
            revert BondNotMatureYet({
                maturityDate: maturityDate(),
                currentTime: block.timestamp
            });

        if (safeSlipAmount < safeRatio())
            revert MinimumInput({input: safeSlipAmount, reqInput: safeRatio()});

        address safeSlipTokenAddress = s_safeSlipTokenAddress;

        //transfer fee to owner
        uint256 feeSlip = (safeSlipAmount * feeBps) / BPS;
        TransferHelper.safeTransferFrom(
            safeSlipTokenAddress,
            _msgSender(),
            owner(),
            feeSlip
        );

        safeSlipAmount -= feeSlip;

        uint256 safeSlipSupply = ICBBSlip(safeSlipTokenAddress).totalSupply();

        //burn safe-slips
        ICBBSlip(safeSlipTokenAddress).burn(_msgSender(), safeSlipAmount);

        //transfer safe-Tranche after maturity only
        TransferHelper.safeTransfer(
            address(safeTranche()),
            _msgSender(),
            (safeSlipAmount)
        );

        uint256 zPenaltyTotal = IERC20(address(riskTranche())).balanceOf(
            address(this)
        ) - IERC20(s_riskSlipTokenAddress).totalSupply();

        //transfer risk-Tranche penalty after maturity only
        TransferHelper.safeTransfer(
            address(riskTranche()),
            _msgSender(),
            (safeSlipAmount * zPenaltyTotal) /
                (safeSlipSupply - s_repaidSafeSlips)
        );

        emit RedeemSafeTranche(_msgSender(), safeSlipAmount);
    }

    /**
     * @inheritdoc IConvertibleBondBox
     */

    function redeemStable(uint256 safeSlipAmount) external override {
        if (s_startDate == 0)
            revert ConvertibleBondBoxNotStarted({
                given: 0,
                minStartDate: block.timestamp
            });

        if (safeSlipAmount < safeRatio())
            revert MinimumInput({input: safeSlipAmount, reqInput: safeRatio()});

        address safeSlipTokenAddress = s_safeSlipTokenAddress;

        //change to owner as recipient

        TransferHelper.safeTransferFrom(
            safeSlipTokenAddress,
            _msgSender(),
            owner(),
            (safeSlipAmount * feeBps) / BPS
        );

        safeSlipAmount *= (BPS - feeBps) / BPS;
        uint256 stableBalance = stableToken().balanceOf(address(this));

        //burn safe-slips
        ICBBSlip(safeSlipTokenAddress).burn(_msgSender(), safeSlipAmount);

        //transfer stables
        TransferHelper.safeTransfer(
            address(stableToken()),
            _msgSender(),
            (safeSlipAmount * stableBalance) / (s_repaidSafeSlips)
        );

        emit RedeemStable(_msgSender(), safeSlipAmount, this.currentPrice());
    }

    function setFee(uint256 newFeeBps) external override onlyOwner() {
        if (bond().isMature())
            revert BondIsMature({given: bond().isMature(), required: false});
        if (newFeeBps > maxFeeBPS)
            revert FeeTooLarge({input: newFeeBps, maximum: maxFeeBPS});
        feeBps = newFeeBps;
        emit FeeUpdate(newFeeBps);
    }

    function _atomicDeposit(
        address _borrower,
        address _lender,
        uint256 _stableAmount,
        uint256 _safeSlipAmount,
        uint256 _riskSlipAmount
    ) internal {
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
        ICBBSlip(s_safeSlipTokenAddress).mint(_lender, _safeSlipAmount);

        // //Mint riskSlips to the borrower
        ICBBSlip(s_riskSlipTokenAddress).mint(_borrower, _riskSlipAmount);

        // // Transfer stables to borrower
        TransferHelper.safeTransferFrom(
            address(stableToken()),
            _msgSender(),
            _borrower,
            _stableAmount
        );
    }

    function cbbTransferOwnership(address owner) override external {
        transferOwnership(owner);
    }
}
