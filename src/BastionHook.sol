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
import {IAVSConsumer} from "./interfaces/IAVSConsumer.sol";
import {InsuranceTranche} from "./InsuranceTranche.sol";
import {LendingModule} from "./LendingModule.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BastionTaskManager} from "./avs/BastionTaskManager.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";

/// @title BastionHook
/// @notice A Uniswap v4 hook with dynamic fees, basket rebalancing, and insurance integration
contract BastionHook is BaseHook, IAVSConsumer {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

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

    /// @notice Minimum insurance split: 5% = 500 basis points
    uint256 public constant MIN_INSURANCE_SPLIT = 500;

    /// @notice Maximum insurance split: 20% = 2000 basis points
    uint256 public constant MAX_INSURANCE_SPLIT = 2000;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice The volatility oracle used to determine dynamic fees
    IVolatilityOracle public immutable volatilityOracle;

    /// @notice Bastion AVS task manager for validated oracle data
    BastionTaskManager public bastionTaskManager;

    /// @notice Insurance tranche for depeg protection
    InsuranceTranche public insuranceTranche;

    /// @notice Lending module for LP-collateralized borrowing
    LendingModule public lendingModule;

    /// @notice Insurance premium split in basis points (5-20% of swap fees)
    uint256 public insuranceSplit;

    /// @notice Premium token used for insurance payments
    IERC20 public premiumToken;

    /// @notice Owner/admin address
    address public owner;

    /// @notice Target basket configuration per pool
    mapping(PoolId => BasketConfig) public basketConfigs;

    /// @notice Current basket state per pool
    mapping(PoolId => BasketState) public basketStates;

    /// @notice Mapping of currency address to asset type for quick lookups
    mapping(Currency => AssetType) public assetTypes;

    /// @notice Accumulated fees from donations (rebasing tokens) per pool per currency
    mapping(PoolId => mapping(Currency => uint256)) public accumulatedDonations;

    /// @notice Accumulated swap fees available for insurance premiums per pool
    mapping(PoolId => uint256) public accumulatedFees;

    /// @notice DEX router for rebalancing swaps
    ISwapRouter public swapRouter;

    /// @notice Token addresses for basket assets
    address public stETHToken;
    address public cbETHToken;
    address public rETHToken;
    address public USDeToken;
    address public baseToken; // WETH or stablecoin for swaps

    /// @notice Maximum slippage for rebalancing swaps (basis points)
    uint256 public maxRebalanceSlippage = 100; // 1% default

    /// @notice Minimum swap amount to prevent dust swaps
    uint256 public minSwapAmount = 1e15; // 0.001 tokens

    /// @notice Whether rebalancing is enabled
    bool public rebalancingEnabled = true;

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

    /// @notice Emitted when insurance premium is collected
    event InsurancePremiumCollected(PoolId indexed poolId, uint256 premium, uint256 remainingFees);

    /// @notice Emitted when insurance split is updated
    event InsuranceSplitUpdated(uint256 oldSplit, uint256 newSplit);

    /// @notice Emitted when insurance tranche is set
    event InsuranceTrancheSet(address indexed tranche);

    /// @notice Emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when swap router is set
    event SwapRouterSet(address indexed router);

    /// @notice Emitted when basket tokens are configured
    event BasketTokensConfigured(address stETH, address cbETH, address rETH, address USDe, address base);

    /// @notice Emitted when rebalancing swap is executed
    event RebalanceSwapExecuted(
        PoolId indexed poolId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /// @notice Emitted when rebalancing settings are updated
    event RebalancingSettingsUpdated(uint256 maxSlippage, uint256 minSwapAmount, bool enabled);

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "BastionHook: caller is not owner");
        _;
    }

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize the BastionHook with a PoolManager and VolatilityOracle
    /// @param _poolManager The Uniswap v4 PoolManager contract
    /// @param _volatilityOracle The volatility oracle contract
    constructor(IPoolManager _poolManager, IVolatilityOracle _volatilityOracle) BaseHook(_poolManager) {
        volatilityOracle = _volatilityOracle;
        owner = msg.sender;
        insuranceSplit = 1000; // Default 10%
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
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();

        // Update basket state based on swap delta
        _updateBasketState(poolId, key, delta);

        // Accumulate swap fees for insurance premiums
        // Fee is calculated based on the swap amount
        if (address(insuranceTranche) != address(0) && address(premiumToken) != address(0)) {
            _accumulateSwapFees(poolId, params);
        }

        // Check if rebalancing is needed
        (bool shouldRebalance, uint256 maxDeviation) = _shouldRebalance(poolId);
        if (shouldRebalance) {
            emit RebalanceTriggered(poolId, maxDeviation);
            _rebalanceBasket(poolId, key);
        }

        return (BaseHook.afterSwap.selector, 0);
    }

    /// @notice Hook called after liquidity is added to a pool
    /// @dev LPs must manually register collateral via registerLPCollateral()
    /// @param sender Address providing liquidity
    /// @param key The pool key
    /// @param params Liquidity modification parameters
    /// @param delta Balance delta from liquidity addition
    /// @return selector The function selector
    /// @return hookDelta The delta to apply after adding liquidity
    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        // Note: Automatic registration is not possible because sender is PositionManager
        // LPs must manually call registerLPCollateral() after adding liquidity
        return (BaseHook.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    /// @notice Manually register LP collateral for borrowing
    /// @dev Must be called by LP after adding liquidity
    /// @param lpTokenAmount Amount of LP tokens to register as collateral
    /// @param collateralValue USD value of the collateral
    function registerLPCollateral(uint256 lpTokenAmount, uint256 collateralValue) external {
        require(address(lendingModule) != address(0), "BastionHook: lending module not set");
        require(lpTokenAmount > 0, "BastionHook: zero amount");
        require(collateralValue > 0, "BastionHook: zero value");

        // Register caller's collateral
        lendingModule.registerCollateral(
            msg.sender,
            address(this), // lpToken address (using hook as proxy)
            lpTokenAmount,
            collateralValue
        );
    }

    /// @notice Hook called after liquidity is removed from a pool
    /// @dev Note: Cannot enforce debt check here because sender is PositionManager
    ///      LPs must use LendingModule.withdrawCollateral() to access their collateral
    /// @param sender Address removing liquidity
    /// @param key The pool key
    /// @return selector The function selector
    /// @return hookDelta The delta to apply after removing liquidity
    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        // Cannot check debt here because sender is PositionManager, not actual LP
        // Debt enforcement happens in LendingModule.withdrawCollateral()
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
        if (!rebalancingEnabled || address(swapRouter) == address(0)) {
            emit BasketRebalanced(poolId, block.timestamp);
            return;
        }

        BasketConfig memory config = basketConfigs[poolId];
        BasketState storage state = basketStates[poolId];

        // Skip if no basket configured or no value
        if (state.totalValue == 0) {
            emit BasketRebalanced(poolId, block.timestamp);
            return;
        }

        // Calculate target amounts for each asset based on weights
        uint256 targetStETH = (state.totalValue * config.stETHWeight) / BASIS_POINTS;
        uint256 targetCbETH = (state.totalValue * config.cbETHWeight) / BASIS_POINTS;
        uint256 targetRETH = (state.totalValue * config.rETHWeight) / BASIS_POINTS;
        uint256 targetUSDe = (state.totalValue * config.USDeWeight) / BASIS_POINTS;

        // Execute rebalancing swaps for overweight assets
        _executeRebalanceSwaps(poolId, state, targetStETH, targetCbETH, targetRETH, targetUSDe);

        emit BasketRebalanced(poolId, block.timestamp);
    }

    /// @notice Execute rebalancing swaps for overweight/underweight assets
    /// @param poolId The pool ID
    /// @param state Current basket state
    /// @param targetStETH Target stETH amount
    /// @param targetCbETH Target cbETH amount
    /// @param targetRETH Target rETH amount
    /// @param targetUSDe Target USDe amount
    function _executeRebalanceSwaps(
        PoolId poolId,
        BasketState storage state,
        uint256 targetStETH,
        uint256 targetCbETH,
        uint256 targetRETH,
        uint256 targetUSDe
    ) internal {
        // Find overweight and underweight assets
        // Overweight assets need to be sold, underweight assets need to be bought

        // Check stETH
        if (state.stETHBalance > targetStETH && stETHToken != address(0)) {
            uint256 excess = state.stETHBalance - targetStETH;
            if (excess >= minSwapAmount) {
                _executeSwapToBase(poolId, stETHToken, excess);
                state.stETHBalance = targetStETH;
            }
        }

        // Check cbETH
        if (state.cbETHBalance > targetCbETH && cbETHToken != address(0)) {
            uint256 excess = state.cbETHBalance - targetCbETH;
            if (excess >= minSwapAmount) {
                _executeSwapToBase(poolId, cbETHToken, excess);
                state.cbETHBalance = targetCbETH;
            }
        }

        // Check rETH
        if (state.rETHBalance > targetRETH && rETHToken != address(0)) {
            uint256 excess = state.rETHBalance - targetRETH;
            if (excess >= minSwapAmount) {
                _executeSwapToBase(poolId, rETHToken, excess);
                state.rETHBalance = targetRETH;
            }
        }

        // Check USDe
        if (state.USDeBalance > targetUSDe && USDeToken != address(0)) {
            uint256 excess = state.USDeBalance - targetUSDe;
            if (excess >= minSwapAmount) {
                _executeSwapToBase(poolId, USDeToken, excess);
                state.USDeBalance = targetUSDe;
            }
        }

        // Now buy underweight assets with accumulated base token
        uint256 baseBalance = baseToken != address(0) ? IERC20(baseToken).balanceOf(address(this)) : 0;

        if (baseBalance > 0) {
            _buyUnderweightAssets(poolId, state, targetStETH, targetCbETH, targetRETH, targetUSDe, baseBalance);
        }
    }

    /// @notice Execute a swap from basket asset to base token
    /// @param poolId Pool ID for event
    /// @param tokenIn Token to sell
    /// @param amountIn Amount to sell
    function _executeSwapToBase(PoolId poolId, address tokenIn, uint256 amountIn) internal {
        if (baseToken == address(0) || tokenIn == address(0)) return;

        // Approve router
        IERC20(tokenIn).forceApprove(address(swapRouter), amountIn);

        // Calculate minimum output with slippage protection
        uint256 expectedOut = swapRouter.getAmountOut(tokenIn, baseToken, amountIn);
        uint256 minOut = (expectedOut * (BASIS_POINTS - maxRebalanceSlippage)) / BASIS_POINTS;

        // Execute swap
        uint256 amountOut = swapRouter.swapExactTokensForTokens(
            tokenIn,
            baseToken,
            amountIn,
            minOut,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        );

        emit RebalanceSwapExecuted(poolId, tokenIn, baseToken, amountIn, amountOut);
    }

    /// @notice Buy underweight assets with base token
    /// @param poolId Pool ID
    /// @param state Basket state
    /// @param targetStETH Target amounts
    /// @param targetCbETH Target amounts
    /// @param targetRETH Target amounts
    /// @param targetUSDe Target amounts
    /// @param baseBalance Available base token
    function _buyUnderweightAssets(
        PoolId poolId,
        BasketState storage state,
        uint256 targetStETH,
        uint256 targetCbETH,
        uint256 targetRETH,
        uint256 targetUSDe,
        uint256 baseBalance
    ) internal {
        // Calculate total deficit
        uint256 stETHDeficit = state.stETHBalance < targetStETH ? targetStETH - state.stETHBalance : 0;
        uint256 cbETHDeficit = state.cbETHBalance < targetCbETH ? targetCbETH - state.cbETHBalance : 0;
        uint256 rETHDeficit = state.rETHBalance < targetRETH ? targetRETH - state.rETHBalance : 0;
        uint256 USDeDeficit = state.USDeBalance < targetUSDe ? targetUSDe - state.USDeBalance : 0;

        uint256 totalDeficit = stETHDeficit + cbETHDeficit + rETHDeficit + USDeDeficit;
        if (totalDeficit == 0) return;

        // Buy each underweight asset proportionally
        if (stETHDeficit > 0 && stETHToken != address(0)) {
            uint256 buyAmount = (baseBalance * stETHDeficit) / totalDeficit;
            if (buyAmount >= minSwapAmount) {
                uint256 received = _executeSwapFromBase(poolId, stETHToken, buyAmount);
                state.stETHBalance += received;
            }
        }

        if (cbETHDeficit > 0 && cbETHToken != address(0)) {
            uint256 buyAmount = (baseBalance * cbETHDeficit) / totalDeficit;
            if (buyAmount >= minSwapAmount) {
                uint256 received = _executeSwapFromBase(poolId, cbETHToken, buyAmount);
                state.cbETHBalance += received;
            }
        }

        if (rETHDeficit > 0 && rETHToken != address(0)) {
            uint256 buyAmount = (baseBalance * rETHDeficit) / totalDeficit;
            if (buyAmount >= minSwapAmount) {
                uint256 received = _executeSwapFromBase(poolId, rETHToken, buyAmount);
                state.rETHBalance += received;
            }
        }

        if (USDeDeficit > 0 && USDeToken != address(0)) {
            uint256 buyAmount = (baseBalance * USDeDeficit) / totalDeficit;
            if (buyAmount >= minSwapAmount) {
                uint256 received = _executeSwapFromBase(poolId, USDeToken, buyAmount);
                state.USDeBalance += received;
            }
        }
    }

    /// @notice Execute a swap from base token to basket asset
    /// @param poolId Pool ID for event
    /// @param tokenOut Token to buy
    /// @param amountIn Amount of base token to spend
    /// @return amountOut Amount of tokenOut received
    function _executeSwapFromBase(PoolId poolId, address tokenOut, uint256 amountIn) internal returns (uint256 amountOut) {
        if (baseToken == address(0) || tokenOut == address(0)) return 0;

        // Approve router
        IERC20(baseToken).forceApprove(address(swapRouter), amountIn);

        // Calculate minimum output with slippage protection
        uint256 expectedOut = swapRouter.getAmountOut(baseToken, tokenOut, amountIn);
        uint256 minOut = (expectedOut * (BASIS_POINTS - maxRebalanceSlippage)) / BASIS_POINTS;

        // Execute swap
        amountOut = swapRouter.swapExactTokensForTokens(
            baseToken,
            tokenOut,
            amountIn,
            minOut,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        );

        emit RebalanceSwapExecuted(poolId, baseToken, tokenOut, amountIn, amountOut);
    }

    /// @notice Manually trigger rebalancing for a pool
    /// @dev Can be called by keeper or admin
    /// @param key The pool key
    function triggerRebalance(PoolKey calldata key) external {
        PoolId poolId = key.toId();
        (bool shouldRebalance,) = _shouldRebalance(poolId);
        require(shouldRebalance, "BastionHook: rebalancing not needed");
        _rebalanceBasket(poolId, key);
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
    function setBasketConfig(PoolId poolId, BasketConfig memory config) external onlyOwner {
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
    function setAssetType(Currency currency, AssetType assetType) external onlyOwner {
        assetTypes[currency] = assetType;
    }

    /// @notice Accumulate swap fees for insurance premiums
    /// @param poolId The pool ID
    /// @param params The swap parameters
    function _accumulateSwapFees(PoolId poolId, SwapParams calldata params) internal {
        // Estimate fee from swap amount (simplified - in production would track actual fees)
        uint256 swapAmount = params.amountSpecified > 0
            ? uint256(int256(params.amountSpecified))
            : uint256(int256(-params.amountSpecified));

        // Approximate fee based on current volatility tier
        uint256 estimatedFee = (swapAmount * MEDIUM_VOLATILITY_FEE) / 1000000; // Simplified

        accumulatedFees[poolId] += estimatedFee;
    }

    /// @notice Collect accumulated premiums and send to insurance tranche
    /// @dev Requires the hook to hold premium tokens (deposited by admin or received through protocol fees)
    /// @param poolId The pool ID
    function collectInsurancePremium(PoolId poolId) external {
        require(address(insuranceTranche) != address(0), "BastionHook: insurance not set");
        require(address(premiumToken) != address(0), "BastionHook: premium token not set");

        uint256 totalFees = accumulatedFees[poolId];
        require(totalFees > 0, "BastionHook: no fees to collect");

        // Calculate insurance premium
        uint256 premium = (totalFees * insuranceSplit) / BASIS_POINTS;
        uint256 remainingFees = totalFees - premium;

        // Verify hook has sufficient balance to transfer
        uint256 hookBalance = premiumToken.balanceOf(address(this));
        require(hookBalance >= premium, "BastionHook: insufficient premium token balance");

        // Reset accumulated fees
        accumulatedFees[poolId] = 0;

        // Transfer premium to insurance tranche
        if (premium > 0) {
            premiumToken.forceApprove(address(insuranceTranche), premium);
            insuranceTranche.collectPremiumWithToken(address(premiumToken), premium);
        }

        emit InsurancePremiumCollected(poolId, premium, remainingFees);
    }

    /// @notice Deposit premium tokens into the hook for insurance collection
    /// @dev Admin can deposit tokens to fund insurance premiums
    /// @param amount Amount of premium tokens to deposit
    function depositPremiumTokens(uint256 amount) external onlyOwner {
        require(address(premiumToken) != address(0), "BastionHook: premium token not set");
        require(amount > 0, "BastionHook: zero amount");
        premiumToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Keeper function to check for depegs and trigger payouts
    /// @dev Can be called by anyone (keepers, bots, etc.)
    /// @return assetsDepegged Array of depegged asset addresses
    /// @dev Only detects depegs. Payout execution must be done separately by insurance owner.
    function checkAndExecuteDepegPayouts() external view returns (address[] memory assetsDepegged) {
        require(address(insuranceTranche) != address(0), "BastionHook: insurance not set");

        // Check all configured assets for depeg
        assetsDepegged = insuranceTranche.checkAllAssets();

        return assetsDepegged;
    }

    /// @notice Set insurance tranche contract
    /// @param _insuranceTranche Insurance tranche address
    function setInsuranceTranche(address _insuranceTranche) external onlyOwner {
        require(_insuranceTranche != address(0), "BastionHook: zero address");
        insuranceTranche = InsuranceTranche(_insuranceTranche);
        emit InsuranceTrancheSet(_insuranceTranche);
    }

    /// @notice Set premium token for insurance payments
    /// @param _premiumToken Premium token address
    function setPremiumToken(address _premiumToken) external onlyOwner {
        require(_premiumToken != address(0), "BastionHook: zero address");
        premiumToken = IERC20(_premiumToken);
    }

    /// @notice Set insurance split percentage
    /// @param _insuranceSplit Insurance split in basis points (500-2000)
    function setInsuranceSplit(uint256 _insuranceSplit) external onlyOwner {
        require(_insuranceSplit >= MIN_INSURANCE_SPLIT, "BastionHook: split too low");
        require(_insuranceSplit <= MAX_INSURANCE_SPLIT, "BastionHook: split too high");

        uint256 oldSplit = insuranceSplit;
        insuranceSplit = _insuranceSplit;

        emit InsuranceSplitUpdated(oldSplit, _insuranceSplit);
    }

    /// @notice Set lending module contract
    /// @param _lendingModule Lending module address
    function setLendingModule(address _lendingModule) external onlyOwner {
        require(_lendingModule != address(0), "BastionHook: zero address");
        lendingModule = LendingModule(_lendingModule);
    }

    /// @notice Calculate collateral value from balance delta
    /// @param delta Balance delta from liquidity operation
    /// @return value Estimated collateral value
    function _calculateCollateralValue(BalanceDelta delta) internal pure returns (uint256 value) {
        // Simple calculation: sum of absolute values of both token amounts
        // In production, this would use price oracles to get USD value
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        uint256 absAmount0 = amount0 >= 0 ? uint256(int256(amount0)) : uint256(int256(-amount0));
        uint256 absAmount1 = amount1 >= 0 ? uint256(int256(amount1)) : uint256(int256(-amount1));

        value = absAmount0 + absAmount1;
    }

    /// @notice Transfer ownership
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "BastionHook: zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Set Bastion AVS task manager
    /// @param _taskManager Task manager address
    function setBastionTaskManager(address _taskManager) external onlyOwner {
        require(_taskManager != address(0), "BastionHook: zero address");
        bastionTaskManager = BastionTaskManager(_taskManager);
    }

    /// @notice Set swap router for rebalancing
    /// @param _swapRouter Swap router address
    function setSwapRouter(address _swapRouter) external onlyOwner {
        swapRouter = ISwapRouter(_swapRouter);
        emit SwapRouterSet(_swapRouter);
    }

    /// @notice Configure basket token addresses
    /// @param _stETH stETH token address
    /// @param _cbETH cbETH token address
    /// @param _rETH rETH token address
    /// @param _USDe USDe token address
    /// @param _base Base token (WETH) address
    function setBasketTokens(
        address _stETH,
        address _cbETH,
        address _rETH,
        address _USDe,
        address _base
    ) external onlyOwner {
        stETHToken = _stETH;
        cbETHToken = _cbETH;
        rETHToken = _rETH;
        USDeToken = _USDe;
        baseToken = _base;
        emit BasketTokensConfigured(_stETH, _cbETH, _rETH, _USDe, _base);
    }

    /// @notice Update rebalancing settings
    /// @param _maxSlippage Max slippage in basis points
    /// @param _minSwapAmount Minimum swap amount
    /// @param _enabled Whether rebalancing is enabled
    function setRebalancingSettings(
        uint256 _maxSlippage,
        uint256 _minSwapAmount,
        bool _enabled
    ) external onlyOwner {
        require(_maxSlippage <= 500, "BastionHook: slippage too high"); // Max 5%
        maxRebalanceSlippage = _maxSlippage;
        minSwapAmount = _minSwapAmount;
        rebalancingEnabled = _enabled;
        emit RebalancingSettingsUpdated(_maxSlippage, _minSwapAmount, _enabled);
    }

    // -----------------------------------------------
    // IAVSConsumer Implementation
    // -----------------------------------------------

    /// @notice Gets the latest validated volatility data from AVS for a pool
    /// @param poolId The pool identifier (keccak256 of pool address)
    /// @return volatilityData Struct containing volatility, timestamp, and validity
    function getLatestVolatility(bytes32 poolId)
        external
        view
        override
        returns (VolatilityData memory volatilityData)
    {
        if (address(bastionTaskManager) == address(0)) {
            revert AVSDataNotAvailable();
        }

        (uint256 volatility, uint256 timestamp, bool isValid) =
            bastionTaskManager.getLatestVolatility(poolId);

        volatilityData = VolatilityData({
            volatility: volatility,
            timestamp: timestamp,
            isValid: isValid
        });

        if (!isValid) {
            revert AVSDataNotAvailable();
        }
    }

    /// @notice Gets the latest validated depeg status from AVS for an asset
    /// @param assetAddress The address of the asset to check
    /// @return depegData Struct containing depeg status, price, deviation, timestamp, and validity
    function getLatestDepegStatus(address assetAddress)
        external
        view
        override
        returns (DepegData memory depegData)
    {
        if (address(bastionTaskManager) == address(0)) {
            revert AVSDataNotAvailable();
        }

        (bool isDepegged, uint256 currentPrice, uint256 deviation, uint256 timestamp, bool isValid) =
            bastionTaskManager.getLatestDepegStatus(assetAddress);

        depegData = DepegData({
            isDepegged: isDepegged,
            currentPrice: currentPrice,
            deviation: deviation,
            timestamp: timestamp,
            isValid: isValid
        });

        if (!isValid) {
            revert AVSDataNotAvailable();
        }
    }

    /// @notice Checks if volatility data for a pool is stale
    /// @param poolId The pool identifier
    /// @param maxAge Maximum acceptable age in seconds
    /// @return isStale True if data is older than maxAge or unavailable
    function isVolatilityDataStale(bytes32 poolId, uint256 maxAge)
        external
        view
        override
        returns (bool isStale)
    {
        if (address(bastionTaskManager) == address(0)) {
            return true;
        }

        (,uint256 timestamp, bool isValid) = bastionTaskManager.getLatestVolatility(poolId);

        if (!isValid) {
            return true;
        }

        return (block.timestamp - timestamp) > maxAge;
    }

    /// @notice Checks if depeg status data for an asset is stale
    /// @param assetAddress The address of the asset
    /// @param maxAge Maximum acceptable age in seconds
    /// @return isStale True if data is older than maxAge or unavailable
    function isDepegDataStale(address assetAddress, uint256 maxAge)
        external
        view
        override
        returns (bool isStale)
    {
        if (address(bastionTaskManager) == address(0)) {
            return true;
        }

        (,,,uint256 timestamp, bool isValid) = bastionTaskManager.getLatestDepegStatus(assetAddress);

        if (!isValid) {
            return true;
        }

        return (block.timestamp - timestamp) > maxAge;
    }
}
