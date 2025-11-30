// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockBastionTaskManager
/// @notice Mock implementation of BastionTaskManager for testing AVS consumer integration
/// @dev Allows tests to set arbitrary volatility and depeg data to simulate AVS responses
contract MockBastionTaskManager {
    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    struct VolatilityData {
        uint256 volatility;
        uint256 timestamp;
        bool isValid;
    }

    struct DepegData {
        bool isDepegged;
        uint256 currentPrice;
        uint256 deviation;
        uint256 timestamp;
        bool isValid;
    }

    struct InterestRateData {
        uint256 newRate;
        uint256 timestamp;
        bool isValid;
    }

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Mock volatility data per pool ID
    mapping(bytes32 => VolatilityData) public mockVolatilityData;

    /// @notice Mock depeg data per asset address
    mapping(address => DepegData) public mockDepegData;

    /// @notice Mock interest rate data per lending module
    mapping(address => InterestRateData) public mockInterestRateData;

    // -----------------------------------------------
    // Mock Data Setters (for tests)
    // -----------------------------------------------

    /// @notice Set mock volatility data for a pool
    /// @param poolId Pool identifier
    /// @param volatility Volatility value in basis points
    /// @param timestamp Validation timestamp
    /// @param isValid Whether the data is valid
    function setMockVolatility(bytes32 poolId, uint256 volatility, uint256 timestamp, bool isValid) external {
        mockVolatilityData[poolId] = VolatilityData({
            volatility: volatility,
            timestamp: timestamp,
            isValid: isValid
        });
    }

    /// @notice Set mock depeg data for an asset
    /// @param assetAddress Asset address
    /// @param isDepegged Whether asset is depegged
    /// @param currentPrice Current price
    /// @param deviation Deviation from peg in basis points
    /// @param timestamp Validation timestamp
    /// @param isValid Whether the data is valid
    function setMockDepegStatus(
        address assetAddress,
        bool isDepegged,
        uint256 currentPrice,
        uint256 deviation,
        uint256 timestamp,
        bool isValid
    ) external {
        mockDepegData[assetAddress] = DepegData({
            isDepegged: isDepegged,
            currentPrice: currentPrice,
            deviation: deviation,
            timestamp: timestamp,
            isValid: isValid
        });
    }

    /// @notice Set mock interest rate data for a lending module
    /// @param lendingModuleAddress Lending module address
    /// @param newRate Interest rate in basis points
    /// @param timestamp Validation timestamp
    /// @param isValid Whether the data is valid
    function setMockInterestRate(address lendingModuleAddress, uint256 newRate, uint256 timestamp, bool isValid)
        external
    {
        mockInterestRateData[lendingModuleAddress] = InterestRateData({
            newRate: newRate,
            timestamp: timestamp,
            isValid: isValid
        });
    }

    // -----------------------------------------------
    // BastionTaskManager Interface Implementation
    // -----------------------------------------------

    /// @notice Gets the latest validated volatility for a pool
    /// @param poolId The pool identifier (keccak256 of pool address)
    /// @return volatility Volatility in basis points
    /// @return timestamp When the data was validated
    /// @return isValid Whether consensus was reached
    function getLatestVolatility(bytes32 poolId)
        external
        view
        returns (uint256 volatility, uint256 timestamp, bool isValid)
    {
        VolatilityData memory data = mockVolatilityData[poolId];
        return (data.volatility, data.timestamp, data.isValid);
    }

    /// @notice Gets the latest validated depeg status for an asset
    /// @param assetAddress The address of the asset to check
    /// @return isDepegged Whether the asset is depegged
    /// @return currentPrice Current price from oracle
    /// @return deviation Deviation from peg in basis points
    /// @return timestamp When the data was validated
    /// @return isValid Whether consensus was reached
    function getLatestDepegStatus(address assetAddress)
        external
        view
        returns (bool isDepegged, uint256 currentPrice, uint256 deviation, uint256 timestamp, bool isValid)
    {
        DepegData memory data = mockDepegData[assetAddress];
        return (data.isDepegged, data.currentPrice, data.deviation, data.timestamp, data.isValid);
    }

    /// @notice Gets the latest validated interest rate for a lending module
    /// @param lendingModuleAddress The lending module address
    /// @return newRate Interest rate in basis points
    /// @return timestamp When the data was validated
    /// @return isValid Whether consensus was reached
    function getLatestInterestRate(address lendingModuleAddress)
        external
        view
        returns (uint256 newRate, uint256 timestamp, bool isValid)
    {
        InterestRateData memory data = mockInterestRateData[lendingModuleAddress];
        return (data.newRate, data.timestamp, data.isValid);
    }
}
