// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {Ownable2Step} from "./base/Ownable2Step.sol";

/// @title BasketSwapper
/// @notice Handles DEX swaps for basket allocation and rebalancing
/// @dev Can be used by BastionVault and BastionHook for token swaps
contract BasketSwapper is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    /// @notice Configuration for a swap route
    struct SwapRoute {
        address router;         // DEX router address
        bool isActive;          // Whether route is active
        uint256 maxSlippage;    // Max slippage in basis points
    }

    // -----------------------------------------------
    // Constants
    // -----------------------------------------------

    /// @notice Basis points constant
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Default max slippage (1%)
    uint256 public constant DEFAULT_MAX_SLIPPAGE = 100;

    /// @notice Minimum slippage allowed (0.1%)
    uint256 public constant MIN_SLIPPAGE = 10;

    /// @notice Maximum slippage allowed (5%)
    uint256 public constant MAX_SLIPPAGE = 500;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Default DEX router
    ISwapRouter public defaultRouter;

    /// @notice Mapping of token pair to preferred route
    /// @dev key = keccak256(abi.encodePacked(tokenIn, tokenOut))
    mapping(bytes32 => SwapRoute) public swapRoutes;

    /// @notice Addresses authorized to execute swaps
    mapping(address => bool) public authorizedSwappers;

    /// @notice Default swap deadline extension (5 minutes)
    uint256 public defaultDeadlineExtension = 5 minutes;

    /// @notice Emergency pause
    bool public paused;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when a swap is executed
    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient
    );

    /// @notice Emitted when default router is updated
    event DefaultRouterUpdated(address indexed oldRouter, address indexed newRouter);

    /// @notice Emitted when a swap route is configured
    event SwapRouteConfigured(
        address indexed tokenIn,
        address indexed tokenOut,
        address router,
        uint256 maxSlippage
    );

    /// @notice Emitted when authorized swapper is updated
    event AuthorizedSwapperUpdated(address indexed swapper, bool authorized);

    /// @notice Emitted when pause state changes
    event PauseStateChanged(bool paused);

    // -----------------------------------------------
    // Errors
    // -----------------------------------------------

    error Unauthorized();
    error Paused();
    error InvalidRouter();
    error InvalidSlippage();
    error SwapFailed();
    error InsufficientOutput(uint256 expected, uint256 actual);

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    modifier onlyAuthorized() {
        if (!authorizedSwappers[msg.sender] && msg.sender != owner()) {
            revert Unauthorized();
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize the BasketSwapper
    /// @param _defaultRouter Default DEX router address
    constructor(address _defaultRouter) Ownable2Step(msg.sender) {
        if (_defaultRouter != address(0)) {
            defaultRouter = ISwapRouter(_defaultRouter);
        }
    }

    // -----------------------------------------------
    // Swap Functions
    // -----------------------------------------------

    /// @notice Execute a swap with automatic route selection
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param amountIn Amount of input tokens
    /// @param minAmountOut Minimum output amount (0 = use default slippage)
    /// @param recipient Address to receive output tokens
    /// @return amountOut Actual output amount
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external onlyAuthorized whenNotPaused nonReentrant returns (uint256 amountOut) {
        // Get the best route for this pair
        (ISwapRouter router, uint256 maxSlippage) = _getSwapRoute(tokenIn, tokenOut);

        if (address(router) == address(0)) {
            revert InvalidRouter();
        }

        // Calculate minimum output if not specified
        if (minAmountOut == 0) {
            uint256 expectedOut = router.getAmountOut(tokenIn, tokenOut, amountIn);
            minAmountOut = (expectedOut * (BASIS_POINTS - maxSlippage)) / BASIS_POINTS;
        }

        // Transfer tokens from caller
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve router
        IERC20(tokenIn).forceApprove(address(router), amountIn);

        // Execute swap
        uint256 deadline = block.timestamp + defaultDeadlineExtension;
        amountOut = router.swapExactTokensForTokens(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            recipient,
            deadline
        );

        // Verify output
        if (amountOut < minAmountOut) {
            revert InsufficientOutput(minAmountOut, amountOut);
        }

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, recipient);
    }

    /// @notice Execute multiple swaps in a single transaction
    /// @param tokensIn Array of input tokens
    /// @param tokensOut Array of output tokens
    /// @param amountsIn Array of input amounts
    /// @param recipient Address to receive all output tokens
    /// @return amountsOut Array of actual output amounts
    function batchSwap(
        address[] calldata tokensIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsIn,
        address recipient
    ) external onlyAuthorized whenNotPaused nonReentrant returns (uint256[] memory amountsOut) {
        require(
            tokensIn.length == tokensOut.length && tokensIn.length == amountsIn.length,
            "BasketSwapper: array length mismatch"
        );

        amountsOut = new uint256[](tokensIn.length);

        for (uint256 i = 0; i < tokensIn.length; i++) {
            (ISwapRouter router, uint256 maxSlippage) = _getSwapRoute(tokensIn[i], tokensOut[i]);

            if (address(router) == address(0)) continue;

            // Transfer tokens from caller
            IERC20(tokensIn[i]).safeTransferFrom(msg.sender, address(this), amountsIn[i]);

            // Calculate minimum output
            uint256 expectedOut = router.getAmountOut(tokensIn[i], tokensOut[i], amountsIn[i]);
            uint256 minAmountOut = (expectedOut * (BASIS_POINTS - maxSlippage)) / BASIS_POINTS;

            // Approve and swap
            IERC20(tokensIn[i]).forceApprove(address(router), amountsIn[i]);

            uint256 deadline = block.timestamp + defaultDeadlineExtension;
            amountsOut[i] = router.swapExactTokensForTokens(
                tokensIn[i],
                tokensOut[i],
                amountsIn[i],
                minAmountOut,
                recipient,
                deadline
            );

            emit SwapExecuted(tokensIn[i], tokensOut[i], amountsIn[i], amountsOut[i], recipient);
        }
    }

    /// @notice Get quote for a swap
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param amountIn Input amount
    /// @return amountOut Expected output amount
    /// @return router Router that would be used
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut, address router) {
        (ISwapRouter swapRouter,) = _getSwapRoute(tokenIn, tokenOut);
        router = address(swapRouter);

        if (router != address(0)) {
            amountOut = swapRouter.getAmountOut(tokenIn, tokenOut, amountIn);
        }
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Set the default DEX router
    /// @param _router Router address
    function setDefaultRouter(address _router) external onlyOwner {
        address oldRouter = address(defaultRouter);
        defaultRouter = ISwapRouter(_router);
        emit DefaultRouterUpdated(oldRouter, _router);
    }

    /// @notice Configure a swap route for a token pair
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param router Router address (address(0) to use default)
    /// @param maxSlippage Maximum slippage in basis points
    function configureSwapRoute(
        address tokenIn,
        address tokenOut,
        address router,
        uint256 maxSlippage
    ) external onlyOwner {
        if (maxSlippage < MIN_SLIPPAGE || maxSlippage > MAX_SLIPPAGE) {
            revert InvalidSlippage();
        }

        bytes32 pairKey = _getPairKey(tokenIn, tokenOut);

        swapRoutes[pairKey] = SwapRoute({
            router: router,
            isActive: router != address(0),
            maxSlippage: maxSlippage
        });

        emit SwapRouteConfigured(tokenIn, tokenOut, router, maxSlippage);
    }

    /// @notice Set authorized swapper status
    /// @param swapper Swapper address
    /// @param authorized Whether authorized
    function setAuthorizedSwapper(address swapper, bool authorized) external onlyOwner {
        authorizedSwappers[swapper] = authorized;
        emit AuthorizedSwapperUpdated(swapper, authorized);
    }

    /// @notice Set default deadline extension
    /// @param extension Deadline extension in seconds
    function setDefaultDeadlineExtension(uint256 extension) external onlyOwner {
        require(extension >= 1 minutes && extension <= 30 minutes, "BasketSwapper: invalid extension");
        defaultDeadlineExtension = extension;
    }

    /// @notice Emergency pause
    /// @param _paused Pause state
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseStateChanged(_paused);
    }

    /// @notice Rescue stuck tokens
    /// @param token Token address
    /// @param amount Amount to rescue
    /// @param recipient Recipient address
    function rescueTokens(address token, uint256 amount, address recipient) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

    // -----------------------------------------------
    // Internal Functions
    // -----------------------------------------------

    /// @notice Get the swap route for a token pair
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @return router Router to use
    /// @return maxSlippage Maximum slippage
    function _getSwapRoute(address tokenIn, address tokenOut)
        internal
        view
        returns (ISwapRouter router, uint256 maxSlippage)
    {
        bytes32 pairKey = _getPairKey(tokenIn, tokenOut);
        SwapRoute memory route = swapRoutes[pairKey];

        if (route.isActive && route.router != address(0)) {
            return (ISwapRouter(route.router), route.maxSlippage);
        }

        // Fall back to default router
        return (defaultRouter, DEFAULT_MAX_SLIPPAGE);
    }

    /// @notice Generate a unique key for a token pair
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @return key Unique pair key
    function _getPairKey(address tokenIn, address tokenOut) internal pure returns (bytes32 key) {
        return keccak256(abi.encodePacked(tokenIn, tokenOut));
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Check if an address is authorized to swap
    /// @param swapper Address to check
    /// @return isAuthorized Whether authorized
    function isAuthorizedSwapper(address swapper) external view returns (bool isAuthorized) {
        return authorizedSwappers[swapper] || swapper == owner();
    }

    /// @notice Get swap route details for a pair
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @return router Router address
    /// @return isActive Whether active
    /// @return maxSlippage Max slippage
    function getSwapRouteDetails(address tokenIn, address tokenOut)
        external
        view
        returns (address router, bool isActive, uint256 maxSlippage)
    {
        bytes32 pairKey = _getPairKey(tokenIn, tokenOut);
        SwapRoute memory route = swapRoutes[pairKey];
        return (route.router, route.isActive, route.maxSlippage);
    }
}
