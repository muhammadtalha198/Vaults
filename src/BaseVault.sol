// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    SafeERC20
} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IERC20
} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract BaseVault {
    using SafeERC20 for IERC20;

    address public immutable MULTISIG;
    IERC20 public immutable TOKEN;

    uint256 public totalReceived;
    uint256 public totalReleased;

    event AssetReceived(
        address indexed from,
        uint256 amount,
        uint256 totalReceived
    );
    event AssetReleased(
        address indexed recipient,
        uint256 amount,
        uint256 totalReleased
    );

    error NotMultisig();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();

    constructor(address _multisig, address _token) {
        if (_multisig == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        MULTISIG = _multisig;
        TOKEN = IERC20(_token);
    }

    /// @dev Pull tokens from `from` into this vault and update accounting.
    ///      Caller must have approved this contract first.
    function _received(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // pulls tokens in — requires prior approve()
        TOKEN.safeTransferFrom(from, address(this), amount);

        totalReceived += amount;

        emit AssetReceived(from, amount, totalReceived);
    }

    /// @dev Send tokens out of this vault to `recipient` and update accounting.
    function _release(address recipient, uint256 amount) internal {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;
        totalReceived -= amount;

        TOKEN.safeTransfer(recipient, amount);

        emit AssetReleased(recipient, amount, totalReleased);
    }

    function vaultBalance() external view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    modifier onlyMultisig() {
        _onlyMultisig();
        _;
    }

    function _onlyMultisig() internal view {
        if (msg.sender != MULTISIG) revert NotMultisig();
    }
}
