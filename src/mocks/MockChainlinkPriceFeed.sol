// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockChainlinkPriceFeed
/// @notice Mock implementation of Chainlink price feed for testing
contract MockChainlinkPriceFeed {
    int256 private price;
    uint8 private immutable _decimals;
    uint256 private updatedAt;
    uint80 private roundId;

    constructor(int256 initialPrice, uint8 decimals_) {
        price = initialPrice;
        _decimals = decimals_;
        updatedAt = block.timestamp;
        roundId = 1;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId_, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        return (roundId, price, updatedAt, updatedAt, roundId);
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId_, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        return (_roundId, price, updatedAt, updatedAt, _roundId);
    }

    // Admin functions for testing
    function updatePrice(int256 newPrice) external {
        price = newPrice;
        updatedAt = block.timestamp;
        roundId++;
    }

    function setPrice(int256 newPrice) external {
        price = newPrice;
    }

    function setUpdatedAt(uint256 timestamp) external {
        updatedAt = timestamp;
    }
}
