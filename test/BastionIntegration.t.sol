// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BastionHook} from "../src/BastionHook.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {MockVolatilityOracle} from "../src/mocks/MockVolatilityOracle.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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

/// @title MockChainlinkPriceFeed
/// @notice Mock Chainlink price feed for testing
contract MockChainlinkPriceFeed is AggregatorV3Interface {
    int256 private _price;
    uint8 private _decimals;
    uint80 private _roundId;
    uint256 private _updatedAt;

    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _roundId = 1;
        _updatedAt = block.timestamp;
    }

    function setPrice(int256 newPrice) external {
        _price = newPrice;
        _roundId++;
        _updatedAt = block.timestamp;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}

/// @title BastionIntegrationTest
/// @notice Integration tests for BastionHook and InsuranceTranche with depeg scenarios
contract BastionIntegrationTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency currency0;
    Currency currency1;

    PoolKey poolKey;

    BastionHook hook;
    InsuranceTranche insurance;
    MockVolatilityOracle oracle;
    MockERC20 stETH;
    MockERC20 premiumToken;
    MockChainlinkPriceFeed stETHFeed;

    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    address lp1;
    address lp2;

    uint256 constant INITIAL_BALANCE = 1000000e18;
    int256 constant ETH_TARGET_PRICE = 1e8; // $1 for simplified testing
    uint8 constant PRICE_DECIMALS = 8;

    function setUp() public {
        // Deploy test infrastructure
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        lp1 = address(0x1);
        lp2 = address(0x2);

        // Deploy mock oracle
        oracle = new MockVolatilityOracle();

        // Deploy insurance-related mocks
        stETH = new MockERC20("Lido Staked ETH", "stETH");
        premiumToken = new MockERC20("Premium Token", "PREM");
        stETHFeed = new MockChainlinkPriceFeed(ETH_TARGET_PRICE, PRICE_DECIMALS);

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

        // Deploy insurance tranche
        insurance = new InsuranceTranche(address(hook));

        // Configure hook with insurance
        hook.setInsuranceTranche(address(insurance));
        hook.setPremiumToken(address(premiumToken));
        hook.setInsuranceSplit(1000); // 10%

        // Configure insurance asset
        insurance.configureAsset(address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), 2000); // 20% threshold

        // Create pool
        poolKey = PoolKey(currency0, currency1, 0x800000, 60, IHooks(hook));
        poolId = poolKey.toId();
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Provide liquidity
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

        // Mint premium tokens to hook
        premiumToken.mint(address(hook), INITIAL_BALANCE);

        // Register LPs
        vm.prank(address(hook));
        insurance.updateLPPosition(lp1, 1000e18);

        vm.prank(address(hook));
        insurance.updateLPPosition(lp2, 1000e18);

        vm.label(address(hook), "BastionHook");
        vm.label(address(insurance), "InsuranceTranche");
        vm.label(address(stETH), "stETH");
        vm.label(lp1, "LP1");
        vm.label(lp2, "LP2");
    }

    /// @notice Test insurance premium collection after swaps
    function testInsurancePremiumCollection() public {
        // Set low volatility
        oracle.setVolatility(poolKey, 500);

        // Execute swap
        uint256 amountIn = 1e18;
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Check that fees were accumulated
        uint256 accumulatedFees = hook.accumulatedFees(poolId);
        assertTrue(accumulatedFees > 0, "Should have accumulated fees");

        // Collect insurance premium
        uint256 insuranceBalanceBefore = insurance.insurancePoolBalance();
        hook.collectInsurancePremium(poolId);
        uint256 insuranceBalanceAfter = insurance.insurancePoolBalance();

        assertTrue(insuranceBalanceAfter > insuranceBalanceBefore, "Insurance pool should have received premium");

        // Verify accumulated fees reset
        assertEq(hook.accumulatedFees(poolId), 0, "Accumulated fees should be reset");
    }

    /// @notice Test depeg detection and payout execution
    function testDepegScenario() public {
        // Step 1: Collect premiums from swaps
        oracle.setVolatility(poolKey, 500);

        for (uint256 i = 0; i < 10; i++) {
            swapRouter.swapExactTokensForTokens({
                amountIn: 1e18,
                amountOutMin: 0,
                zeroForOne: i % 2 == 0,
                poolKey: poolKey,
                hookData: Constants.ZERO_BYTES,
                receiver: address(this),
                deadline: block.timestamp + 1
            });
        }

        // Collect premiums
        hook.collectInsurancePremium(poolId);

        uint256 insurancePool = insurance.insurancePoolBalance();
        assertTrue(insurancePool > 0, "Insurance pool should have funds");

        // Step 2: Simulate depeg (30% drop)
        int256 depeggedPrice = (ETH_TARGET_PRICE * 70) / 100;
        stETHFeed.setPrice(depeggedPrice);

        // Step 3: Check for depeg
        (bool isDepegged, uint256 currentPrice, uint256 deviation) = insurance.checkDepeg(address(stETH));
        assertTrue(isDepegged, "Asset should be depegged");
        assertEq(deviation, 3000, "Deviation should be 30%");

        // Step 4: Execute payout
        insurance.executePayout(address(stETH));

        // Verify payout executed
        assertEq(insurance.insurancePoolBalance(), 0, "Insurance pool should be empty after payout");
        assertEq(insurance.getPayoutHistoryCount(), 1, "Should have 1 payout event");
    }

    /// @notice Test keeper function for automated depeg monitoring
    function testKeeperDepegMonitoring() public {
        // Collect some premiums
        oracle.setVolatility(poolKey, 1200);

        swapRouter.swapExactTokensForTokens({
            amountIn: 5e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        hook.collectInsurancePremium(poolId);

        // No depeg initially
        address[] memory depegged = hook.checkAndExecuteDepegPayouts();
        assertEq(depegged.length, 0, "Should have no depegged assets");

        // Cause depeg
        int256 depeggedPrice = (ETH_TARGET_PRICE * 75) / 100; // 25% drop
        stETHFeed.setPrice(depeggedPrice);

        // Keeper checks and finds depeg
        depegged = hook.checkAndExecuteDepegPayouts();
        assertEq(depegged.length, 1, "Should detect 1 depegged asset");
        assertEq(depegged[0], address(stETH), "Should be stETH");

        // The keeper function only detects, doesn't execute (since hook is not owner of insurance)
        // Owner must manually trigger payout after keeper alerts
        assertTrue(insurance.insurancePoolBalance() > 0, "Pool should still have funds before payout");

        insurance.executePayout(address(stETH));
        assertEq(insurance.insurancePoolBalance(), 0, "Pool should be empty after payout");
    }

    /// @notice Test insurance split configuration
    function testInsuranceSplitConfiguration() public {
        // Test default (10%)
        assertEq(hook.insuranceSplit(), 1000, "Default should be 10%");

        // Update to 15%
        hook.setInsuranceSplit(1500);
        assertEq(hook.insuranceSplit(), 1500, "Should update to 15%");

        // Test minimum (5%)
        hook.setInsuranceSplit(500);
        assertEq(hook.insuranceSplit(), 500, "Should allow 5%");

        // Test maximum (20%)
        hook.setInsuranceSplit(2000);
        assertEq(hook.insuranceSplit(), 2000, "Should allow 20%");

        // Test below minimum fails
        vm.expectRevert("BastionHook: split too low");
        hook.setInsuranceSplit(499);

        // Test above maximum fails
        vm.expectRevert("BastionHook: split too high");
        hook.setInsuranceSplit(2001);
    }

    /// @notice Test multiple swap scenarios with varying insurance splits
    function testVaryingInsuranceSplits() public {
        oracle.setVolatility(poolKey, 800);

        // Test with 5% split
        hook.setInsuranceSplit(500);

        swapRouter.swapExactTokensForTokens({
            amountIn: 2e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        uint256 fees5pct = hook.accumulatedFees(poolId);
        hook.collectInsurancePremium(poolId);
        uint256 premium5pct = insurance.insurancePoolBalance();

        // Reset - cause a depeg and execute payout to clear the pool
        int256 depeggedPrice = (ETH_TARGET_PRICE * 75) / 100; // 25% drop
        stETHFeed.setPrice(depeggedPrice);
        insurance.executePayout(address(stETH));

        // Reset price back to peg
        stETHFeed.setPrice(ETH_TARGET_PRICE);

        // Test with 20% split
        hook.setInsuranceSplit(2000);

        swapRouter.swapExactTokensForTokens({
            amountIn: 2e18,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        uint256 fees20pct = hook.accumulatedFees(poolId);
        hook.collectInsurancePremium(poolId);
        uint256 premium20pct = insurance.insurancePoolBalance();

        // 20% split should result in higher premium (roughly 4x)
        assertTrue(premium20pct > premium5pct * 3, "20% split should yield significantly more premium");
    }

    /// @notice Test full end-to-end depeg scenario with multiple LPs
    function testEndToEndDepegWithMultipleLPs() public {
        // Step 1: Multiple swaps generate fees
        oracle.setVolatility(poolKey, 1200); // Medium volatility

        for (uint256 i = 0; i < 20; i++) {
            swapRouter.swapExactTokensForTokens({
                amountIn: 1e18,
                amountOutMin: 0,
                zeroForOne: i % 2 == 0,
                poolKey: poolKey,
                hookData: Constants.ZERO_BYTES,
                receiver: address(this),
                deadline: block.timestamp + 1
            });
        }

        // Step 2: Collect insurance premiums
        uint256 feesBefore = hook.accumulatedFees(poolId);
        assertTrue(feesBefore > 0, "Should have accumulated fees");

        hook.collectInsurancePremium(poolId);
        uint256 poolBalance = insurance.insurancePoolBalance();
        assertTrue(poolBalance > 0, "Insurance pool should be funded");

        // Step 3: stETH depegs severely (40% drop)
        int256 severeDepeg = (ETH_TARGET_PRICE * 60) / 100;
        stETHFeed.setPrice(severeDepeg);

        // Step 4: Verify depeg detection
        (bool isDepegged,, uint256 deviation) = insurance.checkDepeg(address(stETH));
        assertTrue(isDepegged, "Should detect severe depeg");
        assertEq(deviation, 4000, "Deviation should be 40%");

        // Step 5: Execute payout
        uint256 payoutHistoryBefore = insurance.getPayoutHistoryCount();
        insurance.executePayout(address(stETH));
        uint256 payoutHistoryAfter = insurance.getPayoutHistoryCount();

        assertEq(payoutHistoryAfter, payoutHistoryBefore + 1, "Should record payout event");

        // Step 6: Verify payout details
        (address asset, uint256 totalPayout, uint256 timestamp, uint256 price, uint256 payoutDeviation) =
            insurance.getPayoutEvent(payoutHistoryBefore);

        assertEq(asset, address(stETH), "Payout should be for stETH");
        assertEq(totalPayout, poolBalance, "Total payout should match pool balance");
        assertEq(payoutDeviation, 4000, "Payout deviation should be 40%");
        assertEq(price, uint256(uint256(severeDepeg)), "Price should match depegged price");
    }
}
