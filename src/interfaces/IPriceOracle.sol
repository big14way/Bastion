// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IPriceOracle
/// @notice Interface for price oracle used by BastionVault
/// @dev Returns prices in 18 decimal format (1e18 = $1)
interface IPriceOracle {
    /// @notice Get the price of a token in USD
    /// @param token Address of the token
    /// @return price Price in 18 decimals (1e18 = $1)
    function getPrice(address token) external view returns (uint256 price);

    /// @notice Get the price of a token with staleness check
    /// @param token Address of the token
    /// @param maxAge Maximum age of price data in seconds
    /// @return price Price in 18 decimals
    /// @return isValid Whether the price is fresh and valid
    function getPriceWithValidity(address token, uint256 maxAge)
        external
        view
        returns (uint256 price, bool isValid);

    /// @notice Check if a token has a configured price feed
    /// @param token Address of the token
    /// @return hasPrice True if price feed exists
    function hasPriceFeed(address token) external view returns (bool hasPrice);
}
