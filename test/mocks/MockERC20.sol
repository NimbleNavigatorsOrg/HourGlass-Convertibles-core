import "@buttonwood-protocol/tranche/contracts/external/ERC20.sol";

contract MockERC20 is ERC20 {

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {

    }

    function mint (address target, uint256 amount) external {
        _mint(target, amount);
    }
}