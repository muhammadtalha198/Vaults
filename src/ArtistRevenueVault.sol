// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ArtistRevenueVault
/// @notice Artist-owned USDC revenue vault. Only the artist can release funds.
contract ArtistRevenueVault {
    using SafeERC20 for IERC20;

    string public constant VAULT_NAME = "ArtistRevenueVault";

    address public immutable ARTIST;
    IERC20 public immutable USDC;

    uint256 public totalReceived;
    uint256 public totalReleased;

    error NotArtist();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance();

    event RevenueReceived(
        address indexed from,
        uint256 amount,
        uint256 newBalance
    );
    event RevenueReleased(
        address indexed recipient,
        uint256 amount,
        uint256 newBalance
    );

    constructor(address usdc, address artist) {
        if (usdc == address(0)) revert ZeroAddress();
        if (artist == address(0)) revert ZeroAddress();

        USDC = IERC20(usdc);
        ARTIST = artist;
    }

    /// @notice Anyone can deposit USDC via transferFrom.
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        USDC.safeTransferFrom(msg.sender, address(this), amount);
        totalReceived += amount;

        emit RevenueReceived(msg.sender, amount, USDC.balanceOf(address(this)));
    }

    /// @notice Artist moves USDC out.
    function release(address recipient, uint256 amount) external onlyArtist {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 balance = USDC.balanceOf(address(this));
        if (amount > balance) revert InsufficientBalance();

        USDC.safeTransfer(recipient, amount);
        totalReleased += amount;

        emit RevenueReleased(recipient, amount, USDC.balanceOf(address(this)));
    }

    function vaultBalance() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    modifier onlyArtist() {
        if (msg.sender != ARTIST) revert NotArtist();
        _;
    }
}
