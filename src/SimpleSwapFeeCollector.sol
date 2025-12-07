// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Extended ERC20 interface with decimals
interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @title SimpleSwapFeeCollector
 * @notice Simplified swap contract that collects fees for insurance pool
 * @dev Alternative to Uniswap v4 hooks for testnet demonstration
 */
contract SimpleSwapFeeCollector is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Insurance tranche contract
    address public insuranceTranche;

    /// @notice Fee percentage (in basis points, 20 = 0.2%)
    uint256 public constant FEE_BPS = 20; // 0.2% fee

    /// @notice Basis points constant
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Owner address
    address public owner;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event FeeSentToInsurance(address indexed token, uint256 amount);

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "SimpleSwap: not owner");
        _;
    }

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    constructor(address _insuranceTranche) {
        require(_insuranceTranche != address(0), "SimpleSwap: zero address");
        insuranceTranche = _insuranceTranche;
        owner = msg.sender;
    }

    // -----------------------------------------------
    // Swap Functions
    // -----------------------------------------------

    /// @notice Execute a swap with fee collection and decimal conversion
    /// @param tokenIn Token to swap from
    /// @param tokenOut Token to swap to
    /// @param amountIn Amount of tokenIn to swap
    /// @return amountOut Amount of tokenOut received (after fees)
    function swap(address tokenIn, address tokenOut, uint256 amountIn)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(tokenIn != address(0) && tokenOut != address(0), "SimpleSwap: zero address");
        require(amountIn > 0, "SimpleSwap: zero amount");
        require(tokenIn != tokenOut, "SimpleSwap: same token");

        // Get token decimals
        uint8 decimalsIn = IERC20Extended(tokenIn).decimals();
        uint8 decimalsOut = IERC20Extended(tokenOut).decimals();

        // Calculate fee in tokenIn decimals (0.2%)
        uint256 fee = (amountIn * FEE_BPS) / BASIS_POINTS;
        uint256 amountAfterFee = amountIn - fee;

        // Convert to tokenOut decimals (1:1 price ratio)
        if (decimalsIn > decimalsOut) {
            // Example: stETH (18) -> USDC (6) = divide by 10^12
            amountOut = amountAfterFee / (10 ** (decimalsIn - decimalsOut));
        } else if (decimalsOut > decimalsIn) {
            // Example: USDC (6) -> stETH (18) = multiply by 10^12
            amountOut = amountAfterFee * (10 ** (decimalsOut - decimalsIn));
        } else {
            // Same decimals, no conversion needed
            amountOut = amountAfterFee;
        }

        // Transfer tokenIn from user
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Transfer 80% of fee to insurance (in tokenIn)
        uint256 insuranceFee = (fee * 8000) / BASIS_POINTS; // 80% of fee
        if (insuranceFee > 0) {
            // Approve and send to insurance
            IERC20(tokenIn).approve(insuranceTranche, insuranceFee);

            // Call collectPremiumWithToken on InsuranceTranche
            try IInsuranceTranche(insuranceTranche).collectPremiumWithToken(tokenIn, insuranceFee) {
                emit FeeSentToInsurance(tokenIn, insuranceFee);
            } catch {
                // If insurance collection fails, keep fee in contract for manual transfer
                emit FeeSentToInsurance(tokenIn, 0);
            }
        }

        // Transfer tokenOut to user with correct decimal amount
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);

        return amountOut;
    }

    /// @notice Get quote for a swap with decimal conversion
    /// @param tokenIn Token to swap from
    /// @param tokenOut Token to swap to
    /// @param amountIn Amount to swap
    /// @return amountOut Amount out after fees (in tokenOut decimals)
    /// @return fee Fee amount (in tokenIn decimals)
    function getQuote(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut, uint256 fee)
    {
        require(tokenIn != address(0) && tokenOut != address(0), "SimpleSwap: zero address");
        require(tokenIn != tokenOut, "SimpleSwap: same token");

        // Get token decimals
        uint8 decimalsIn = IERC20Extended(tokenIn).decimals();
        uint8 decimalsOut = IERC20Extended(tokenOut).decimals();

        // Calculate fee in tokenIn decimals
        fee = (amountIn * FEE_BPS) / BASIS_POINTS;
        uint256 amountAfterFee = amountIn - fee;

        // Convert to tokenOut decimals
        if (decimalsIn > decimalsOut) {
            amountOut = amountAfterFee / (10 ** (decimalsIn - decimalsOut));
        } else if (decimalsOut > decimalsIn) {
            amountOut = amountAfterFee * (10 ** (decimalsOut - decimalsIn));
        } else {
            amountOut = amountAfterFee;
        }

        return (amountOut, fee);
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Update insurance tranche address
    /// @param _insuranceTranche New insurance tranche address
    function setInsuranceTranche(address _insuranceTranche) external onlyOwner {
        require(_insuranceTranche != address(0), "SimpleSwap: zero address");
        insuranceTranche = _insuranceTranche;
    }

    /// @notice Emergency withdraw (owner only)
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner, amount);
    }

    /// @notice Transfer ownership
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SimpleSwap: zero address");
        owner = newOwner;
    }
}

// Minimal interface for InsuranceTranche
interface IInsuranceTranche {
    function collectPremiumWithToken(address token, uint256 amount) external;
}
