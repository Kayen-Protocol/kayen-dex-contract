
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IKayenMasterRouterV2 {
    error Expired();
    error InsufficientBAmount();
    error InsufficientAAmount();
    error ExcessiveInputAmount();
    error MustWrapToken();
    event MasterRouterSwap(uint256[] amounts, address reminderTokenAddress, uint256 reminder);

}
