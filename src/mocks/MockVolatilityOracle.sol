// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVolatilityOracle} from "../interfaces/IVolatilityOracle.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @title MockVolatilityOracle
/// @notice Mock implementation of volatility oracle for testing
contract MockVolatilityOracle is IVolatilityOracle {
    using PoolIdLibrary for PoolKey;

    /// @notice Mapping of pool ID to volatility value (in basis points, e.g., 1000 = 10.00%)
    mapping(PoolId => uint256) public volatilityData;

    /// @notice Set the volatility for a specific pool
    /// @param key The pool key
    /// @param volatility The volatility value in basis points (e.g., 1000 = 10.00%)
    function setVolatility(PoolKey calldata key, uint256 volatility) external {
        volatilityData[key.toId()] = volatility;
    }

    /// @notice Get the realized volatility for a specific pool
    /// @param key The pool key identifying the pool
    /// @return volatility The realized volatility as a percentage (e.g., 1000 = 10.00%)
    function realizedVolatility(PoolKey calldata key) external view override returns (uint256 volatility) {
        return volatilityData[key.toId()];
    }
}
