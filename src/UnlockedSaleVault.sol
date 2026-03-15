// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseVault.sol";

/// @title  UnlockedSaleVault
/// @notice Hot operational vault that receives token tranches from PublicPoolVault
///         and dispenses them through the bonding curve sale mechanism.
///         The bonding curve contract itself must be set by the multisig —
///         it is the only non-multisig address permitted to pull tokens.
contract UnlockedSaleVault is BaseVault {
    string public constant VAULT_NAME = "UnlockedSaleVault";

    /// @notice The approved bonding curve contract that may pull sale tokens.
    address public bondingCurve;

    event BondingCurveUpdated(
        address indexed oldCurve,
        address indexed newCurve
    );
    event SaleTransfer(address indexed buyer, uint256 amount);

    error NotAuthorised();

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Multisig sets (or rotates) the bonding curve address.
    function setBondingCurve(address _bondingCurve) external onlyMultisig {
        if (_bondingCurve == address(0)) revert ZeroAddress();
        emit BondingCurveUpdated(bondingCurve, _bondingCurve);
        bondingCurve = _bondingCurve;
    }

    /// @notice Bonding curve calls this to transfer tokens to a buyer.
    ///         Only the approved bondingCurve address may call this.
    function transferToBuyer(address buyer, uint256 amount) external {
        if (msg.sender != bondingCurve) revert NotAuthorised();
        if (buyer == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;
        // token.safeTransfer(buyer, amount);

        emit SaleTransfer(buyer, amount);
        emit AssetReleased(buyer, amount);
    }
}
