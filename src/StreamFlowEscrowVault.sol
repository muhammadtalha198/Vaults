// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseVault.sol";

/// @title  StreamFlowEscrowVault
/// @notice Holds 43% of supply for artist vesting.
///         The multisig controls all releases — vesting schedule logic
///         lives off-chain or in a separate scheduler contract that
///         calls through the multisig.
contract StreamFlowEscrowVault is BaseVault {
    string public constant VAULT_NAME = "StreamFlowEscrowVault";

    struct VestingRecord {
        address artist;
        uint256 totalAllocated;
        uint256 totalReleased;
    }

    // artistAddress => VestingRecord
    mapping(address => VestingRecord) public vestingRecords;

    event VestingRecordCreated(
        address indexed artist,
        uint256 totalAllocated,
        uint256 startTime,
        uint256 endTime
    );
    event ArtistVestingReleased(
        address indexed artist,
        uint256 amount,
        uint256 totalReleasedToArtist
    );

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Register an artist vesting allocation.
    function createVestingRecord(
        address artist,
        uint256 totalAllocated,
        uint256 startTime,
        uint256 endTime
    ) external onlyMultisig {
        if (artist == address(0)) revert ZeroAddress();
        if (totalAllocated == 0) revert ZeroAmount();
        require(endTime > startTime, "Invalid time range");

        vestingRecords[artist] = VestingRecord({
            artist: artist,
            totalAllocated: totalAllocated,
            totalReleased: 0,
            startTime: startTime,
            endTime: endTime
        });

        emit VestingRecordCreated(artist, totalAllocated, startTime, endTime);
    }

    /// @notice Release vested tokens to a specific artist.
    ///         Multisig is responsible for computing the correct amount.
    function releaseToArtist(
        address artist,
        uint256 amount
    ) external onlyMultisig {
        if (artist == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        VestingRecord storage record = vestingRecords[artist];
        require(record.totalAllocated > 0, "No vesting record");
        require(
            record.totalReleased + amount <= record.totalAllocated,
            "Exceeds allocation"
        );
        if (token.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        record.totalReleased += amount;
        totalReleased += amount;

        // token.safeTransfer(artist, amount);

        emit ArtistVestingReleased(artist, amount, record.totalReleased);
        emit AssetReleased(artist, amount);
    }

    /// @notice View how much of an artist's allocation remains locked.
    function remainingAllocation(
        address artist
    ) external view returns (uint256) {
        VestingRecord storage r = vestingRecords[artist];
        return r.totalAllocated - r.totalReleased;
    }
}
