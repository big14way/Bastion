// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IAVSConsumer
/// @notice Interface for contracts that consume data from Bastion AVS (Actively Validated Services)
/// @dev Contracts implementing this interface can read validated results from the AVS task manager
interface IAVSConsumer {
    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    /// @notice Volatility data from AVS operators
    /// @param volatility Realized volatility in basis points (10000 = 100%)
    /// @param timestamp When the volatility was calculated
    /// @param isValid Whether the data has been verified by AVS consensus
    struct VolatilityData {
        uint256 volatility;
        uint256 timestamp;
        bool isValid;
    }

    /// @notice Depeg status data from AVS operators
    /// @param isDepegged Whether the asset is currently depegged
    /// @param currentPrice Current price ratio (18 decimals, 1e18 = 1:1 peg)
    /// @param deviation Deviation from peg in basis points
    /// @param timestamp When the depeg check was performed
    /// @param isValid Whether the data has been verified by AVS consensus
    struct DepegData {
        bool isDepegged;
        uint256 currentPrice;
        uint256 deviation;
        uint256 timestamp;
        bool isValid;
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Retrieves the latest validated volatility data for a pool
    /// @param poolId The pool identifier (PoolId from Uniswap v4)
    /// @return volatilityData The latest volatility data from AVS consensus
    function getLatestVolatility(bytes32 poolId) external view returns (VolatilityData memory volatilityData);

    /// @notice Retrieves the latest validated depeg status for an asset
    /// @param assetAddress The address of the asset to check
    /// @return depegData The latest depeg status from AVS consensus
    function getLatestDepegStatus(address assetAddress) external view returns (DepegData memory depegData);

    /// @notice Checks if AVS data for a pool is stale (older than threshold)
    /// @param poolId The pool identifier
    /// @param maxAge Maximum allowed age in seconds
    /// @return isStale True if data is older than maxAge
    function isVolatilityDataStale(bytes32 poolId, uint256 maxAge) external view returns (bool isStale);

    /// @notice Checks if AVS depeg data for an asset is stale
    /// @param assetAddress The address of the asset
    /// @param maxAge Maximum allowed age in seconds
    /// @return isStale True if data is older than maxAge
    function isDepegDataStale(address assetAddress, uint256 maxAge) external view returns (bool isStale);

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when new volatility data is received from AVS
    /// @param poolId The pool identifier
    /// @param volatility Volatility in basis points
    /// @param timestamp When the data was validated
    event VolatilityUpdated(bytes32 indexed poolId, uint256 volatility, uint256 timestamp);

    /// @notice Emitted when new depeg status is received from AVS
    /// @param assetAddress The asset address
    /// @param isDepegged Whether asset is depegged
    /// @param currentPrice Current price ratio
    /// @param deviation Deviation in basis points
    /// @param timestamp When the data was validated
    event DepegStatusUpdated(
        address indexed assetAddress,
        bool isDepegged,
        uint256 currentPrice,
        uint256 deviation,
        uint256 timestamp
    );

    // -----------------------------------------------
    // Errors
    // -----------------------------------------------

    /// @notice Thrown when AVS data is not available
    error AVSDataNotAvailable();

    /// @notice Thrown when AVS data is stale
    error AVSDataStale(uint256 age, uint256 maxAge);

    /// @notice Thrown when AVS consensus has not been reached
    error AVSConsensusNotReached();
}
