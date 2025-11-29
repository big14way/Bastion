// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Simple mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

/// @title LendingModuleTest
/// @notice Comprehensive tests for LendingModule
contract LendingModuleTest is Test {
    LendingModule public lending;
    MockERC20 public stablecoin;

    address public hook;
    address public user1;
    address public user2;
    address public liquidator;

    uint256 constant INITIAL_POOL = 1000000e18; // $1M
    uint256 constant DEFAULT_INTEREST_RATE = 500; // 5% APR
    uint256 constant COLLATERAL_VALUE = 10000e18; // $10k
    uint256 constant LP_AMOUNT = 100e18;

    function setUp() public {
        hook = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);
        liquidator = address(0x4);

        // Deploy stablecoin
        stablecoin = new MockERC20("USDC", "USDC");

        // Deploy lending module
        lending = new LendingModule(hook, address(stablecoin), DEFAULT_INTEREST_RATE);

        // Mint stablecoins and fund pool
        stablecoin.mint(address(this), INITIAL_POOL);
        stablecoin.approve(address(lending), INITIAL_POOL);
        lending.fundPool(INITIAL_POOL);

        // Mint stablecoins to users for repayments
        stablecoin.mint(user1, 100000e18);
        stablecoin.mint(user2, 100000e18);
        stablecoin.mint(liquidator, 100000e18);

        // Setup approvals
        vm.prank(user1);
        stablecoin.approve(address(lending), type(uint256).max);

        vm.prank(user2);
        stablecoin.approve(address(lending), type(uint256).max);

        vm.prank(liquidator);
        stablecoin.approve(address(lending), type(uint256).max);

        vm.label(hook, "Hook");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(liquidator, "Liquidator");
    }

    /// @notice Test collateral registration
    function testRegisterCollateral() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        (
            uint256 lpTokenAmount,
            uint256 collateralValue,
            uint256 borrowedAmount,
            uint256 interestRate,
            uint256 lastUpdateTime,
            uint256 accruedInterest,
            bool isActive
        ) = lending.positions(user1);

        assertEq(lpTokenAmount, LP_AMOUNT, "LP token amount should match");
        assertEq(collateralValue, COLLATERAL_VALUE, "Collateral value should match");
        assertEq(borrowedAmount, 0, "Borrowed amount should be zero");
        assertEq(interestRate, DEFAULT_INTEREST_RATE, "Interest rate should match default");
        assertEq(lastUpdateTime, block.timestamp, "Last update time should be current");
        assertEq(accruedInterest, 0, "Accrued interest should be zero");
        assertTrue(isActive, "Position should be active");
    }

    /// @notice Test registering collateral multiple times adds to position
    function testRegisterCollateralMultipleTimes() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        (uint256 lpTokenAmount, uint256 collateralValue,,,,, bool isActive) = lending.positions(user1);

        assertEq(lpTokenAmount, LP_AMOUNT * 2, "LP amount should double");
        assertEq(collateralValue, COLLATERAL_VALUE * 2, "Collateral value should double");
        assertTrue(isActive, "Position should still be active");
    }

    /// @notice Test only hook can register collateral
    function testOnlyHookCanRegisterCollateral() public {
        vm.expectRevert("LendingModule: caller is not authorized hook");
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);
    }

    /// @notice Test minimum collateral value requirement
    function testMinimumCollateralValue() public {
        vm.prank(hook);
        vm.expectRevert("LendingModule: collateral too low");
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, 50e18); // Only $50
    }

    /// @notice Test basic borrow
    function testBorrow() public {
        // Register collateral
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        // Borrow 70% of collateral
        uint256 borrowAmount = (COLLATERAL_VALUE * 7000) / 10000; // 70% LTV

        uint256 balanceBefore = stablecoin.balanceOf(user1);

        vm.prank(user1);
        lending.borrow(borrowAmount);

        uint256 balanceAfter = stablecoin.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, borrowAmount, "Should receive borrowed amount");

        (,, uint256 borrowedAmount,,, uint256 accruedInterest,) = lending.positions(user1);
        assertEq(borrowedAmount, borrowAmount, "Borrowed amount should be recorded");
        assertEq(accruedInterest, 0, "No interest should be accrued yet");
    }

    /// @notice Test cannot borrow more than LTV allows
    function testCannotExceedLTV() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        // Try to borrow 80% (exceeds 70% LTV)
        uint256 excessiveBorrow = (COLLATERAL_VALUE * 8000) / 10000;

        vm.prank(user1);
        vm.expectRevert("LendingModule: exceeds LTV");
        lending.borrow(excessiveBorrow);
    }

    /// @notice Test cannot borrow without collateral
    function testCannotBorrowWithoutCollateral() public {
        vm.prank(user1);
        vm.expectRevert("LendingModule: no collateral");
        lending.borrow(1000e18);
    }

    /// @notice Test repay principal and interest
    function testRepay() public {
        // Setup: register collateral and borrow
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        uint256 borrowAmount = 5000e18;
        vm.prank(user1);
        lending.borrow(borrowAmount);

        // Fast forward 1 year to accrue interest
        vm.warp(block.timestamp + 365 days);

        // Calculate expected interest: 5000 * 5% = 250
        uint256 expectedInterest = (borrowAmount * DEFAULT_INTEREST_RATE) / 10000;
        uint256 totalDebt = lending.getCurrentDebt(user1);

        assertEq(totalDebt, borrowAmount + expectedInterest, "Total debt should include interest");

        // Repay full debt
        vm.prank(user1);
        lending.repay(totalDebt);

        (,, uint256 borrowedAmount,,, uint256 accruedInterest,) = lending.positions(user1);
        assertEq(borrowedAmount, 0, "Borrowed amount should be zero");
        assertEq(accruedInterest, 0, "Accrued interest should be zero");
    }

    /// @notice Test partial repayment (interest only)
    function testPartialRepayInterestOnly() public {
        // Setup
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        uint256 borrowAmount = 5000e18;
        vm.prank(user1);
        lending.borrow(borrowAmount);

        // Fast forward to accrue some interest
        vm.warp(block.timestamp + 180 days);

        uint256 totalDebt = lending.getCurrentDebt(user1);
        uint256 partialRepay = 100e18; // Repay small amount

        vm.prank(user1);
        lending.repay(partialRepay);

        uint256 newDebt = lending.getCurrentDebt(user1);
        assertLt(newDebt, totalDebt, "Debt should decrease");
        assertTrue(newDebt > borrowAmount, "Still have principal remaining");
    }

    /// @notice Test interest accrual over time
    function testInterestAccrual() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        uint256 borrowAmount = 5000e18; // Borrow less to avoid LTV issues over time
        vm.prank(user1);
        lending.borrow(borrowAmount);

        // No interest initially
        assertEq(lending.getCurrentDebt(user1), borrowAmount);

        // After 1 year: 5000 * 5% = 250
        vm.warp(block.timestamp + 365 days);
        uint256 debt1Year = lending.getCurrentDebt(user1);
        uint256 expectedInterest = (borrowAmount * DEFAULT_INTEREST_RATE) / 10000;
        assertEq(debt1Year, borrowAmount + expectedInterest, "Interest after 1 year");

        // After 2 years (interest on principal only, not compounding)
        vm.warp(block.timestamp + 365 days);
        uint256 debt2Year = lending.getCurrentDebt(user1);
        assertEq(debt2Year, borrowAmount + expectedInterest * 2, "Interest after 2 years");
    }

    /// @notice Test liquidation of undercollateralized position
    function testLiquidation() public {
        // Setup: user1 borrows maximum at 70% LTV
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        uint256 borrowAmount = (COLLATERAL_VALUE * 7000) / 10000; // 70% LTV
        vm.prank(user1);
        lending.borrow(borrowAmount);

        // Position is healthy initially
        assertFalse(lending.isPositionLiquidatable(user1), "Position should be healthy");

        // Accrue interest to push over liquidation threshold
        // Need debt to reach 80% of collateral (liquidation threshold)
        // Current: 7000, threshold: 8000, need 1000 more in debt
        // 1000 / 7000 = 14.29% interest needed
        // At 5% APR: 14.29% / 5% = 2.86 years ~= 1044 days
        vm.warp(block.timestamp + 1050 days);

        // Check if liquidatable
        assertTrue(lending.isPositionLiquidatable(user1), "Position should be liquidatable");

        // Liquidate
        vm.prank(liquidator);
        lending.liquidate(user1);

        // Check position is cleared
        (,, uint256 borrowedAmount,,,, bool isActive) = lending.positions(user1);
        assertEq(borrowedAmount, 0, "Borrowed amount should be zero");
        assertFalse(isActive, "Position should be inactive");
    }

    /// @notice Test cannot liquidate healthy position
    function testCannotLiquidateHealthyPosition() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        uint256 borrowAmount = 5000e18; // 50% LTV
        vm.prank(user1);
        lending.borrow(borrowAmount);

        vm.prank(liquidator);
        vm.expectRevert("LendingModule: position healthy");
        lending.liquidate(user1);
    }

    /// @notice Test health factor calculation
    function testHealthFactor() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        // No debt = infinite health
        assertEq(lending.getHealthFactor(user1), type(uint256).max);

        // Borrow 50% of collateral
        uint256 borrowAmount = COLLATERAL_VALUE / 2;
        vm.prank(user1);
        lending.borrow(borrowAmount);

        // Health factor should be 200% (collateral/debt * 100)
        uint256 healthFactor = lending.getHealthFactor(user1);
        assertEq(healthFactor, 20000, "Health factor should be 200%");

        // Borrow more to 70%
        uint256 additionalBorrow = (COLLATERAL_VALUE * 2000) / 10000;
        vm.prank(user1);
        lending.borrow(additionalBorrow);

        // New health factor should be ~142% (10000/7000 * 100)
        uint256 newHealthFactor = lending.getHealthFactor(user1);
        assertApproxEqAbs(newHealthFactor, 14285, 10, "Health factor should be ~142%");
    }

    /// @notice Test max borrow calculation
    function testGetMaxBorrow() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        // Max borrow should be 70% of collateral
        uint256 maxBorrow = lending.getMaxBorrow(user1);
        assertEq(maxBorrow, (COLLATERAL_VALUE * 7000) / 10000, "Max borrow at 70% LTV");

        // Borrow half of max
        uint256 borrowAmount = maxBorrow / 2;
        vm.prank(user1);
        lending.borrow(borrowAmount);

        // Remaining max should be approximately half
        uint256 remainingMax = lending.getMaxBorrow(user1);
        assertApproxEqAbs(remainingMax, maxBorrow / 2, 1e15, "Remaining max ~half");
    }

    /// @notice Test withdraw collateral after full repayment
    function testWithdrawCollateral() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        uint256 borrowAmount = 5000e18;
        vm.prank(user1);
        lending.borrow(borrowAmount);

        // Cannot withdraw with outstanding debt
        vm.prank(user1);
        vm.expectRevert("LendingModule: outstanding debt");
        lending.withdrawCollateral(COLLATERAL_VALUE);

        // Repay debt
        vm.warp(block.timestamp + 365 days);
        uint256 totalDebt = lending.getCurrentDebt(user1);
        vm.prank(user1);
        lending.repay(totalDebt);

        // Now can withdraw
        vm.prank(user1);
        lending.withdrawCollateral(COLLATERAL_VALUE);

        (,, uint256 collateralValue,,,, bool isActive) = lending.positions(user1);
        assertEq(collateralValue, 0, "Collateral should be withdrawn");
        assertFalse(isActive, "Position should be inactive");
    }

    /// @notice Test multiple users can have positions
    function testMultipleUsers() public {
        // User 1 borrows
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        vm.prank(user1);
        lending.borrow(3000e18);

        // User 2 borrows
        vm.prank(hook);
        lending.registerCollateral(user2, address(0x6), LP_AMOUNT, COLLATERAL_VALUE);

        vm.prank(user2);
        lending.borrow(4000e18);

        // Both positions should be independent
        assertEq(lending.getCurrentDebt(user1), 3000e18);
        assertEq(lending.getCurrentDebt(user2), 4000e18);
    }

    /// @notice Test pool liquidity limits
    function testPoolLiquidityLimit() public {
        // Register large collateral
        uint256 hugeCollateral = 10000000e18; // $10M
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), 1000e18, hugeCollateral);

        // Try to borrow more than pool has (pool has 1M, collateral allows 7M)
        uint256 excessiveBorrow = INITIAL_POOL + 1e18;

        vm.prank(user1);
        vm.expectRevert("LendingModule: insufficient liquidity");
        lending.borrow(excessiveBorrow);

        // Can borrow up to pool limit
        vm.prank(user1);
        lending.borrow(INITIAL_POOL);
    }

    /// @notice Test admin functions
    function testAdminFunctions() public {
        // Set interest rate
        lending.setDefaultInterestRate(1000); // 10%
        assertEq(lending.defaultInterestRate(), 1000);

        // Set minimum collateral
        lending.setMinimumCollateralValue(200e18);
        assertEq(lending.minimumCollateralValue(), 200e18);

        // Pause/unpause
        lending.pause();
        assertTrue(lending.paused());

        lending.unpause();
        assertFalse(lending.paused());
    }

    /// @notice Test pause functionality blocks operations
    function testPauseBlocksOperations() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        lending.pause();

        vm.prank(user1);
        vm.expectRevert("LendingModule: paused");
        lending.borrow(1000e18);

        vm.prank(hook);
        vm.expectRevert("LendingModule: paused");
        lending.registerCollateral(user2, address(0x6), LP_AMOUNT, COLLATERAL_VALUE);
    }

    /// @notice Test interest rate limits
    function testInterestRateLimits() public {
        // Cannot set rate above 20%
        vm.expectRevert("LendingModule: rate too high");
        lending.setDefaultInterestRate(2001);

        // Can set at exactly 20%
        lending.setDefaultInterestRate(2000);
        assertEq(lending.defaultInterestRate(), 2000);
    }

    /// @notice Test funding pool mints tokens
    function testFundPoolMintsTokens() public {
        uint256 additionalFunding = 50000e18;

        stablecoin.mint(address(this), additionalFunding);
        stablecoin.approve(address(lending), additionalFunding);

        uint256 balanceBefore = lending.balanceOf(address(this));
        lending.fundPool(additionalFunding);
        uint256 balanceAfter = lending.balanceOf(address(this));

        assertEq(balanceAfter - balanceBefore, additionalFunding, "Should mint pool tokens");
        assertEq(lending.totalLendingPool(), INITIAL_POOL + additionalFunding, "Pool should grow");
    }

    /// @notice Test ownership transfer
    function testOwnershipTransfer() public {
        address newOwner = address(0x99);

        lending.transferOwnership(newOwner);

        // Old owner cannot perform admin functions
        vm.expectRevert("LendingModule: caller is not owner");
        lending.pause();

        // New owner can
        vm.prank(newOwner);
        lending.pause();
        assertTrue(lending.paused());
    }

    /// @notice Test zero amount validations
    function testZeroAmountValidations() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        vm.prank(user1);
        vm.expectRevert("LendingModule: zero amount");
        lending.borrow(0);

        vm.prank(user1);
        vm.expectRevert("LendingModule: zero amount");
        lending.repay(0);

        vm.prank(user1);
        vm.expectRevert("LendingModule: zero amount");
        lending.withdrawCollateral(0);
    }

    /// @notice Test edge case: borrow, wait, borrow more
    function testBorrowMultipleTimes() public {
        vm.prank(hook);
        lending.registerCollateral(user1, address(0x5), LP_AMOUNT, COLLATERAL_VALUE);

        // First borrow
        vm.prank(user1);
        lending.borrow(3000e18);

        // Wait and accrue interest
        vm.warp(block.timestamp + 180 days);

        // Borrow more
        uint256 maxBorrow = lending.getMaxBorrow(user1);
        assertTrue(maxBorrow > 0, "Should still be able to borrow");

        vm.prank(user1);
        lending.borrow(maxBorrow);

        // Total borrowed should include both amounts
        (,, uint256 borrowedAmount,,,,) = lending.positions(user1);
        assertEq(borrowedAmount, 3000e18 + maxBorrow, "Should track total borrowed");
    }
}
