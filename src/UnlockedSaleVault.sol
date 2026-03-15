// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  UnlockedSaleVault
/// @notice Hot operational vault that receives token tranches from PublicPoolVault
///         and dispenses them through the bonding curve sale mechanism.
///         The bonding curve contract itself must be set by the multisig —
///         it is the only non-multisig address permitted to pull tokens.
contract UnlockedSaleVault is BaseVault {
    string public constant VAULT_NAME = "UnlockedSaleVault";

    event SaleTransfer(address indexed buyer, uint256 amount);

    error NotAuthorised();

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Bonding curve calls this to transfer tokens to a buyer.
    ///         Only the approved bondingCurve address may call this.
    function transferToBuyer(address buyer, uint256 amount) external {
        _release(buyer, amount);
        emit SaleTransfer(buyer, amount);
    }
}
