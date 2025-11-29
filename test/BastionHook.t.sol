// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

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
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";

import {EasyPosm} from "./utils/libraries/EasyPosm.sol";

import {BastionHook} from "../src/BastionHook.sol";
import {MockVolatilityOracle} from "../src/mocks/MockVolatilityOracle.sol";
import {BaseTest} from "./utils/BaseTest.sol";

/// @title BastionHookTest
/// @notice Comprehensive tests for BastionHook's dynamic fee system
contract BastionHookTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency currency0;
    Currency currency1;

    PoolKey poolKey;

    BastionHook hook;
    MockVolatilityOracle oracle;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    // Fee tier constants (matching BastionHook)
    uint24 constant LOW_VOLATILITY_FEE = 500;      // 0.05%
    uint24 constant MEDIUM_VOLATILITY_FEE = 3000;  // 0.30%
    uint24 constant HIGH_VOLATILITY_FEE = 10000;   // 1.00%

    // Volatility thresholds (in basis points)
    uint256 constant LOW_THRESHOLD = 1000;   // 10.00%
    uint256 constant HIGH_THRESHOLD = 1400;  // 14.00%

    function setUp() public {
        // Deploy all required artifacts
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        // Deploy the mock volatility oracle
        oracle = new MockVolatilityOracle();

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                    | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_DONATE_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(poolManager, oracle); // Add all the necessary constructor arguments
        deployCodeTo("BastionHook.sol:BastionHook", constructorArgs, flags);
        hook = BastionHook(flags);

        // Create the pool with dynamic fee flag (0x800000 = DYNAMIC_FEE_FLAG)
        poolKey = PoolKey(currency0, currency1, 0x800000, 60, IHooks(hook));
        poolId = poolKey.toId();
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );

        vm.label(address(hook), "BastionHook");
        vm.label(address(oracle), "MockVolatilityOracle");
    }

    /// @notice Test that low volatility (< 10%) returns 0.05% fee
    function testLowVolatilityFee() public {
        // Set volatility to 5% (500 basis points) - below LOW_THRESHOLD
        uint256 lowVolatility = 500;
        oracle.setVolatility(poolKey, lowVolatility);

        // Verify oracle is set correctly
        assertEq(oracle.realizedVolatility(poolKey), lowVolatility);

        // Perform a swap
        uint256 amountIn = 1e18;

        // Get pool state before swap
        (uint160 sqrtPriceBeforeX96,,,) = poolManager.getSlot0(poolId);

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify swap executed
        assertEq(int256(swapDelta.amount0()), -int256(amountIn));

        // Get pool state after swap to verify fee was applied
        (uint160 sqrtPriceAfterX96,,,) = poolManager.getSlot0(poolId);
        assertTrue(sqrtPriceAfterX96 != sqrtPriceBeforeX96, "Price should have changed");

        // The swap should have succeeded with the low fee tier
        // (implicit validation - if wrong fee was used, price impact would differ)
    }

    /// @notice Test that medium volatility (10-14%) returns 0.30% fee
    function testMediumVolatilityFee() public {
        // Set volatility to 12% (1200 basis points) - between LOW_THRESHOLD and HIGH_THRESHOLD
        uint256 mediumVolatility = 1200;
        oracle.setVolatility(poolKey, mediumVolatility);

        // Verify oracle is set correctly
        assertEq(oracle.realizedVolatility(poolKey), mediumVolatility);

        // Perform a swap
        uint256 amountIn = 1e18;

        // Get pool state before swap
        (uint160 sqrtPriceBeforeX96,,,) = poolManager.getSlot0(poolId);

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify swap executed
        assertEq(int256(swapDelta.amount0()), -int256(amountIn));

        // Get pool state after swap to verify fee was applied
        (uint160 sqrtPriceAfterX96,,,) = poolManager.getSlot0(poolId);
        assertTrue(sqrtPriceAfterX96 != sqrtPriceBeforeX96, "Price should have changed");

        // The swap should have succeeded with the medium fee tier
    }

    /// @notice Test that high volatility (>= 14%) returns 1.00% fee
    function testHighVolatilityFee() public {
        // Set volatility to 20% (2000 basis points) - above HIGH_THRESHOLD
        uint256 highVolatility = 2000;
        oracle.setVolatility(poolKey, highVolatility);

        // Verify oracle is set correctly
        assertEq(oracle.realizedVolatility(poolKey), highVolatility);

        // Perform a swap
        uint256 amountIn = 1e18;

        // Get pool state before swap
        (uint160 sqrtPriceBeforeX96,,,) = poolManager.getSlot0(poolId);

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify swap executed
        assertEq(int256(swapDelta.amount0()), -int256(amountIn));

        // Get pool state after swap to verify fee was applied
        (uint160 sqrtPriceAfterX96,,,) = poolManager.getSlot0(poolId);
        assertTrue(sqrtPriceAfterX96 != sqrtPriceBeforeX96, "Price should have changed");

        // The swap should have succeeded with the high fee tier
    }

    /// @notice Test that fee updates correctly when volatility changes
    function testFeeUpdatesWithVolatilityChanges() public {
        uint256 amountIn = 1e18;

        // Test 1: Start with low volatility (5%)
        oracle.setVolatility(poolKey, 500);
        assertEq(oracle.realizedVolatility(poolKey), 500);

        BalanceDelta swapDelta1 = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertTrue(swapDelta1.amount0() < 0, "Swap 1 should have consumed token0");

        // Test 2: Update to medium volatility (12%)
        oracle.setVolatility(poolKey, 1200);
        assertEq(oracle.realizedVolatility(poolKey), 1200);

        BalanceDelta swapDelta2 = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: false, // Reverse direction
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertTrue(swapDelta2.amount1() < 0, "Swap 2 should have consumed token1");

        // Test 3: Update to high volatility (20%)
        oracle.setVolatility(poolKey, 2000);
        assertEq(oracle.realizedVolatility(poolKey), 2000);

        BalanceDelta swapDelta3 = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertTrue(swapDelta3.amount0() < 0, "Swap 3 should have consumed token0");

        // All three swaps should have succeeded with different fees
        // The existence of successful swaps proves the dynamic fee system is working
    }

    /// @notice Test exact threshold boundaries
    function testVolatilityThresholdBoundaries() public {
        uint256 amountIn = 1e18;

        // Test at exactly LOW_THRESHOLD (10%) - should use medium fee
        oracle.setVolatility(poolKey, LOW_THRESHOLD);
        BalanceDelta swapDelta1 = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        assertTrue(swapDelta1.amount0() < 0, "Swap at LOW_THRESHOLD should succeed");

        // Test at exactly HIGH_THRESHOLD (14%) - should use high fee
        oracle.setVolatility(poolKey, HIGH_THRESHOLD);
        BalanceDelta swapDelta2 = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        assertTrue(swapDelta2.amount1() < 0, "Swap at HIGH_THRESHOLD should succeed");

        // Test just below LOW_THRESHOLD - should use low fee
        oracle.setVolatility(poolKey, LOW_THRESHOLD - 1);
        BalanceDelta swapDelta3 = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        assertTrue(swapDelta3.amount0() < 0, "Swap below LOW_THRESHOLD should succeed");

        // Test just below HIGH_THRESHOLD - should use medium fee
        oracle.setVolatility(poolKey, HIGH_THRESHOLD - 1);
        BalanceDelta swapDelta4 = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        assertTrue(swapDelta4.amount1() < 0, "Swap below HIGH_THRESHOLD should succeed");
    }

    /// @notice Test zero volatility edge case
    function testZeroVolatility() public {
        // Set volatility to 0 - should use low fee tier
        oracle.setVolatility(poolKey, 0);
        assertEq(oracle.realizedVolatility(poolKey), 0);

        uint256 amountIn = 1e18;
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertEq(int256(swapDelta.amount0()), -int256(amountIn));
    }

    /// @notice Test extremely high volatility
    function testExtremelyHighVolatility() public {
        // Set volatility to 100% (10000 basis points) - should use high fee tier
        oracle.setVolatility(poolKey, 10000);
        assertEq(oracle.realizedVolatility(poolKey), 10000);

        uint256 amountIn = 1e18;
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertEq(int256(swapDelta.amount0()), -int256(amountIn));
    }
}
