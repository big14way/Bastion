// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ISwapRouter
/// @notice Interface for DEX swap routers (compatible with Uniswap V2/V3 style)
interface ISwapRouter {
    /// @notice Swap exact input amount for minimum output amount
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param amountIn Exact amount of input tokens
    /// @param amountOutMin Minimum acceptable output amount
    /// @param recipient Address to receive output tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amountOut Actual output amount received
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice Swap minimum input for exact output amount
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param amountOut Exact amount of output tokens desired
    /// @param amountInMax Maximum acceptable input amount
    /// @param recipient Address to receive output tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amountIn Actual input amount spent
    function swapTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountIn);

    /// @notice Get quote for swap
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param amountIn Input amount
    /// @return amountOut Expected output amount
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);
}
