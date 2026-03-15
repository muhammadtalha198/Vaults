// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  LPVault
/// @notice Holds 5% of platform token supply locked until
///         the multisig initiates genesis LP creation on Raydium.
contract LPVault is BaseVault {
    string public constant VAULT_NAME = "LPVault";

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Release tokens to the Raydium LP contract.
    ///         Only callable by the global multisig.
    function release(address recipient, uint256 amount) external onlyMultisig {
        _release(recipient, amount);
    }
}
