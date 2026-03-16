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

    bool public depositInitialized;

    event AccountingIncreased(uint256 amount, uint256 totalReceived);
    event AssetReceived(
        address indexed from,
        uint256 amount,
        uint256 totalReceived
    );
    event AssetReleased(
        address indexed recipient,
        uint256 amount,
        uint256 totalReleased,
        uint256 totalReceived
    );

    error NotMultisig();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error DepositAlreadyInitialized();

    constructor(address _multisig, address _token) {
        if (_multisig == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();

        MULTISIG = _multisig;
        TOKEN = IERC20(_token);
    }

    /// @dev Can only be called once to initialize vault funding
    function _deposit(address from, uint256 amount) internal {
        if (depositInitialized) revert DepositAlreadyInitialized();
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(from) < amount) revert InsufficientBalance();

        TOKEN.safeTransferFrom(from, address(this), amount);

        totalReceived += amount;
        depositInitialized = true;

        emit AssetReceived(from, amount, totalReceived);
    }

    /// @dev Send tokens out of vault
    function _release(address recipient, uint256 amount) internal {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;
        totalReceived -= amount;

        TOKEN.safeTransfer(recipient, amount);

        emit AssetReleased(recipient, amount, totalReleased, totalReceived);
    }

    /// @dev Only updates accounting (no token transfer)
    function _increaseReceived(uint256 amount) internal onlyMultisig {
        if (amount == 0) revert ZeroAmount();
        totalReceived += amount;

        emit AccountingIncreased(amount, totalReceived);
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

/// @title  ArtistUnvestedVault
/// @notice Receives vested tokens from StreamFlowEscrowVault on schedule.
///         Tokens can ONLY exit through the approved Artist Drop Curve.
///         Artist cannot withdraw freely.
contract ArtistUnvestedVault is BaseVault {
    string public constant VAULT_NAME = "ArtistUnvestedVault";

    address public immutable artist;

    /// @notice The only contract permitted to pull tokens out —
    ///         the Artist Drop Curve for this artist.
    address public artistDropCurve;

    event ArtistDropCurveUpdated(
        address indexed oldCurve,
        address indexed newCurve
    );
    event SaleTransfer(address indexed buyer, uint256 amount);
    event ReceivedFromStreamFlow(address indexed from, uint256 amount);

    error NotAuthorised();
    error DropCurveNotSet();

    constructor(
        address _multisig,
        address _token,
        address _artist
    ) BaseVault(_multisig, _token) {
        if (_artist == address(0)) revert ZeroAddress();
        artist = _artist;
    }

    /// @notice StreamFlowEscrowVault calls this after pushing tokens here.
    function receiveFromStreamFlow(uint256 amount) external {
        _increaseReceived(amount);
    }

    function transferToBuyer(address buyer, uint256 amount) external {
        if (artistDropCurve == address(0)) revert DropCurveNotSet();
        if (msg.sender != artistDropCurve) revert NotAuthorised();
        _release(buyer, amount);
        emit SaleTransfer(buyer, amount);
    }
}

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

    function depositInStreamFlowVault(address from, uint256 amount) external {
        _deposit(from, amount);
    }
}

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

    function depositInMostroGenesisWallet(
        address from,
        uint256 amount
    ) external {
        _deposit(from, amount);
    }
}

/// @title  PlatformUSDCTreasury
/// @notice Receives USDC from token sales and routes it out
///         on multisig instruction.
contract PlatformUSDCTreasury is BaseVault {
    string public constant VAULT_NAME = "PlatformUSDCTreasury";

    constructor(address _multisig, address _usdc) BaseVault(_multisig, _usdc) {}

    /// @notice Deposit USDC into the treasury.
    ///         Caller must approve this contract for `amount` of USDC first.
    function receiveUSDC(address from, uint256 amount) external {
        _deposit(from, amount);
    }

    /// @notice Multisig routes USDC out to a destination with a tagged purpose.
    function withdraw(
        address plateFormWallet,
        uint256 amount
    ) external onlyMultisig {
        _release(plateFormWallet, amount);
    }
}

/// @title  PublicPoolVault
/// @notice Holds 40% of platform token supply.
///         Releases tokens to the UnlockedSaleVault in tranches
///         controlled entirely by the global multisig.
contract PublicPoolVault is BaseVault {
    string public constant VAULT_NAME = "PublicPoolVault";

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Release a tranche to the unlocked sale vault (or any recipient).
    function releaseTranche(
        address destination,
        uint256 amount
    ) external onlyMultisig {
        _release(destination, amount);
    }

    function depositInPublicVault(address from, uint256 amount) external {
        _deposit(from, amount);
    }
}

