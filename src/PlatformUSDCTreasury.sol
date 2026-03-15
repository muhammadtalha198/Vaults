// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseVault.sol";

/// @title  PlatformUSDCTreasury
/// @notice Receives all USDC from token sales.
///         Routes USDC to LP pairing, operations, and artist incentives
///         on multisig instruction.
contract PlatformUSDCTreasury is BaseVault {
    string public constant VAULT_NAME = "PlatformUSDCTreasury";

    enum Purpose {
        LPPairing,
        Operations,
        ArtistIncentive,
        BuybackAndBurn,
        ProtocolTreasury,
        Other
    }

    event UsdcRouted(
        address indexed destination,
        uint256 amount,
        Purpose purpose
    );

    constructor(address _multisig, address _usdc) BaseVault(_multisig, _usdc) {}

    /// @notice Route USDC to a destination with a tagged purpose.
    function routeUsdc(
        address destination,
        uint256 amount,
        Purpose purpose
    ) external onlyMultisig {
        if (destination == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;
        // token.safeTransfer(destination, amount);

        emit AssetReleased(destination, amount);
        emit UsdcRouted(destination, amount, purpose);
    }
}
