// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  PlatformUSDCTreasury
/// @notice Receives USDC from token sales and routes it out
///         on multisig instruction.
contract PlatformUSDCTreasury is BaseVault {
    string public constant VAULT_NAME = "PlatformUSDCTreasury";

    constructor(address _multisig, address _usdc) BaseVault(_multisig, _usdc) {}

    /// @notice Deposit USDC into the treasury.
    ///         Caller must approve this contract for `amount` of USDC first.
    function deposit(uint256 amount) external {
        _received(msg.sender, amount);
    }

    /// @notice Multisig routes USDC out to a destination with a tagged purpose.
    function withdraw(
        address plateFormWallet,
        uint256 amount
    ) external onlyMultisig {
        _release(plateFormWallet, amount);
    }
}
