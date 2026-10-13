pragma solidity ^0.8.24;

/// SPDX-License-Identifier: MIT
/// Copyright (c) Vigil Protocol
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../../lib/libraries/FixedPointMath.sol";
import "../../lib/libraries/SafeTransfer.sol";
import "../../lib/libraries/InterestRateModel.sol";
import "../../lib/libraries/CollateralBitmap.sol";
import "../../lib/libraries/VigilStorage.sol";

abstract contract VigilPool is UUPSUpgradeable, PausableUpgradeable {
    using FixedPointMath for uint256;
    using SafeTransfer for IERC20;

    // Constants
    uint256 public constant ZERO = 0;
    uint256 public constant ONE = 10**18;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;

    // Namespaced storage slots
    bytes32 constant public POOL_CONFIG_SLOT = VigilStorage.POOL_NAMESPACE;
    bytes32 constant public MARKET_SLOT = keccak256(abi.encodePacked(VigilStorage.COLLATERAL_BITMAP_NAMESPACE, address(0)));

    // Pool config stored in namespaced slot
    struct PoolConfig {
        address poolOwner;
        address feeRecipient;
        uint256 feePercentage; // basis points
        bool isPaused;
        uint256 lastUpdated;
    }

    // Market params stored per asset
    struct Market {
        address asset;
        uint256 ltv; // loan-to-value in basis points (e.g., 7500 = 75%)
        uint256 liquidationThreshold; // in basis points
        uint256 liquidationBonus; // in basis points
        uint256 interestRateModel; // reference to InterestRateModel address
    }

    // User position stored per user
    struct UserPosition {
        uint256 collateralValue; // in FixedPointMath.WAD
        uint256 debtValue; // in FixedPointMath.WAD
        uint256 healthFactor; // scaled by FixedPointMath.WAD
        bool isLiquidated;
        uint256 lastUpdate;
    }

    // Event declarations
    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 interest);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 interest);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Liquidate(address indexed user, address indexed liquidator, address indexed asset, uint256 collateralRepaid, uint256 debtReduced);
    event PauseChanged(bool paused, address indexed by);

    // Storage
    PoolConfig internal poolConfig;
    mapping(address => Market) public markets;
    mapping(address => UserPosition) public positions;
    mapping(address => uint256) public totalSupplied;
    mapping(address => uint256) totalBorrowed;

    // Errors
    error OnlyPaused();
    error NotPaused();
    error InvalidAsset();
    error InsufficientCollateral();
    error InsufficientDebt();
    error ZeroAmount();
    error AlreadyCollateral();
    error NotCollateral();

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdmin, bytes32 indexed newAdmin);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    constructor() {
        poolConfig.poolOwner = msg.sender;
        poolConfig.feeRecipient = address(0);
        poolConfig.feePercentage = 0;
        poolConfig.isPaused = false;
        poolConfig.lastUpdated = block.timestamp;
    }

    // ===== PAUSE LOGIC =====
    function pause() external onlyWhenNotPaused {
        poolConfig.isPaused = true;
        emit PauseChanged(true, msg.sender);
    }

    function unpause() external onlyWhenPaused {
        poolConfig.isPaused = false;
        emit PauseChanged(false, msg.sender);
    }

    modifier onlyWhenNotPaused() {
        require(!poolConfig.isPaused, "Pool paused");
        _;
    }

    modifier onlyWhenPaused() {
        require(poolConfig.isPaused, "Pool not paused");
        _;
    }

    // ===== DEPOSIT =====
    function deposit(address asset, uint256 amount) external whenNotPaused {
        require(amount > 0, "Zero amount");
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Update user position collateral
        UserPosition storage pos = positions[msg.sender];
        pos.collateralValue = pos.collateralValue + amount;

        totalSupplied[msg.sender] = totalSupplied[msg.sender] + amount;

        // Emit deposit event
        emit Deposit(msg.sender, asset, amount, _calculateShares(amount));
    }

    // ===== BORROW =====
    function borrow(address asset, uint256 amount) external whenNotPaused {
        require(amount > 0, "Zero amount");
        Market storage market = markets[asset];
        require(market.asset == asset, "Invalid asset");

        // Check collateralization
        UserPosition storage pos = positions[msg.sender];
        uint256 collateralValue = pos.collateralValue;
        uint256 ltv = market.ltv;

        // Calculate maximum borrowable based on collateral
        uint256 maxBorrow = collateralValue.mulDown(ltv).divDown(FixedPointMath.WAD);

        require(amount <= maxBorrow, "Insufficient collateral");

        // Update user position debt
        pos.debtValue = pos.debtValue + amount;

        totalBorrowed[msg.sender] = totalBorrowed[msg.sender] + amount;

        // Calculate interest
        uint256 utilization = _getUtilization(asset);
        uint256 rate = InterestRateModel.getRate(utilization);
        uint256 interest = amount.mulDown(rate).divDown(SECONDS_PER_YEAR);

        emit Borrow(msg.sender, asset, amount, interest);
    }

    // ===== REPAY =====
    function repay(address asset, uint256 amount) external whenNotPaused {
        require(amount > 0, "Zero amount");
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        UserPosition storage pos = positions[msg.sender];
        require(pos.debtValue >= amount, "Insufficient debt");

        pos.debtValue = pos.debtValue - amount;
        totalBorrowed[msg.sender] = totalBorrowed[msg.sender] - amount;

        // Calculate interest saved
        uint256 utilization = _getUtilization(asset);
        uint256 rate = InterestRateModel.getRate(utilization);
        uint256 interest = amount.mulDown(rate).divDown(SECONDS_PER_YEAR);

        emit Repay(msg.sender, asset, amount, interest);
    }

    // ===== WITHDRAW =====
    function withdraw(address asset, uint256 amount) external whenNotPaused {
        require(amount > 0, "Zero amount");

        UserPosition storage pos = positions[msg.sender];
        require(pos.collateralValue >= amount, "Insufficient collateral");

        IERC20(asset).safeTransfer(address(this), amount); // contract receives then transfers
        pos.collateralValue = pos.collateralValue - amount;
        totalSupplied[msg.sender] = totalSupplied[msg.sender] - amount;

        emit Withdraw(msg.sender, asset, amount, _calculateShares(amount));
    }

    // ===== LIQUIDATE =====
    function liquidate(address user) external whenNotPaused {
        UserPosition storage pos = positions[user];
        require(!pos.isLiquidated, "Already liquidated");

        // Simplified liquidation - in full implementation would check health factor
        emit Liquidate(msg.sender, user, address(0), ZERO, ZERO);
        pos.isLiquidated = true;
    }

    // ===== UTILITY FUNCTIONS =====

    function _userPosition(address user) internal view returns (UserPosition memory) {
        return positions[user];
    }

    function _getUtilization(address asset) internal view returns (uint256) {
        // Simplified utilization: total borrowed / total supplied
        return 500; // 50% as placeholder
    }

    // ===== CALCULATE SHARES =====
    function _calculateShares(uint256 amount) internal view returns (uint256) {
        // Calculate minted shares based on pool reserves
        return amount;
    }

// ===== DEFAULT ROLE =====
    bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
}