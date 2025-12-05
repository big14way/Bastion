// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILendingModule {
    // Structs
    struct Position {
        uint256 lpTokenAmount;
        uint256 collateralValue;
        uint256 borrowedAmount;
        uint256 interestRate;
        uint256 lastUpdateTime;
        uint256 accruedInterest;
        bool isActive;
    }

    // Functions
    function registerCollateral(
        address borrower,
        address lpToken,
        uint256 lpAmount,
        uint256 collateralValue
    ) external;

    function borrow(uint256 amount) external;

    function repay(uint256 amount) external;

    function liquidate(address borrower) external;

    function fundPool(uint256 amount) external;

    function withdrawFromPool(uint256 amount) external;

    function updateAuthorizedHook(address newHook) external;

    function updateInterestRate(uint256 newRate) external;

    // View functions
    function positions(address borrower) external view returns (
        uint256 lpTokenAmount,
        uint256 collateralValue,
        uint256 borrowedAmount,
        uint256 interestRate,
        uint256 lastUpdateTime,
        uint256 accruedInterest,
        bool isActive
    );

    function getCurrentDebt(address borrower) external view returns (uint256);

    function getMaxBorrow(address borrower) external view returns (uint256);

    function getHealthFactor(address borrower) external view returns (uint256);

    function getLiquidationPrice(address borrower) external view returns (uint256);

    function totalLendingPool() external view returns (uint256);

    function totalBorrowed() external view returns (uint256);

    function defaultInterestRate() external view returns (uint256);

    function authorizedHook() external view returns (address);

    function usdcToken() external view returns (address);

    function owner() external view returns (address);

    // Constants
    function LTV_RATIO() external view returns (uint256);

    function LIQUIDATION_THRESHOLD() external view returns (uint256);

    function LIQUIDATION_BONUS() external view returns (uint256);

    function BASIS_POINTS() external view returns (uint256);

    function MINIMUM_COLLATERAL() external view returns (uint256);
}