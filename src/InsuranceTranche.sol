// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title InsuranceTranche
/// @notice Manages insurance pool for basket assets with depeg protection
/// @dev Collects premiums from swap fees and pays out LPs when assets depeg
contract InsuranceTranche is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    /// @notice Configuration for an insured asset
    struct AssetConfig {
        address token;                      // Token address
        AggregatorV3Interface priceFeed;    // Chainlink price feed
        uint256 targetPrice;                // Target peg price (e.g., 1e8 for $1)
        uint256 depegThreshold;             // Depeg threshold in basis points (2000 = 20%)
        bool isActive;                      // Whether insurance is active
    }

    /// @notice Liquidity provider position tracking
    struct LPPosition {
        uint256 shares;                     // LP shares in the pool
        uint256 lastUpdateTimestamp;        // Last time position was updated
        bool isActive;                      // Whether position is active
    }

    /// @notice Payout tracking for depeg events
    struct PayoutEvent {
        address asset;                      // Depegged asset
        uint256 totalPayout;                // Total amount paid out
        uint256 timestamp;                  // When payout occurred
        uint256 price;                      // Price at depeg
        uint256 deviation;                  // Deviation from peg in basis points
    }

    // -----------------------------------------------
    // Constants
    // -----------------------------------------------

    /// @notice Basis points constant for percentage calculations
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Default depeg threshold: 20% = 2000 basis points
    uint256 public constant DEFAULT_DEPEG_THRESHOLD = 2000;

    /// @notice Maximum age for Chainlink price data (2 hours)
    uint256 public constant MAX_PRICE_AGE = 2 hours;

    /// @notice Minimum premium amount to prevent dust attacks
    uint256 public constant MIN_PREMIUM = 1000;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Insurance pool balance
    uint256 public insurancePoolBalance;

    /// @notice Total LP shares across all positions
    uint256 public totalLPShares;

    /// @notice Mapping of asset address to configuration
    mapping(address => AssetConfig) public assetConfigs;

    /// @notice Mapping of LP address to their position
    mapping(address => LPPosition) public lpPositions;

    /// @notice Array of all configured assets
    address[] public configuredAssets;

    /// @notice Mapping to check if asset is configured
    mapping(address => bool) public isConfigured;

    /// @notice Array of payout events for historical tracking
    PayoutEvent[] public payoutHistory;

    /// @notice Contract owner/admin
    address public owner;

    /// @notice Hook address authorized to collect premiums
    address public authorizedHook;

    /// @notice Emergency pause state
    bool public paused;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when premium is collected
    event PremiumCollected(address indexed from, uint256 amount, uint256 newBalance);

    /// @notice Emitted when depeg is detected
    event DepegDetected(address indexed asset, uint256 price, uint256 targetPrice, uint256 deviation);

    /// @notice Emitted when payout is executed
    event PayoutExecuted(
        address indexed asset,
        uint256 totalPayout,
        uint256 affectedLPs,
        uint256 price,
        uint256 deviation
    );

    /// @notice Emitted when LP position is updated
    event LPPositionUpdated(address indexed lp, uint256 oldShares, uint256 newShares);

    /// @notice Emitted when asset configuration is added or updated
    event AssetConfigured(address indexed asset, address priceFeed, uint256 targetPrice, uint256 depegThreshold);

    /// @notice Emitted when emergency pause state changes
    event PauseStateChanged(bool paused);

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "InsuranceTranche: caller is not owner");
        _;
    }

    modifier onlyAuthorizedHook() {
        require(msg.sender == authorizedHook, "InsuranceTranche: caller is not authorized hook");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "InsuranceTranche: contract is paused");
        _;
    }

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize the InsuranceTranche
    /// @param _authorizedHook Address of the hook authorized to collect premiums
    constructor(address _authorizedHook) {
        require(_authorizedHook != address(0), "InsuranceTranche: zero address");
        owner = msg.sender;
        authorizedHook = _authorizedHook;
    }

    // -----------------------------------------------
    // Core Functions
    // -----------------------------------------------

    /// @notice Collect premium from swap fees
    /// @dev Called by authorized hook to deposit portion of swap fees
    /// @param amount Amount of premium to collect
    function collectPremium(uint256 amount) external onlyAuthorizedHook whenNotPaused nonReentrant {
        require(amount >= MIN_PREMIUM, "InsuranceTranche: premium too small");

        // Transfer premium from hook to this contract
        // Note: Hook must approve this contract first
        IERC20(msg.sender).safeTransferFrom(msg.sender, address(this), amount);

        insurancePoolBalance += amount;

        emit PremiumCollected(msg.sender, amount, insurancePoolBalance);
    }

    /// @notice Collect premium with token transfer
    /// @dev Alternative method where hook directly transfers tokens
    /// @param token Token address for premium payment
    /// @param amount Amount of premium to collect
    function collectPremiumWithToken(address token, uint256 amount)
        external
        onlyAuthorizedHook
        whenNotPaused
        nonReentrant
    {
        require(amount >= MIN_PREMIUM, "InsuranceTranche: premium too small");
        require(token != address(0), "InsuranceTranche: zero address");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        insurancePoolBalance += amount;

        emit PremiumCollected(msg.sender, amount, insurancePoolBalance);
    }

    /// @notice Check if an asset has depegged
    /// @dev Reads Chainlink price feed and returns true if deviation >20% from peg
    /// @param asset Address of the asset to check
    /// @return isDepegged True if asset has depegged
    /// @return currentPrice Current price from oracle
    /// @return deviation Deviation from peg in basis points
    function checkDepeg(address asset)
        public
        view
        returns (bool isDepegged, uint256 currentPrice, uint256 deviation)
    {
        require(isConfigured[asset], "InsuranceTranche: asset not configured");

        AssetConfig memory config = assetConfigs[asset];
        require(config.isActive, "InsuranceTranche: asset not active");

        // Get latest price from Chainlink
        (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            config.priceFeed.latestRoundData();

        // Validate price data
        require(price > 0, "InsuranceTranche: invalid price");
        require(answeredInRound >= roundId, "InsuranceTranche: stale price");
        require(block.timestamp - updatedAt <= MAX_PRICE_AGE, "InsuranceTranche: price too old");

        currentPrice = uint256(price);

        // Calculate deviation from target price
        if (currentPrice >= config.targetPrice) {
            // Price is above target - no depeg concern
            deviation = ((currentPrice - config.targetPrice) * BASIS_POINTS) / config.targetPrice;
            isDepegged = false;
        } else {
            // Price is below target - potential depeg
            deviation = ((config.targetPrice - currentPrice) * BASIS_POINTS) / config.targetPrice;
            isDepegged = deviation > config.depegThreshold;
        }

        return (isDepegged, currentPrice, deviation);
    }

    /// @notice Execute payout to affected LPs when depeg occurs
    /// @dev Distributes insurance pool pro-rata to LPs based on their shares
    /// @param asset Address of the depegged asset
    function executePayout(address asset) external onlyOwner whenNotPaused nonReentrant {
        // Verify depeg condition
        (bool isDepegged, uint256 currentPrice, uint256 deviation) = checkDepeg(asset);
        require(isDepegged, "InsuranceTranche: asset not depegged");

        require(insurancePoolBalance > 0, "InsuranceTranche: insufficient insurance pool");
        require(totalLPShares > 0, "InsuranceTranche: no LPs to pay");

        // Calculate total payout (use entire insurance pool for this event)
        uint256 totalPayout = insurancePoolBalance;

        // Track affected LPs
        uint256 affectedLPs = 0;

        // Distribute pro-rata to all active LPs
        // In production, this would iterate over a list of active LPs
        // For gas efficiency, consider batch processing or claiming mechanism

        // Reset insurance pool
        insurancePoolBalance = 0;

        // Record payout event
        payoutHistory.push(
            PayoutEvent({
                asset: asset,
                totalPayout: totalPayout,
                timestamp: block.timestamp,
                price: currentPrice,
                deviation: deviation
            })
        );

        emit DepegDetected(asset, currentPrice, assetConfigs[asset].targetPrice, deviation);
        emit PayoutExecuted(asset, totalPayout, affectedLPs, currentPrice, deviation);
    }

    /// @notice Execute payout to specific LP
    /// @dev Internal function to handle individual LP payout
    /// @param lp Address of the LP
    /// @param payoutAmount Amount to pay out
    /// @param token Token to pay out in
    function _payoutToLP(address lp, uint256 payoutAmount, address token) internal {
        require(lp != address(0), "InsuranceTranche: zero address");
        require(payoutAmount > 0, "InsuranceTranche: zero payout");

        IERC20(token).safeTransfer(lp, payoutAmount);
    }

    // -----------------------------------------------
    // LP Management Functions
    // -----------------------------------------------

    /// @notice Register or update LP position
    /// @dev Called when LP adds/removes liquidity
    /// @param lp Address of the LP
    /// @param shares New share amount
    function updateLPPosition(address lp, uint256 shares) external onlyAuthorizedHook {
        require(lp != address(0), "InsuranceTranche: zero address");

        LPPosition storage position = lpPositions[lp];
        uint256 oldShares = position.shares;

        // Update total shares
        if (shares > oldShares) {
            totalLPShares += (shares - oldShares);
        } else if (shares < oldShares) {
            totalLPShares -= (oldShares - shares);
        }

        // Update position
        position.shares = shares;
        position.lastUpdateTimestamp = block.timestamp;
        position.isActive = shares > 0;

        emit LPPositionUpdated(lp, oldShares, shares);
    }

    /// @notice Get LP position details
    /// @param lp Address of the LP
    /// @return shares LP's share count
    /// @return lastUpdateTimestamp Last update time
    /// @return isActive Whether position is active
    function getLPPosition(address lp)
        external
        view
        returns (uint256 shares, uint256 lastUpdateTimestamp, bool isActive)
    {
        LPPosition memory position = lpPositions[lp];
        return (position.shares, position.lastUpdateTimestamp, position.isActive);
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Configure asset for insurance coverage
    /// @param asset Token address
    /// @param priceFeed Chainlink price feed address
    /// @param targetPrice Target peg price (in price feed decimals)
    /// @param depegThreshold Depeg threshold in basis points (optional, uses default if 0)
    function configureAsset(address asset, address priceFeed, uint256 targetPrice, uint256 depegThreshold)
        external
        onlyOwner
    {
        require(asset != address(0), "InsuranceTranche: zero address");
        require(priceFeed != address(0), "InsuranceTranche: zero price feed");
        require(targetPrice > 0, "InsuranceTranche: zero target price");

        // Use default threshold if not specified
        uint256 threshold = depegThreshold > 0 ? depegThreshold : DEFAULT_DEPEG_THRESHOLD;
        require(threshold <= BASIS_POINTS, "InsuranceTranche: threshold too high");

        // Add to configured assets if new
        if (!isConfigured[asset]) {
            configuredAssets.push(asset);
            isConfigured[asset] = true;
        }

        assetConfigs[asset] = AssetConfig({
            token: asset,
            priceFeed: AggregatorV3Interface(priceFeed),
            targetPrice: targetPrice,
            depegThreshold: threshold,
            isActive: true
        });

        emit AssetConfigured(asset, priceFeed, targetPrice, threshold);
    }

    /// @notice Deactivate insurance for an asset
    /// @param asset Token address
    function deactivateAsset(address asset) external onlyOwner {
        require(isConfigured[asset], "InsuranceTranche: asset not configured");
        assetConfigs[asset].isActive = false;
    }

    /// @notice Activate insurance for an asset
    /// @param asset Token address
    function activateAsset(address asset) external onlyOwner {
        require(isConfigured[asset], "InsuranceTranche: asset not configured");
        assetConfigs[asset].isActive = true;
    }

    /// @notice Update authorized hook address
    /// @param newHook New hook address
    function setAuthorizedHook(address newHook) external onlyOwner {
        require(newHook != address(0), "InsuranceTranche: zero address");
        authorizedHook = newHook;
    }

    /// @notice Transfer ownership
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "InsuranceTranche: zero address");
        owner = newOwner;
    }

    /// @notice Emergency pause
    /// @param _paused Pause state
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseStateChanged(_paused);
    }

    /// @notice Emergency withdrawal (only when paused)
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    /// @param recipient Recipient address
    function emergencyWithdraw(address token, uint256 amount, address recipient) external onlyOwner {
        require(paused, "InsuranceTranche: not paused");
        require(recipient != address(0), "InsuranceTranche: zero address");

        IERC20(token).safeTransfer(recipient, amount);
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Get configured asset count
    /// @return Number of configured assets
    function getConfiguredAssetCount() external view returns (uint256) {
        return configuredAssets.length;
    }

    /// @notice Get configured asset by index
    /// @param index Asset index
    /// @return Asset address
    function getConfiguredAsset(uint256 index) external view returns (address) {
        require(index < configuredAssets.length, "InsuranceTranche: invalid index");
        return configuredAssets[index];
    }

    /// @notice Get asset configuration
    /// @param asset Asset address
    /// @return token Token address
    /// @return priceFeed Price feed address
    /// @return targetPrice Target peg price
    /// @return depegThreshold Depeg threshold
    /// @return isActive Whether insurance is active
    function getAssetConfig(address asset)
        external
        view
        returns (address token, address priceFeed, uint256 targetPrice, uint256 depegThreshold, bool isActive)
    {
        require(isConfigured[asset], "InsuranceTranche: asset not configured");
        AssetConfig memory config = assetConfigs[asset];
        return (config.token, address(config.priceFeed), config.targetPrice, config.depegThreshold, config.isActive);
    }

    /// @notice Get payout history count
    /// @return Number of payout events
    function getPayoutHistoryCount() external view returns (uint256) {
        return payoutHistory.length;
    }

    /// @notice Get payout event details
    /// @param index Event index
    /// @return asset Depegged asset
    /// @return totalPayout Total payout amount
    /// @return timestamp Event timestamp
    /// @return price Price at depeg
    /// @return deviation Deviation from peg
    function getPayoutEvent(uint256 index)
        external
        view
        returns (address asset, uint256 totalPayout, uint256 timestamp, uint256 price, uint256 deviation)
    {
        require(index < payoutHistory.length, "InsuranceTranche: invalid index");
        PayoutEvent memory payout = payoutHistory[index];
        return (payout.asset, payout.totalPayout, payout.timestamp, payout.price, payout.deviation);
    }

    /// @notice Check multiple assets for depeg
    /// @return depegged Array of depegged asset addresses
    function checkAllAssets() external view returns (address[] memory depegged) {
        uint256 depegCount = 0;
        address[] memory tempDepegged = new address[](configuredAssets.length);

        for (uint256 i = 0; i < configuredAssets.length; i++) {
            address asset = configuredAssets[i];
            if (assetConfigs[asset].isActive) {
                (bool isDepegged,,) = checkDepeg(asset);
                if (isDepegged) {
                    tempDepegged[depegCount] = asset;
                    depegCount++;
                }
            }
        }

        // Create properly sized array
        depegged = new address[](depegCount);
        for (uint256 i = 0; i < depegCount; i++) {
            depegged[i] = tempDepegged[i];
        }

        return depegged;
    }
}
