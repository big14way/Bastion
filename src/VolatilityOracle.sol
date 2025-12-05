// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVolatilityOracle} from "./interfaces/IVolatilityOracle.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/**
 * @title VolatilityOracle
 * @notice Simple volatility oracle for BastionHook fee calculation
 * @dev In production, this would integrate with Chainlink or other price feeds
 */
contract VolatilityOracle is IVolatilityOracle {
    /// @notice Current volatility in basis points (100 = 1%)
    uint256 private volatility;

    /// @notice Admin address
    address public admin;

    event VolatilityUpdated(uint256 oldVolatility, uint256 newVolatility);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    error Unauthorized();
    error InvalidVolatility();

    constructor() {
        admin = msg.sender;
        volatility = 500; // Default 5% volatility
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Get realized volatility for a pool (implements IVolatilityOracle)
     * @param key Pool key (unused in this simple implementation)
     * @return Current volatility in basis points
     */
    function realizedVolatility(PoolKey calldata key) external view override returns (uint256) {
        return volatility;
    }

    /**
     * @notice Get current volatility (legacy function)
     * @return Current volatility in basis points
     */
    function getVolatility() external view returns (uint256) {
        return volatility;
    }

    /**
     * @notice Update volatility (admin only)
     * @param newVolatility New volatility in basis points
     */
    function updateVolatility(uint256 newVolatility) external onlyAdmin {
        if (newVolatility > 10000) revert InvalidVolatility(); // Max 100%

        uint256 oldVolatility = volatility;
        volatility = newVolatility;

        emit VolatilityUpdated(oldVolatility, newVolatility);
    }

    /**
     * @notice Update admin address
     * @param newAdmin New admin address
     */
    function updateAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert Unauthorized();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(oldAdmin, newAdmin);
    }
}
