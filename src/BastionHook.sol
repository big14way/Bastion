// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

import {IVolatilityOracle} from "./interfaces/IVolatilityOracle.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

/// @title BastionHook
/// @notice A Uniswap v4 hook with dynamic fees and liquidity/swap tracking
contract BastionHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    /// @notice Configuration for basket asset weights
    /// @dev Weights are in basis points (10000 = 100%)
    struct BasketConfig {
        uint256 stETHWeight;  // Target weight for stETH
        uint256 cbETHWeight;  // Target weight for cbETH
        uint256 rETHWeight;   // Target weight for rETH
        uint256 USDeWeight;   // Target weight for USDe
    }

    /// @notice Tracks actual basket holdings
    struct BasketState {
        uint256 stETHBalance;
        uint256 cbETHBalance;
        uint256 rETHBalance;
        uint256 USDeBalance;
        uint256 totalValue;  // Total value in USD or base unit
    }

    // -----------------------------------------------
    // Constants - Fee Tiers (in hundredths of a bip, 1 bip = 0.01%)
    // -----------------------------------------------

    /// @notice Low volatility fee tier: 0.05% = 500 (500 / 1,000,000)
    uint24 public constant LOW_VOLATILITY_FEE = 500;

    /// @notice Medium volatility fee tier: 0.30% = 3,000 (3,000 / 1,000,000)
    uint24 public constant MEDIUM_VOLATILITY_FEE = 3000;

    /// @notice High volatility fee tier: 1.00% = 10,000 (10,000 / 1,000,000)
    uint24 public constant HIGH_VOLATILITY_FEE = 10000;

    // -----------------------------------------------
    // Constants - Volatility Thresholds (in basis points)
    // -----------------------------------------------

    /// @notice Low to medium volatility threshold: 10.00% = 1,000 basis points
    uint256 public constant LOW_THRESHOLD = 1000;

    /// @notice Medium to high volatility threshold: 14.00% = 1,400 basis points
    uint256 public constant HIGH_THRESHOLD = 1400;

    // -----------------------------------------------
    // Constants - Rebalancing
    // -----------------------------------------------

    /// @notice Rebalancing deviation threshold: 5.00% = 500 basis points
    /// @dev Triggers rebalance when actual weight deviates from target by this amount
    uint256 public constant REBALANCE_THRESHOLD = 500;

    /// @notice Basis points constant for percentage calculations
    uint256 public constant BASIS_POINTS = 10000;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice The volatility oracle used to determine dynamic fees
    IVolatilityOracle public immutable volatilityOracle;

    /// @notice Target basket configuration per pool
    mapping(PoolId => BasketConfig) public basketConfigs;

    /// @notice Current basket state per pool
    mapping(PoolId => BasketState) public basketStates;

    /// @notice Mapping of currency address to asset type for quick lookups
    mapping(Currency => AssetType) public assetTypes;

    /// @notice Accumulated fees from donations (rebasing tokens) per pool per currency
    mapping(PoolId => mapping(Currency => uint256)) public accumulatedDonations;

    // -----------------------------------------------
    // Enums
    // -----------------------------------------------

    /// @notice Asset types supported in the basket
    enum AssetType {
        UNKNOWN,
        STETH,
        CBETH,
        RETH,
        USDE
    }

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when basket is rebalanced
    event BasketRebalanced(PoolId indexed poolId, uint256 timestamp);

    /// @notice Emitted when donation is received (e.g., from rebasing tokens)
    event DonationReceived(PoolId indexed poolId, Currency indexed currency, uint256 amount0, uint256 amount1);

    /// @notice Emitted when basket deviation exceeds threshold
    event RebalanceTriggered(PoolId indexed poolId, uint256 maxDeviation);

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize the BastionHook with a PoolManager and VolatilityOracle
    /// @param _poolManager The Uniswap v4 PoolManager contract
    /// @param _volatilityOracle The volatility oracle contract
    constructor(IPoolManager _poolManager, IVolatilityOracle _volatilityOracle) BaseHook(_poolManager) {
        volatilityOracle = _volatilityOracle;
    }

    // -----------------------------------------------
    // Hook Permissions
    // -----------------------------------------------

    /// @notice Returns the hook permissions for this contract
    /// @return Hooks.Permissions struct with enabled hook flags
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: true,          // Enabled for dynamic fees
            afterSwap: true,
            beforeDonate: false,
            afterDonate: true,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // Hook Implementations
    // -----------------------------------------------

    /// @notice Hook called before a swap is executed
    /// @dev Used for dynamic fee implementation based on pool volatility
    /// @param key The pool key
    /// @return selector The function selector
    /// @return beforeSwapDelta The delta to apply before the swap
    /// @return swapFee The dynamic swap fee based on volatility
    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        // Get current realized volatility from oracle
        uint256 volatility = volatilityOracle.realizedVolatility(key);

        // Determine fee tier based on volatility thresholds
        uint24 dynamicFee;
        if (volatility < LOW_THRESHOLD) {
            // Low volatility: 0.05%
            dynamicFee = LOW_VOLATILITY_FEE;
        } else if (volatility < HIGH_THRESHOLD) {
            // Medium volatility: 0.30%
            dynamicFee = MEDIUM_VOLATILITY_FEE;
        } else {
            // High volatility: 1.00%
            dynamicFee = HIGH_VOLATILITY_FEE;
        }

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, dynamicFee);
    }

    /// @notice Hook called after a swap is executed
    /// @dev Checks basket deviation and triggers rebalancing if needed
    /// @param key The pool key
    /// @param delta The balance delta from the swap
    /// @return selector The function selector
    /// @return hookDelta The delta to apply after the swap
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();

        // Update basket state based on swap delta
        _updateBasketState(poolId, key, delta);

        // Check if rebalancing is needed
        (bool shouldRebalance, uint256 maxDeviation) = _shouldRebalance(poolId);
        if (shouldRebalance) {
            emit RebalanceTriggered(poolId, maxDeviation);
            _rebalanceBasket(poolId, key);
        }

        return (BaseHook.afterSwap.selector, 0);
    }

    /// @notice Hook called after liquidity is added to a pool
    /// @param key The pool key
    /// @return selector The function selector
    /// @return hookDelta The delta to apply after adding liquidity
    function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        // TODO: Implement liquidity addition tracking logic
        return (BaseHook.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    /// @notice Hook called after liquidity is removed from a pool
    /// @param key The pool key
    /// @return selector The function selector
    /// @return hookDelta The delta to apply after removing liquidity
    function _afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        // TODO: Implement liquidity removal tracking logic
        return (BaseHook.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    /// @notice Hook called after a donation is made to a pool
    /// @dev Handles rebasing token rewards by accumulating donated amounts
    /// @param key The pool key
    /// @param amount0 Amount of currency0 donated
    /// @param amount1 Amount of currency1 donated
    /// @return selector The function selector
    function _afterDonate(
        address,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();

        // Accumulate donations for rebasing tokens (e.g., stETH rewards)
        if (amount0 > 0) {
            accumulatedDonations[poolId][key.currency0] += amount0;
        }
        if (amount1 > 0) {
            accumulatedDonations[poolId][key.currency1] += amount1;
        }

        emit DonationReceived(poolId, key.currency0, amount0, amount1);

        // Check if accumulated donations warrant a rebalance
        (bool shouldRebalance, uint256 maxDeviation) = _shouldRebalance(poolId);
        if (shouldRebalance) {
            emit RebalanceTriggered(poolId, maxDeviation);
            _rebalanceBasket(poolId, key);
        }

        return BaseHook.afterDonate.selector;
    }

    // -----------------------------------------------
    // Internal Helper Functions
    // -----------------------------------------------

    /// @notice Update basket state after a swap
    /// @param poolId The pool ID
    /// @param key The pool key
    /// @param delta The balance delta from the swap
    function _updateBasketState(PoolId poolId, PoolKey calldata key, BalanceDelta delta) internal {
        BasketState storage state = basketStates[poolId];

        // Update balances based on which currencies are involved
        AssetType asset0 = assetTypes[key.currency0];
        AssetType asset1 = assetTypes[key.currency1];

        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        // Update asset balances (convert int128 to uint256, handling positive/negative)
        if (asset0 == AssetType.STETH) {
            state.stETHBalance = _updateBalance(state.stETHBalance, amount0);
        } else if (asset0 == AssetType.CBETH) {
            state.cbETHBalance = _updateBalance(state.cbETHBalance, amount0);
        } else if (asset0 == AssetType.RETH) {
            state.rETHBalance = _updateBalance(state.rETHBalance, amount0);
        } else if (asset0 == AssetType.USDE) {
            state.USDeBalance = _updateBalance(state.USDeBalance, amount0);
        }

        if (asset1 == AssetType.STETH) {
            state.stETHBalance = _updateBalance(state.stETHBalance, amount1);
        } else if (asset1 == AssetType.CBETH) {
            state.cbETHBalance = _updateBalance(state.cbETHBalance, amount1);
        } else if (asset1 == AssetType.RETH) {
            state.rETHBalance = _updateBalance(state.rETHBalance, amount1);
        } else if (asset1 == AssetType.USDE) {
            state.USDeBalance = _updateBalance(state.USDeBalance, amount1);
        }

        // Recalculate total value
        state.totalValue = state.stETHBalance + state.cbETHBalance + state.rETHBalance + state.USDeBalance;
    }

    /// @notice Helper to update balance with signed delta
    /// @param currentBalance Current balance
    /// @param delta Signed delta to apply
    /// @return Updated balance
    function _updateBalance(uint256 currentBalance, int128 delta) internal pure returns (uint256) {
        if (delta >= 0) {
            return currentBalance + uint256(int256(delta));
        } else {
            uint256 absDelta = uint256(int256(-delta));
            return currentBalance > absDelta ? currentBalance - absDelta : 0;
        }
    }

    /// @notice Check if basket needs rebalancing
    /// @param poolId The pool ID
    /// @return shouldRebalance True if rebalancing is needed
    /// @return maxDeviation Maximum deviation found (for event emission)
    function _shouldRebalance(PoolId poolId) internal view returns (bool shouldRebalance, uint256 maxDeviation) {
        BasketConfig storage config = basketConfigs[poolId];
        BasketState storage state = basketStates[poolId];

        // If no config set or total value is zero, no rebalancing needed
        if (state.totalValue == 0) {
            return (false, 0);
        }

        // Calculate current weights (in basis points)
        uint256 currentStETHWeight = (state.stETHBalance * BASIS_POINTS) / state.totalValue;
        uint256 currentCbETHWeight = (state.cbETHBalance * BASIS_POINTS) / state.totalValue;
        uint256 currentRETHWeight = (state.rETHBalance * BASIS_POINTS) / state.totalValue;
        uint256 currentUSDeWeight = (state.USDeBalance * BASIS_POINTS) / state.totalValue;

        // Check if any weight deviates by more than threshold
        uint256 stETHDeviation = _absoluteDifference(currentStETHWeight, config.stETHWeight);
        uint256 cbETHDeviation = _absoluteDifference(currentCbETHWeight, config.cbETHWeight);
        uint256 rETHDeviation = _absoluteDifference(currentRETHWeight, config.rETHWeight);
        uint256 usDeDeviation = _absoluteDifference(currentUSDeWeight, config.USDeWeight);

        maxDeviation = _max4(stETHDeviation, cbETHDeviation, rETHDeviation, usDeDeviation);

        shouldRebalance = maxDeviation > REBALANCE_THRESHOLD;
    }

    /// @notice Internal rebalance function
    /// @dev Swaps excess assets to restore target weights
    /// @param poolId The pool ID
    /// @param key The pool key
    function _rebalanceBasket(PoolId poolId, PoolKey calldata key) internal {
        // In a real implementation, this would:
        // 1. Calculate which assets are overweight and underweight
        // 2. Execute swaps through the pool manager to rebalance
        // 3. Update basket state after rebalancing
        //
        // For now, we emit an event to track when rebalancing would occur
        // The actual swap execution would require integration with the pool manager's
        // swap functionality and proper accounting of the hook's token balances

        emit BasketRebalanced(poolId, block.timestamp);

        // TODO: Implement actual rebalancing swaps
        // This would involve:
        // - Calculating target amounts for each asset
        // - Determining swap routes
        // - Executing swaps via poolManager.swap()
        // - Handling any slippage or swap failures
    }

    /// @notice Calculate absolute difference between two uint256 values
    /// @param a First value
    /// @param b Second value
    /// @return Absolute difference
    function _absoluteDifference(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /// @notice Find maximum of four uint256 values
    /// @param a First value
    /// @param b Second value
    /// @param c Third value
    /// @param d Fourth value
    /// @return Maximum value
    function _max4(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256) {
        uint256 max1 = a > b ? a : b;
        uint256 max2 = c > d ? c : d;
        return max1 > max2 ? max1 : max2;
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Set basket configuration for a pool
    /// @param poolId The pool ID
    /// @param config The basket configuration
    function setBasketConfig(PoolId poolId, BasketConfig memory config) external {
        // Validate weights sum to 100%
        require(
            config.stETHWeight + config.cbETHWeight + config.rETHWeight + config.USDeWeight == BASIS_POINTS,
            "Weights must sum to 100%"
        );

        basketConfigs[poolId] = config;
    }

    /// @notice Set asset type for a currency
    /// @param currency The currency address
    /// @param assetType The asset type
    function setAssetType(Currency currency, AssetType assetType) external {
        assetTypes[currency] = assetType;
    }
}
