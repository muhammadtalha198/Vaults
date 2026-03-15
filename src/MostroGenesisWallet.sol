// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseVault.sol";

/// @title  MostroGenesisWallet
/// @notice Core platform wallet — 3% of supply.
///         Used for governance, early operations, and strategic disbursements.
///         All movements require multisig approval.
contract MostroGenesisWallet is BaseVault {
    string public constant VAULT_NAME = "MostroGenesisWallet";

    enum DisbursementPurpose {
        Governance,
        Operations,
        Strategic,
        Other
    }

    event StrategicDisbursement(
        address indexed recipient,
        uint256 amount,
        DisbursementPurpose purpose,
        string note
    );

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Disburse tokens with a tagged purpose for on-chain auditability.
    function disburse(
        address recipient,
        uint256 amount,
        DisbursementPurpose purpose,
        string calldata note
    ) external onlyMultisig {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;
        // token.safeTransfer(recipient, amount);

        emit AssetReleased(recipient, amount);
        emit StrategicDisbursement(recipient, amount, purpose, note);
    }
}
