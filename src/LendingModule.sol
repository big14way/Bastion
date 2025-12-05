// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title LendingModule
/// @notice LP-collateralized borrowing with fixed interest rates
/// @dev Allows LPs to borrow stablecoins against their LP positions at 70% LTV
contract LendingModule is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    /// @notice LP collateral position
    struct CollateralPosition {
        uint256 lpTokenAmount;      // Amount of LP tokens deposited
        uint256 collateralValue;    // USD value of collateral at deposit time
        uint256 borrowedAmount;     // Amount of stablecoin borrowed
        uint256 interestRate;       // Fixed interest rate in basis points (e.g., 500 = 5%)
        uint256 lastUpdateTime;     // Last time interest was accrued
        uint256 accruedInterest;    // Total accrued interest
        bool isActive;              // Whether position is active
    }

    // -----------------------------------------------
    // Constants
    // -----------------------------------------------

    /// @notice Loan-to-Value ratio: 70% = 7000 basis points
    uint256 public constant LTV_RATIO = 7000;

    /// @notice Liquidation threshold: 80% = 8000 basis points
    /// @dev Position can be liquidated if debt/collateral > 80%
    uint256 public constant LIQUIDATION_THRESHOLD = 8000;

    /// @notice Liquidation bonus: 5% = 500 basis points
    /// @dev Liquidator receives 5% bonus on collateral seized
    uint256 public constant LIQUIDATION_BONUS = 500;

    /// @notice Basis points constant for percentage calculations
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Seconds per year for interest calculations
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Address authorized to register collateral (BastionHook)
    address public authorizedHook;

    /// @notice Stablecoin token used for borrowing
    IERC20 public stablecoin;

    /// @notice Owner/admin address
    address public owner;

    /// @notice Default interest rate in basis points (e.g., 500 = 5% APR)
    uint256 public defaultInterestRate;

    /// @notice Minimum collateral value required (in stablecoin decimals)
    uint256 public minimumCollateralValue;

    /// @notice Total stablecoins available in the lending pool
    uint256 public totalLendingPool;

    /// @notice Total stablecoins borrowed
    uint256 public totalBorrowed;

    /// @notice User collateral positions
    mapping(address => CollateralPosition) public positions;

    /// @notice LP token address to price oracle mapping
    mapping(address => address) public lpTokenOracles;

    /// @notice Emergency pause state
    bool public paused;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when collateral is registered
    event CollateralRegistered(
        address indexed user,
        address indexed lpToken,
        uint256 amount,
        uint256 collateralValue
    );

    /// @notice Emitted when user borrows stablecoins
    event Borrowed(
        address indexed user,
        uint256 amount,
        uint256 interestRate,
        uint256 timestamp
    );

    /// @notice Emitted when user repays debt
    event Repaid(
        address indexed user,
        uint256 principalRepaid,
        uint256 interestRepaid,
        uint256 timestamp
    );

    /// @notice Emitted when position is liquidated
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 liquidatorBonus
    );

    /// @notice Emitted when collateral is withdrawn
    event CollateralWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when lending pool is funded
    event PoolFunded(address indexed funder, uint256 amount, uint256 newTotal);

    /// @notice Emitted when lending pool is withdrawn from
    event PoolWithdrawn(address indexed withdrawer, uint256 amount, uint256 newTotal);

    /// @notice Emitted when interest is accrued
    event InterestAccrued(address indexed user, uint256 interest, uint256 totalDebt);

    /// @notice Emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "LendingModule: caller is not owner");
        _;
    }

    modifier onlyAuthorizedHook() {
        require(msg.sender == authorizedHook, "LendingModule: caller is not authorized hook");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "LendingModule: paused");
        _;
    }

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize the LendingModule
    /// @param _authorizedHook Address of BastionHook that can register collateral
    /// @param _stablecoin Stablecoin token for borrowing
    /// @param _defaultInterestRate Default interest rate in basis points
    constructor(address _authorizedHook, address _stablecoin, uint256 _defaultInterestRate)
        ERC20("Bastion Lending Pool", "bLP")
    {
        require(_authorizedHook != address(0), "LendingModule: zero address");
        require(_stablecoin != address(0), "LendingModule: zero address");
        require(_defaultInterestRate <= 2000, "LendingModule: rate too high"); // Max 20%

        authorizedHook = _authorizedHook;
        stablecoin = IERC20(_stablecoin);
        defaultInterestRate = _defaultInterestRate;
        minimumCollateralValue = 100e18; // $100 minimum
        owner = msg.sender;
    }

    // -----------------------------------------------
    // Core Functions
    // -----------------------------------------------

    /// @notice Register LP collateral (called by BastionHook after liquidity is added)
    /// @param user Address of the LP
    /// @param lpToken Address of the LP token
    /// @param amount Amount of LP tokens
    /// @param collateralValue USD value of the collateral
    function registerCollateral(address user, address lpToken, uint256 amount, uint256 collateralValue)
        external
        onlyAuthorizedHook
        whenNotPaused
    {
        require(user != address(0), "LendingModule: zero address");
        require(amount > 0, "LendingModule: zero amount");
        require(collateralValue >= minimumCollateralValue, "LendingModule: collateral too low");

        CollateralPosition storage position = positions[user];

        // If position exists, add to it
        if (position.isActive) {
            position.lpTokenAmount += amount;
            position.collateralValue += collateralValue;
        } else {
            // Create new position
            position.lpTokenAmount = amount;
            position.collateralValue = collateralValue;
            position.borrowedAmount = 0;
            position.interestRate = defaultInterestRate;
            position.lastUpdateTime = block.timestamp;
            position.accruedInterest = 0;
            position.isActive = true;
        }

        emit CollateralRegistered(user, lpToken, amount, collateralValue);
    }

    /// @notice Borrow stablecoins against LP collateral at 70% LTV
    /// @param amount Amount of stablecoins to borrow
    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "LendingModule: zero amount");

        CollateralPosition storage position = positions[msg.sender];
        require(position.isActive, "LendingModule: no collateral");

        // Accrue interest before borrowing
        _accrueInterest(msg.sender);

        // Calculate maximum borrowable amount (70% LTV)
        uint256 maxBorrow = (position.collateralValue * LTV_RATIO) / BASIS_POINTS;
        uint256 currentDebt = position.borrowedAmount + position.accruedInterest;

        require(currentDebt + amount <= maxBorrow, "LendingModule: exceeds LTV");
        require(amount <= totalLendingPool - totalBorrowed, "LendingModule: insufficient liquidity");

        // Update position
        position.borrowedAmount += amount;
        position.lastUpdateTime = block.timestamp;

        // Update global state
        totalBorrowed += amount;

        // Transfer stablecoins to borrower
        stablecoin.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount, position.interestRate, block.timestamp);
    }

    /// @notice Repay borrowed stablecoins plus interest
    /// @param amount Amount to repay (principal + interest)
    function repay(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "LendingModule: zero amount");

        CollateralPosition storage position = positions[msg.sender];
        require(position.isActive, "LendingModule: no position");
        require(position.borrowedAmount > 0, "LendingModule: no debt");

        // Accrue interest
        _accrueInterest(msg.sender);

        uint256 totalDebt = position.borrowedAmount + position.accruedInterest;
        require(amount <= totalDebt, "LendingModule: repay exceeds debt");

        // Transfer stablecoins from user
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate how much goes to interest vs principal
        uint256 interestRepaid = 0;
        uint256 principalRepaid = 0;

        if (amount <= position.accruedInterest) {
            // Repaying only interest
            interestRepaid = amount;
            position.accruedInterest -= amount;
        } else {
            // Repaying interest + principal
            interestRepaid = position.accruedInterest;
            principalRepaid = amount - interestRepaid;

            position.accruedInterest = 0;
            position.borrowedAmount -= principalRepaid;
            totalBorrowed -= principalRepaid;
        }

        // Add interest earned back to the lending pool (grows pool for lenders)
        if (interestRepaid > 0) {
            totalLendingPool += interestRepaid;
        }

        position.lastUpdateTime = block.timestamp;

        emit Repaid(msg.sender, principalRepaid, interestRepaid, block.timestamp);

        // If debt is fully repaid, allow collateral withdrawal
        if (position.borrowedAmount == 0 && position.accruedInterest == 0) {
            // Position remains active but can withdraw collateral
        }
    }

    /// @notice Liquidate undercollateralized position
    /// @param user Address of the position to liquidate
    function liquidate(address user) external nonReentrant whenNotPaused {
        require(user != address(0), "LendingModule: zero address");

        CollateralPosition storage position = positions[user];
        require(position.isActive, "LendingModule: no position");
        require(position.borrowedAmount > 0, "LendingModule: no debt");

        // Accrue interest
        _accrueInterest(user);

        uint256 totalDebt = position.borrowedAmount + position.accruedInterest;

        // Check if position is undercollateralized
        // Liquidation threshold is 80%
        uint256 minCollateral = (totalDebt * BASIS_POINTS) / LIQUIDATION_THRESHOLD;
        require(position.collateralValue < minCollateral, "LendingModule: position healthy");

        // Calculate liquidation amounts
        // Liquidator repays debt and receives collateral + 5% bonus
        uint256 collateralToSeize = position.collateralValue;
        uint256 bonusAmount = (collateralToSeize * LIQUIDATION_BONUS) / BASIS_POINTS;
        uint256 totalCollateralSeized = collateralToSeize + bonusAmount;

        // Transfer debt from liquidator
        stablecoin.safeTransferFrom(msg.sender, address(this), totalDebt);

        // Update global state
        totalBorrowed -= position.borrowedAmount;

        // Transfer collateral value to liquidator (in practice this would be LP tokens)
        // For now, we'll emit event and mark position as liquidated
        // In production, this would transfer actual LP tokens

        emit Liquidated(user, msg.sender, totalDebt, collateralToSeize, bonusAmount);

        // Reset position
        position.lpTokenAmount = 0;
        position.collateralValue = 0;
        position.borrowedAmount = 0;
        position.accruedInterest = 0;
        position.isActive = false;
    }

    /// @notice Withdraw collateral if no outstanding debt
    /// @param amount Amount of collateral value to withdraw
    function withdrawCollateral(uint256 amount) external nonReentrant whenNotPaused {
        CollateralPosition storage position = positions[msg.sender];
        require(position.isActive, "LendingModule: no position");
        require(amount > 0, "LendingModule: zero amount");
        require(amount <= position.collateralValue, "LendingModule: insufficient collateral");

        // Accrue interest
        _accrueInterest(msg.sender);

        uint256 totalDebt = position.borrowedAmount + position.accruedInterest;
        require(totalDebt == 0, "LendingModule: outstanding debt");

        // Update position
        position.collateralValue -= amount;
        // In production, this would transfer LP tokens back to user

        emit CollateralWithdrawn(msg.sender, amount);

        // If all collateral withdrawn, deactivate position
        if (position.collateralValue == 0) {
            position.isActive = false;
        }
    }

    // -----------------------------------------------
    // Internal Functions
    // -----------------------------------------------

    /// @notice Accrue interest on a position
    /// @param user Address of the user
    function _accrueInterest(address user) internal {
        CollateralPosition storage position = positions[user];

        if (position.borrowedAmount == 0) {
            return;
        }

        uint256 timeElapsed = block.timestamp - position.lastUpdateTime;
        if (timeElapsed == 0) {
            return;
        }

        // Calculate interest: principal * rate * time / (BASIS_POINTS * SECONDS_PER_YEAR)
        uint256 interest =
            (position.borrowedAmount * position.interestRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);

        position.accruedInterest += interest;
        position.lastUpdateTime = block.timestamp;

        emit InterestAccrued(user, interest, position.borrowedAmount + position.accruedInterest);
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Get current debt of a position (principal + accrued interest)
    /// @param user Address of the user
    /// @return totalDebt Total debt including accrued interest
    function getCurrentDebt(address user) external view returns (uint256 totalDebt) {
        CollateralPosition memory position = positions[user];

        if (position.borrowedAmount == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - position.lastUpdateTime;
        uint256 pendingInterest = 0;

        if (timeElapsed > 0) {
            pendingInterest =
                (position.borrowedAmount * position.interestRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        }

        totalDebt = position.borrowedAmount + position.accruedInterest + pendingInterest;
    }

    /// @notice Get maximum borrowable amount for a user
    /// @param user Address of the user
    /// @return maxBorrow Maximum amount user can borrow
    function getMaxBorrow(address user) external view returns (uint256 maxBorrow) {
        CollateralPosition memory position = positions[user];

        if (!position.isActive) {
            return 0;
        }

        uint256 maxTotal = (position.collateralValue * LTV_RATIO) / BASIS_POINTS;

        // Calculate current debt with pending interest
        uint256 timeElapsed = block.timestamp - position.lastUpdateTime;
        uint256 pendingInterest = 0;

        if (timeElapsed > 0 && position.borrowedAmount > 0) {
            pendingInterest =
                (position.borrowedAmount * position.interestRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        }

        uint256 currentDebt = position.borrowedAmount + position.accruedInterest + pendingInterest;

        if (maxTotal > currentDebt) {
            maxBorrow = maxTotal - currentDebt;
        }
    }

    /// @notice Check if a position is liquidatable
    /// @param user Address of the user
    /// @return isLiquidatable Whether position can be liquidated
    function isPositionLiquidatable(address user) external view returns (bool isLiquidatable) {
        CollateralPosition memory position = positions[user];

        if (!position.isActive || position.borrowedAmount == 0) {
            return false;
        }

        // Calculate total debt with pending interest
        uint256 timeElapsed = block.timestamp - position.lastUpdateTime;
        uint256 pendingInterest =
            (position.borrowedAmount * position.interestRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);

        uint256 totalDebt = position.borrowedAmount + position.accruedInterest + pendingInterest;

        // Check if debt/collateral ratio exceeds liquidation threshold
        uint256 minCollateral = (totalDebt * BASIS_POINTS) / LIQUIDATION_THRESHOLD;

        isLiquidatable = position.collateralValue < minCollateral;
    }

    /// @notice Get health factor of a position (collateral / debt ratio)
    /// @param user Address of the user
    /// @return healthFactor Health factor in basis points (10000 = 100%)
    function getHealthFactor(address user) external view returns (uint256 healthFactor) {
        CollateralPosition memory position = positions[user];

        if (!position.isActive || position.borrowedAmount == 0) {
            return type(uint256).max; // Infinite health if no debt
        }

        uint256 timeElapsed = block.timestamp - position.lastUpdateTime;
        uint256 pendingInterest =
            (position.borrowedAmount * position.interestRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);

        uint256 totalDebt = position.borrowedAmount + position.accruedInterest + pendingInterest;

        // Health factor = (collateral / debt) * 10000
        healthFactor = (position.collateralValue * BASIS_POINTS) / totalDebt;
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Fund the lending pool with stablecoins
    /// @param amount Amount of stablecoins to add
    function fundPool(uint256 amount) external onlyOwner {
        require(amount > 0, "LendingModule: zero amount");

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        totalLendingPool += amount;

        // Mint pool tokens to funder
        _mint(msg.sender, amount);

        emit PoolFunded(msg.sender, amount, totalLendingPool);
    }

    /// @notice Withdraw from the lending pool (admin only)
    /// @dev Can only withdraw funds not currently borrowed
    /// @param amount Amount of stablecoins to withdraw
    function withdrawFromPool(uint256 amount) external onlyOwner {
        require(amount > 0, "LendingModule: zero amount");

        // Calculate available liquidity (pool - borrowed)
        uint256 availableLiquidity = totalLendingPool - totalBorrowed;
        require(amount <= availableLiquidity, "LendingModule: insufficient liquidity");

        // Check admin has enough pool tokens to burn
        require(balanceOf(msg.sender) >= amount, "LendingModule: insufficient pool tokens");

        // Update state
        totalLendingPool -= amount;

        // Burn pool tokens from admin
        _burn(msg.sender, amount);

        // Transfer stablecoins to admin
        stablecoin.safeTransfer(msg.sender, amount);

        emit PoolWithdrawn(msg.sender, amount, totalLendingPool);
    }

    /// @notice Set default interest rate
    /// @param rate Interest rate in basis points
    function setDefaultInterestRate(uint256 rate) external onlyOwner {
        require(rate <= 2000, "LendingModule: rate too high"); // Max 20%
        defaultInterestRate = rate;
    }

    /// @notice Set minimum collateral value
    /// @param minValue Minimum collateral value
    function setMinimumCollateralValue(uint256 minValue) external onlyOwner {
        minimumCollateralValue = minValue;
    }

    /// @notice Emergency pause
    function pause() external onlyOwner {
        paused = true;
    }

    /// @notice Unpause
    function unpause() external onlyOwner {
        paused = false;
    }

    /// @notice Update the authorized hook address
    /// @param newHook New hook address
    function updateAuthorizedHook(address newHook) external onlyOwner {
        require(newHook != address(0), "LendingModule: zero address");
        authorizedHook = newHook;
    }

    /// @notice Transfer ownership
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "LendingModule: zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