contract StreamFlowEscrowVault is BaseVault {
    string public constant VAULT_NAME = "StreamFlowEscrowVault";

    uint256 public constant TOTAL_PERIODS = 4;
    uint256 public constant PERIOD_DURATION = 180 days;

    uint256 public immutable PERIOD_UNLOCK_AMOUNT;

    uint256 public scheduleStart;
    address public artistUnvestedVault;
    bool public scheduleInitialised;

    mapping(uint256 => bool) public periodReleased;

    event ScheduleInitialised(
        uint256 indexed startTime,
        address indexed artistUnvestedVault,
        uint256 period1UnlocksAt,
        uint256 period2UnlocksAt,
        uint256 period3UnlocksAt,
        uint256 period4UnlocksAt
    );

    event PeriodReleased(
        uint256 indexed period,
        uint256 amount,
        uint256 unlockedAt,
        uint256 releasedAt
    );

    error ScheduleNotInitialised();
    error ScheduleAlreadyInitialised();
    error InvalidPeriod(uint256 period);
    error PeriodAlreadyReleased(uint256 period);
    error PeriodNotYetUnlocked(
        uint256 period,
        uint256 unlocksAt,
        uint256 currentTime
    );

    constructor(
        address _multisig,
        address _token,
        uint256 _periodUnlockAmount
    ) BaseVault(_multisig, _token) {
        if (_periodUnlockAmount == 0) revert ZeroAmount();
        PERIOD_UNLOCK_AMOUNT = _periodUnlockAmount;
    }

    function startSchedule(
        address _artistUnvestedVault,
        uint256 _startTime
    ) external onlyMultisig {
        if (scheduleInitialised) revert ScheduleAlreadyInitialised();
        if (_artistUnvestedVault == address(0)) revert ZeroAddress();
        require(_startTime >= block.timestamp, "Start time is in the past");

        scheduleInitialised = true;
        scheduleStart = _startTime;
        artistUnvestedVault = _artistUnvestedVault;

        emit ScheduleInitialised(
            _startTime,
            _artistUnvestedVault,
            _startTime + (1 * PERIOD_DURATION),
            _startTime + (2 * PERIOD_DURATION),
            _startTime + (3 * PERIOD_DURATION),
            _startTime + (4 * PERIOD_DURATION)
        );
    }

    function releasePeriod(uint256 period) external onlyMultisig {
        if (!scheduleInitialised) revert ScheduleNotInitialised();
        if (period == 0 || period > TOTAL_PERIODS) revert InvalidPeriod(period);
        if (periodReleased[period]) revert PeriodAlreadyReleased(period);

        uint256 unlocksAt = scheduleStart + (period * PERIOD_DURATION);

        if (block.timestamp < unlocksAt) {
            revert PeriodNotYetUnlocked(period, unlocksAt, block.timestamp);
        }

        periodReleased[period] = true;

        _release(artistUnvestedVault, PERIOD_UNLOCK_AMOUNT);

        emit PeriodReleased(
            period,
            PERIOD_UNLOCK_AMOUNT,
            unlocksAt,
            block.timestamp
        );
    }

    function periodUnlockTime(uint256 period) external view returns (uint256) {
        if (!scheduleInitialised) revert ScheduleNotInitialised();
        if (period == 0 || period > TOTAL_PERIODS) revert InvalidPeriod(period);

        return scheduleStart + (period * PERIOD_DURATION);
    }

    function releasedPeriodCount() external view returns (uint256 count) {
        for (uint256 i = 1; i <= TOTAL_PERIODS; i++) {
            if (periodReleased[i]) count++;
        }
    }

    function depositInStreamFlowVault(address from, uint256 amount) external {
        _deposit(from, amount);
    }
}

/// @title  UnlockedSaleVault
/// @notice Hot operational vault that receives token tranches from PublicPoolVault
///         and dispenses them through the bonding curve sale mechanism.
///         The bonding curve contract itself must be set by the multisig —
///         it is the only non-multisig address permitted to pull tokens.
contract UnlockedSaleVault is BaseVault {
    string public constant VAULT_NAME = "UnlockedSaleVault";

    event SaleTransfer(address indexed buyer, uint256 amount);

    error NotAuthorised();

    constructor(
        address _multisig,
        address _token
    ) BaseVault(_multisig, _token) {}

    /// @notice Bonding curve calls this to transfer tokens to a buyer.
    ///         Only the approved bondingCurve address may call this.
    function transferToBuyer(address buyer, uint256 amount) external {
        _release(buyer, amount);
        emit SaleTransfer(buyer, amount);
    }

    function receiveFromPublicVault(uint256 amount) external {
        _increaseReceived(amount);
    }
}
