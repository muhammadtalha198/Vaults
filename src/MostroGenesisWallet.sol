// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  MostroGenesisWallet
/// @notice Core platform wallet — 3% of supply.
///         Used for governance, early operations, and strategic disbursements.
///         All movements require multisig approval.
contract MostroGenesisWallet is BaseVault {
    string public constant VAULT_NAME = "MostroGenesisWallet";

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Disburse tokens with a tagged purpose for on-chain auditability.
    function disburse(address recipient, uint256 amount) external onlyMultisig {
        _release(recipient, amount);
    }
}
