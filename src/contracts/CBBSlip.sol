pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/ICBBSlip.sol";
import "@buttonwood-protocol/tranche/contracts/external/ERC20.sol";

import "forge-std/console2.sol";

/**
 * @dev ERC20 token to represent a single tranche for a ButtonTranche bond
 * Note: this contract has non-transferrable ownership given at init-time
 */
contract CBBSlip is ICBBSlip, ERC20, Initializable {
    address public collateralTranche;
    address public override bondBox;

    /**
     * @dev Constructor for Tranche ERC20 token
     */
    constructor() ERC20("IMPLEMENTATION", "IMPL") {
        collateralTranche = address(0x0);
    }

    /**
     * @dev Constructor for Slip ERC20 token
     * @param name the ERC20 token name
     * @param symbol The ERC20 token symbol
     * @param _bondBox The BondController which owns this Slip token
     * @param _collateralTranche The address of the ERC20 collateral token
     */
    function init(
        string memory name,
        string memory symbol,
        address _bondBox,
        address _collateralTranche
    ) public initializer {
        require(
            _bondBox != address(0),
            "Tranche: invalid Convertible Bond Box address"
        );
        require(
            _collateralTranche != address(0),
            "Tranche: invalid collateralTranche address"
        );

        bondBox = _bondBox;
        collateralTranche = _collateralTranche;

        super.init(name, symbol);
    }

    /**
     * @dev Throws if called by any account other than the bond.
     */
    modifier onlyCBB() {
        require(bondBox == _msgSender(), "Ownable: caller is not the bond");
        _;
    }

    /**
     * @inheritdoc ICBBSlip
     */
    function mint(address to, uint256 amount) external override onlyCBB {
        _mint(to, amount);
    }

    /**
     * @inheritdoc ICBBSlip
     */
    function burn(address from, uint256 amount) external override onlyCBB {
        _burn(from, amount);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Uses the same number of decimals as the collateral token
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view override returns (uint8) {
        return IERC20Metadata(collateralTranche).decimals();
    }
}
