// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title  LPVault
/// @notice Holds platform tokens AND USDC until genesis LP creation.
///         Tracks both assets independently.
///         Does NOT inherit BaseVault because it manages two tokens.
contract LPVault {
    using SafeERC20 for IERC20;

    address public immutable multisig;
    IERC20 public immutable platformToken;
    IERC20 public immutable usdc;

    uint256 public totalTokenReceived;
    uint256 public totalTokenReleased;
    uint256 public totalUsdcReceived;
    uint256 public totalUsdcReleased;

    event TokenReceived(uint256 amount);
    event UsdcReceived(uint256 amount);
    event TokenReleased(address indexed recipient, uint256 amount);
    event UsdcReleased(address indexed recipient, uint256 amount);
    event LPPairReleased(
        address indexed lpContract,
        uint256 tokenAmount,
        uint256 usdcAmount
    );

    error NotMultisig();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();

    modifier onlyMultisig() {
        if (msg.sender != multisig) revert NotMultisig();
        _;
    }

    constructor(address _multisig, address _platformToken, address _usdc) {
        if (_multisig == address(0)) revert ZeroAddress();
        if (_platformToken == address(0)) revert ZeroAddress();
        if (_usdc == address(0)) revert ZeroAddress();

        multisig = _multisig;
        platformToken = IERC20(_platformToken);
        usdc = IERC20(_usdc);
    }

    // ─── Accounting helpers ───────────────────────────────────────────────────

    function notifyTokenReceived(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        totalTokenReceived += amount;
        emit TokenReceived(amount);
    }

    function notifyUsdcReceived(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        totalUsdcReceived += amount;
        emit UsdcReceived(amount);
    }

    // ─── Individual releases ──────────────────────────────────────────────────

    function releaseToken(
        address recipient,
        uint256 amount
    ) external onlyMultisig {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (platformToken.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalTokenReleased += amount;
        platformToken.safeTransfer(recipient, amount);
        emit TokenReleased(recipient, amount);
    }

    function releaseUsdc(
        address recipient,
        uint256 amount
    ) external onlyMultisig {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (usdc.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalUsdcReleased += amount;
        usdc.safeTransfer(recipient, amount);
        emit UsdcReleased(recipient, amount);
    }

    /// @notice Atomic release of both assets to an LP contract in one tx.
    function releaseLPPair(
        address lpContract,
        uint256 tokenAmount,
        uint256 usdcAmount
    ) external onlyMultisig {
        if (lpContract == address(0)) revert ZeroAddress();
        if (tokenAmount == 0 && usdcAmount == 0) revert ZeroAmount();

        if (tokenAmount > 0) {
            if (platformToken.balanceOf(address(this)) < tokenAmount)
                revert InsufficientBalance();
            totalTokenReleased += tokenAmount;
            platformToken.safeTransfer(lpContract, tokenAmount);
        }

        if (usdcAmount > 0) {
            if (usdc.balanceOf(address(this)) < usdcAmount)
                revert InsufficientBalance();
            totalUsdcReleased += usdcAmount;
            usdc.safeTransfer(lpContract, usdcAmount);
        }

        emit LPPairReleased(lpContract, tokenAmount, usdcAmount);
    }

    // ─── Views ─────────────────────────────────────────────────────────────────

    function tokenBalance() external view returns (uint256) {
        return platformToken.balanceOf(address(this));
    }

    function usdcBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}
