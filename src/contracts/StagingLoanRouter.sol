// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IStagingLoanRouter.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "../interfaces/IButtonWoodBondController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/button-wrappers/contracts/interfaces/IButtonWrapper.sol";

contract StagingLoanRouter is IStagingLoanRouter {
    /**
     * @inheritdoc IStagingLoanRouter
     */

    function simpleWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw
    ) public {
        IConvertibleBondBox convertibleBondBox = _stagingBox
            .convertibleBondBox();
        IButtonWoodBondController bond = convertibleBondBox.bond();
        IButtonWrapper wrapper = IButtonWrapper(bond.collateralToken());
        IERC20 underlying = IERC20(wrapper.underlying());

        TransferHelper.safeTransferFrom(
            address(underlying),
            msg.sender,
            address(this),
            _amountRaw
        );
        underlying.approve(address(wrapper), _amountRaw);
        uint256 wrapperAmount = wrapper.deposit(_amountRaw);

        bond.deposit(wrapperAmount);

        uint256 safeTrancheAmount = (wrapperAmount *
            convertibleBondBox.safeRatio()) /
            convertibleBondBox.s_trancheGranularity();

        _stagingBox.depositBorrow(msg.sender, safeTrancheAmount);
    }

    /**
     * @inheritdoc IStagingLoanRouter
     */

    function multiWrapTrancheBorrow(IStagingBox _stagingBox, uint256 _amountRaw)
        public
    {
        simpleWrapTrancheBorrow(_stagingBox, _amountRaw);

        IConvertibleBondBox convertibleBondBox = _stagingBox
            .convertibleBondBox();
        IButtonWoodBondController bond = convertibleBondBox.bond();

        //send back unused tranches to msg.sender
        for (uint256 i = 0; i < bond.trancheCount(); i++) {
            if (
                i != convertibleBondBox.trancheIndex() &&
                i != bond.trancheCount() - 1
            ) {
                (ITranche tranche, ) = bond.tranches(i);
                TransferHelper.safeTransfer(
                    address(tranche),
                    msg.sender,
                    tranche.balanceOf(address(this))
                );
            }
        }
    }
}
