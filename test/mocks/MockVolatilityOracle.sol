// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVolatilityOracle} from "../../src/interfaces/IVolatilityOracle.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract MockVolatilityOracle is IVolatilityOracle {
    uint256 private volatility;

    function setVolatility(uint256 _volatility) external {
        volatility = _volatility;
    }

    function realizedVolatility(PoolKey calldata) external view override returns (uint256) {
        return volatility;
    }

    function getVolatility() external view returns (uint256) {
        return volatility;
    }
}
