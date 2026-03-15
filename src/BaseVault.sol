// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseVault {
    using SafeERC20 for IERC20;

    address public immutable multisig;
    IERC20 public immutable token;

    uint256 public totalReceived;
    uint256 public totalReleased;

    event AssetReleased(address indexed recipient, uint256 amount);

    error NotMultisig();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();

    modifier onlyMultisig() {
        if (msg.sender != multisig) revert NotMultisig();
        _;
    }

    constructor(address _multisig, address _token) {
        if (_multisig == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        multisig = _multisig;
        token = IERC20(_token);
    }

    /// @notice Move tokens out. Only multisig can call.
    // Internal version — no modifier, callable by child contracts
    function _release(address recipient, uint256 amount) internal {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;
        token.safeTransfer(recipient, amount);

        emit AssetReleased(recipient, amount);
    }

    /// @notice Current token balance held by this vault.
    function vaultBalance() internal view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
