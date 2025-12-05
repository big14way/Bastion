// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable2Step} from "../base/Ownable2Step.sol";

/// @title ChainlinkPriceOracle
/// @notice Price oracle wrapper for Chainlink price feeds
/// @dev Normalizes all prices to 18 decimals
contract ChainlinkPriceOracle is IPriceOracle, Ownable2Step {
    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    /// @notice Price feed configuration
    struct PriceFeedConfig {
        AggregatorV3Interface feed;     // Chainlink aggregator
        uint8 decimals;                  // Feed decimals
        uint256 heartbeat;               // Maximum staleness in seconds
        bool isActive;                   // Whether feed is active
    }

    // -----------------------------------------------
    // Constants
    // -----------------------------------------------

    /// @notice Target decimals for normalized prices
    uint8 public constant TARGET_DECIMALS = 18;

    /// @notice Default heartbeat if not specified (1 hour)
    uint256 public constant DEFAULT_HEARTBEAT = 1 hours;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Mapping of token address to price feed config
    mapping(address => PriceFeedConfig) public priceFeeds;

    /// @notice Array of configured tokens
    address[] public configuredTokens;

    /// @notice Base asset address (e.g., WETH for ETH-denominated prices)
    address public baseAsset;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when a price feed is configured
    event PriceFeedConfigured(
        address indexed token,
        address indexed feed,
        uint8 decimals,
        uint256 heartbeat
    );

    /// @notice Emitted when a price feed is removed
    event PriceFeedRemoved(address indexed token);

    /// @notice Emitted when base asset is updated
    event BaseAssetUpdated(address indexed oldBase, address indexed newBase);

    // -----------------------------------------------
    // Errors
    // -----------------------------------------------

    error PriceFeedNotConfigured(address token);
    error InvalidPrice(address token, int256 price);
    error StalePrice(address token, uint256 updatedAt, uint256 heartbeat);
    error InvalidRound(address token);
    error ZeroAddress();

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize the price oracle
    /// @param _baseAsset Base asset for price denomination
    constructor(address _baseAsset) Ownable2Step(msg.sender) {
        baseAsset = _baseAsset;
    }

    // -----------------------------------------------
    // External Functions (IPriceOracle)
    // -----------------------------------------------

    /// @inheritdoc IPriceOracle
    function getPrice(address token) external view override returns (uint256 price) {
        (price,) = _getPrice(token, type(uint256).max);
    }

    /// @inheritdoc IPriceOracle
    function getPriceWithValidity(address token, uint256 maxAge)
        external
        view
        override
        returns (uint256 price, bool isValid)
    {
        return _getPrice(token, maxAge);
    }

    /// @inheritdoc IPriceOracle
    function hasPriceFeed(address token) external view override returns (bool) {
        return priceFeeds[token].isActive;
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Configure a price feed for a token
    /// @param token Token address
    /// @param feed Chainlink aggregator address
    /// @param heartbeat Maximum staleness in seconds (0 for default)
    function configurePriceFeed(
        address token,
        address feed,
        uint256 heartbeat
    ) external onlyOwner {
        if (token == address(0) || feed == address(0)) revert ZeroAddress();

        AggregatorV3Interface aggregator = AggregatorV3Interface(feed);
        uint8 decimals = aggregator.decimals();

        // Add to configured tokens if new
        if (!priceFeeds[token].isActive) {
            configuredTokens.push(token);
        }

        priceFeeds[token] = PriceFeedConfig({
            feed: aggregator,
            decimals: decimals,
            heartbeat: heartbeat > 0 ? heartbeat : DEFAULT_HEARTBEAT,
            isActive: true
        });

        emit PriceFeedConfigured(token, feed, decimals, heartbeat);
    }

    /// @notice Remove a price feed
    /// @param token Token address
    function removePriceFeed(address token) external onlyOwner {
        if (!priceFeeds[token].isActive) revert PriceFeedNotConfigured(token);

        priceFeeds[token].isActive = false;
        emit PriceFeedRemoved(token);
    }

    /// @notice Update base asset
    /// @param _baseAsset New base asset address
    function setBaseAsset(address _baseAsset) external onlyOwner {
        if (_baseAsset == address(0)) revert ZeroAddress();
        address old = baseAsset;
        baseAsset = _baseAsset;
        emit BaseAssetUpdated(old, _baseAsset);
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Get count of configured tokens
    /// @return Number of configured tokens
    function getConfiguredTokenCount() external view returns (uint256) {
        return configuredTokens.length;
    }

    /// @notice Get all configured tokens
    /// @return Array of token addresses
    function getConfiguredTokens() external view returns (address[] memory) {
        return configuredTokens;
    }

    /// @notice Get price feed details for a token
    /// @param token Token address
    /// @return feed Feed address
    /// @return decimals Feed decimals
    /// @return heartbeat Max staleness
    /// @return isActive Whether active
    function getPriceFeedConfig(address token)
        external
        view
        returns (
            address feed,
            uint8 decimals,
            uint256 heartbeat,
            bool isActive
        )
    {
        PriceFeedConfig memory config = priceFeeds[token];
        return (address(config.feed), config.decimals, config.heartbeat, config.isActive);
    }

    // -----------------------------------------------
    // Internal Functions
    // -----------------------------------------------

    /// @notice Internal price fetch with normalization
    /// @param token Token address
    /// @param maxAge Maximum acceptable age
    /// @return price Normalized price (18 decimals)
    /// @return isValid Whether price is fresh
    function _getPrice(address token, uint256 maxAge)
        internal
        view
        returns (uint256 price, bool isValid)
    {
        PriceFeedConfig memory config = priceFeeds[token];

        if (!config.isActive) {
            revert PriceFeedNotConfigured(token);
        }

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = config.feed.latestRoundData();

        // Validate price
        if (answer <= 0) {
            revert InvalidPrice(token, answer);
        }

        // Validate round
        if (answeredInRound < roundId) {
            revert InvalidRound(token);
        }

        // Check staleness
        uint256 effectiveMaxAge = maxAge < config.heartbeat ? maxAge : config.heartbeat;
        isValid = (block.timestamp - updatedAt) <= effectiveMaxAge;

        // Normalize to 18 decimals
        if (config.decimals < TARGET_DECIMALS) {
            price = uint256(answer) * 10 ** (TARGET_DECIMALS - config.decimals);
        } else if (config.decimals > TARGET_DECIMALS) {
            price = uint256(answer) / 10 ** (config.decimals - TARGET_DECIMALS);
        } else {
            price = uint256(answer);
        }
    }
}
