// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BastionHook} from "../src/BastionHook.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {MockVolatilityOracle} from "../src/mocks/MockVolatilityOracle.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";

import {EasyPosm} from "./utils/libraries/EasyPosm.sol";
import {BaseTest} from "./utils/BaseTest.sol";

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

/// @title LendingIntegrationTest
/// @notice Integration tests for BastionHook + LendingModule with full borrow/repay cycles
contract LendingIntegrationTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency currency0;
    Currency currency1;

    PoolKey poolKey;

    BastionHook hook;
    LendingModule lending;
    MockVolatilityOracle oracle;
    MockERC20 stablecoin;

    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    address lp1;
    address lp2;

    uint256 constant INITIAL_BALANCE = 1000000e18;
    uint256 constant LENDING_POOL = 500000e18;
    uint256 constant DEFAULT_INTEREST_RATE = 500; // 5% APR

    function setUp() public {
        // Deploy test infrastructure
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        lp1 = address(0x1);
        lp2 = address(0x2);

        // Deploy mock oracle
        oracle = new MockVolatilityOracle();

        // Deploy stablecoin for lending
        stablecoin = new MockERC20("USDC", "USDC");

        // Deploy hook
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                    | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_DONATE_FLAG
            ) ^ (0x4444 << 144)
        );
        bytes memory constructorArgs = abi.encode(poolManager, oracle);
        deployCodeTo("BastionHook.sol:BastionHook", constructorArgs, flags);
        hook = BastionHook(flags);

        // Deploy lending module
        lending = new LendingModule(address(hook), address(stablecoin), DEFAULT_INTEREST_RATE);

        // Configure hook with lending module
        hook.setLendingModule(address(lending));

        // Fund lending pool
        stablecoin.mint(address(this), LENDING_POOL);
        stablecoin.approve(address(lending), LENDING_POOL);
        lending.fundPool(LENDING_POOL);

        // Create pool
        poolKey = PoolKey(currency0, currency1, 0x800000, 60, IHooks(hook));
        poolId = poolKey.toId();
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Setup ticks
        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        // Mint stablecoins to LPs for repayments
        stablecoin.mint(lp1, 100000e18);
        stablecoin.mint(lp2, 100000e18);

        vm.prank(lp1);
        stablecoin.approve(address(lending), type(uint256).max);

        vm.prank(lp2);
        stablecoin.approve(address(lending), type(uint256).max);

        vm.label(address(hook), "BastionHook");
        vm.label(address(lending), "LendingModule");
        vm.label(address(stablecoin), "USDC");
        vm.label(lp1, "LP1");
        vm.label(lp2, "LP2");
    }

    /// @notice Test manual collateral registration on liquidity addition
    function testManualCollateralRegistration() public {
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        // Add liquidity as lp1
        vm.prank(lp1);
        (tokenId,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Manually register collateral
        uint256 collateralValue = amount0Expected + amount1Expected;
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // Check that collateral was registered
        (uint256 lpTokenAmount, uint256 registeredValue,,,, uint256 accruedInterest, bool isActive) =
            lending.positions(lp1);

        assertTrue(isActive, "Position should be active");
        assertEq(lpTokenAmount, uint256(liquidityAmount), "LP token amount should match");
        assertEq(registeredValue, collateralValue, "Collateral value should match");
        assertEq(accruedInterest, 0, "No interest initially");
    }

    /// @notice Test full borrow/repay cycle
    function testFullBorrowRepayCycle() public {
        // Step 1: Add liquidity and manually register collateral
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        vm.prank(lp1);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Manually register collateral
        uint256 collateralValue = amount0Expected + amount1Expected;
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // Step 2: Borrow against collateral
        uint256 maxBorrow = lending.getMaxBorrow(lp1);
        uint256 borrowAmount = maxBorrow / 2; // Borrow 50% of max

        uint256 balanceBefore = stablecoin.balanceOf(lp1);

        vm.prank(lp1);
        lending.borrow(borrowAmount);

        uint256 balanceAfter = stablecoin.balanceOf(lp1);

        assertEq(balanceAfter - balanceBefore, borrowAmount, "Should receive borrowed amount");

        // Step 3: Wait for interest to accrue
        vm.warp(block.timestamp + 365 days);

        uint256 totalDebt = lending.getCurrentDebt(lp1);
        assertTrue(totalDebt > borrowAmount, "Debt should include interest");

        // Step 4: Repay full debt
        vm.prank(lp1);
        lending.repay(totalDebt);

        // Step 5: Verify debt is cleared
        (,, uint256 borrowedAmount,,, uint256 accruedInterest,) = lending.positions(lp1);
        assertEq(borrowedAmount, 0, "Borrowed amount should be zero");
        assertEq(accruedInterest, 0, "Accrued interest should be zero");
    }

    /// @notice Test cannot withdraw collateral with outstanding debt
    function testCannotWithdrawCollateralWithDebt() public {
        // Add liquidity
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        vm.prank(lp1);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Manually register collateral
        uint256 collateralValue = amount0Expected + amount1Expected;
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // Borrow
        uint256 maxBorrow = lending.getMaxBorrow(lp1);
        vm.prank(lp1);
        lending.borrow(maxBorrow / 2);

        // Try to withdraw collateral - should fail due to outstanding debt
        vm.prank(lp1);
        vm.expectRevert("LendingModule: outstanding debt");
        lending.withdrawCollateral(uint256(liquidityAmount));
    }

    /// @notice Test can remove liquidity after repaying debt
    function testCanRemoveLiquidityAfterRepay() public {
        // Add liquidity
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        vm.prank(lp1);
        (uint256 tid,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Manually register collateral
        uint256 collateralValue = amount0Expected + amount1Expected;
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // Borrow and repay
        uint256 maxBorrow = lending.getMaxBorrow(lp1);
        vm.prank(lp1);
        lending.borrow(maxBorrow / 2);

        vm.warp(block.timestamp + 365 days);

        uint256 totalDebt = lending.getCurrentDebt(lp1);
        vm.prank(lp1);
        lending.repay(totalDebt);

        // Now can remove liquidity
        vm.prank(lp1);
        positionManager.decreaseLiquidity(
            tid, liquidityAmount / 2, 0, 0, lp1, block.timestamp, Constants.ZERO_BYTES
        );
    }

    /// @notice Test multiple LPs can borrow independently
    function testMultipleLPsBorrow() public {
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        uint256 collateralValue = amount0Expected + amount1Expected;

        // LP1 adds liquidity
        vm.prank(lp1);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // LP2 adds liquidity
        vm.prank(lp2);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp2,
            block.timestamp,
            Constants.ZERO_BYTES
        );
        vm.prank(lp2);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // Both borrow
        uint256 maxBorrow1 = lending.getMaxBorrow(lp1);
        uint256 maxBorrow2 = lending.getMaxBorrow(lp2);

        vm.prank(lp1);
        lending.borrow(maxBorrow1 / 2);

        vm.prank(lp2);
        lending.borrow(maxBorrow2 / 3);

        // Verify independent positions
        uint256 debt1 = lending.getCurrentDebt(lp1);
        uint256 debt2 = lending.getCurrentDebt(lp2);

        assertEq(debt1, maxBorrow1 / 2, "LP1 debt should match borrow");
        assertEq(debt2, maxBorrow2 / 3, "LP2 debt should match borrow");
        assertTrue(debt1 != debt2, "Debts should be different");
    }

    /// @notice Test partial repayment flow
    function testPartialRepayment() public {
        // Add liquidity
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        vm.prank(lp1);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Manually register collateral
        uint256 collateralValue = amount0Expected + amount1Expected;
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // Borrow
        uint256 maxBorrow = lending.getMaxBorrow(lp1);
        vm.prank(lp1);
        lending.borrow(maxBorrow / 2);

        // Wait for interest
        vm.warp(block.timestamp + 180 days);

        uint256 totalDebt = lending.getCurrentDebt(lp1);

        // Partial repayment
        uint256 partialAmount = totalDebt / 3;
        vm.prank(lp1);
        lending.repay(partialAmount);

        uint256 remainingDebt = lending.getCurrentDebt(lp1);
        assertLt(remainingDebt, totalDebt, "Debt should decrease");
        assertGt(remainingDebt, 0, "Still has debt remaining");
    }

    /// @notice Test liquidation after interest accrual
    function testLiquidationAfterInterestAccrual() public {
        // Add liquidity
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        vm.prank(lp1);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Manually register collateral
        uint256 collateralValue = amount0Expected + amount1Expected;
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        // Borrow maximum (70% LTV)
        uint256 maxBorrow = lending.getMaxBorrow(lp1);
        vm.prank(lp1);
        lending.borrow(maxBorrow);

        // Position healthy initially
        assertFalse(lending.isPositionLiquidatable(lp1));

        // Accrue interest until liquidatable (need to reach 80% threshold)
        // At 70% LTV, need 14.29% interest to reach 80%
        // At 5% APR: ~2.86 years
        vm.warp(block.timestamp + 1050 days);

        // Now liquidatable
        assertTrue(lending.isPositionLiquidatable(lp1));

        // Setup liquidator
        address liquidator = address(0x99);
        uint256 totalDebt = lending.getCurrentDebt(lp1);
        stablecoin.mint(liquidator, totalDebt);

        vm.startPrank(liquidator);
        stablecoin.approve(address(lending), totalDebt);
        lending.liquidate(lp1);
        vm.stopPrank();

        // Position should be cleared
        (,, uint256 borrowedAmount,,,, bool isActive) = lending.positions(lp1);
        assertEq(borrowedAmount, 0);
        assertFalse(isActive);
    }

    /// @notice Test increasing collateral by adding more liquidity
    function testIncreaseCollateral() public {
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        uint256 collateralValue = amount0Expected + amount1Expected;

        // First liquidity addition
        vm.prank(lp1);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        uint256 maxBorrow1 = lending.getMaxBorrow(lp1);

        // Add more liquidity
        vm.prank(lp1);
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            lp1,
            block.timestamp,
            Constants.ZERO_BYTES
        );
        vm.prank(lp1);
        hook.registerLPCollateral(uint256(liquidityAmount), collateralValue);

        uint256 maxBorrow2 = lending.getMaxBorrow(lp1);

        // Max borrow should increase
        assertGt(maxBorrow2, maxBorrow1, "Max borrow should increase with more collateral");
    }
}
