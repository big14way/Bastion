// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/// @title IVolatilityOracle
/// @notice Interface for volatility oracle that provides realized volatility data for pools
interface IVolatilityOracle {
    /// @notice Get the realized volatility for a specific pool
    /// @param key The pool key identifying the pool
    /// @return volatility The realized volatility as a percentage (e.g., 1000 = 10.00%)
    function realizedVolatility(PoolKey calldata key) external view returns (uint256 volatility);
}
