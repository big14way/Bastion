// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILendingModule} from "./interfaces/ILendingModule.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestCollateralHook
 * @notice Test contract to simulate BastionHook's collateral registration
 * @dev This contract simulates the Uniswap V4 hook that would normally register LP tokens as collateral
 * In production, the BastionHook automatically registers collateral when users add liquidity
 * This test contract allows manual registration for testing the borrowing functionality
 */
contract TestCollateralHook is Ownable {
    ILendingModule public immutable lendingModule;
    address public immutable lpToken;

    // Track registered users to prevent double registration
    mapping(address => bool) public hasRegistered;

    // Events
    event CollateralRegistered(address indexed user, uint256 lpAmount, uint256 collateralValue);
    event LendingModuleUpdated(address newLendingModule);

    constructor(address _lendingModule, address _lpToken) Ownable(msg.sender) {
        require(_lendingModule != address(0), "Invalid lending module");
        require(_lpToken != address(0), "Invalid LP token");

        lendingModule = ILendingModule(_lendingModule);
        lpToken = _lpToken;
    }

    /**
     * @notice Register test collateral for a user
     * @dev This simulates adding liquidity and getting LP tokens
     * @param user The user to register collateral for
     * @param lpAmount Amount of LP tokens (simulated)
     * @param collateralValue USD value of the LP position (with 18 decimals)
     */
    function registerTestCollateral(
        address user,
        uint256 lpAmount,
        uint256 collateralValue
    ) external onlyOwner {
        require(!hasRegistered[user], "User already registered");
        require(lpAmount > 0, "Invalid LP amount");
        require(collateralValue > 0, "Invalid collateral value");

        // Mark as registered
        hasRegistered[user] = true;

        // Register the collateral with the lending module
        // This is what BastionHook would do automatically in production
        lendingModule.registerCollateral(user, lpToken, lpAmount, collateralValue);

        emit CollateralRegistered(user, lpAmount, collateralValue);
    }

    /**
     * @notice Register collateral for multiple users in batch
     * @param users Array of user addresses
     * @param lpAmounts Array of LP token amounts
     * @param collateralValues Array of collateral values
     */
    function batchRegisterCollateral(
        address[] calldata users,
        uint256[] calldata lpAmounts,
        uint256[] calldata collateralValues
    ) external onlyOwner {
        require(users.length == lpAmounts.length, "Array length mismatch");
        require(users.length == collateralValues.length, "Array length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            if (!hasRegistered[users[i]]) {
                hasRegistered[users[i]] = true;
                lendingModule.registerCollateral(
                    users[i],
                    lpToken,
                    lpAmounts[i],
                    collateralValues[i]
                );
                emit CollateralRegistered(users[i], lpAmounts[i], collateralValues[i]);
            }
        }
    }

    /**
     * @notice Reset registration for a user (testing only)
     * @param user The user to reset
     */
    function resetUser(address user) external onlyOwner {
        hasRegistered[user] = false;
    }

    /**
     * @notice Check if a user can borrow
     * @param user The user to check
     * @return canBorrow Whether the user can borrow
     * @return maxBorrow Maximum borrow amount
     * @return healthFactor Current health factor
     */
    function getUserBorrowingStatus(address user) external view returns (
        bool canBorrow,
        uint256 maxBorrow,
        uint256 healthFactor
    ) {
        maxBorrow = lendingModule.getMaxBorrow(user);
        healthFactor = lendingModule.getHealthFactor(user);
        canBorrow = maxBorrow > 0;

        return (canBorrow, maxBorrow, healthFactor);
    }
}