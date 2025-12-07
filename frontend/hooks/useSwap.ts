import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatEther, formatUnits } from "viem";
// import { parseEther } from "viem";
import { useEffect, useState } from "react";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { SimpleSwapABI, ERC20ABI } from "@/lib/contracts/abis";

export function useSwap() {
  const { address } = useAccount();
  const { writeContract, data: hash, isPending } = useWriteContract();
  const [needsApproval, setNeedsApproval] = useState(false);
  const [selectedTokenIn, setSelectedTokenIn] = useState<`0x${string}`>(CONTRACTS.stETH);
  const [selectedTokenOut, setSelectedTokenOut] = useState<`0x${string}`>(CONTRACTS.USDC);

  // Read token balances
  const { data: stETHBalance, refetch: refetchStETH } = useReadContract({
    address: CONTRACTS.stETH,
    abi: ERC20ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  const { data: usdcBalance, refetch: refetchUSDC } = useReadContract({
    address: CONTRACTS.USDC,
    abi: ERC20ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Read token symbols
  const { data: stETHSymbol } = useReadContract({
    address: CONTRACTS.stETH,
    abi: ERC20ABI,
    functionName: "symbol",
  });

  const { data: usdcSymbol } = useReadContract({
    address: CONTRACTS.USDC,
    abi: ERC20ABI,
    functionName: "symbol",
  });

  // Read allowance for selected token
  const { data: allowanceRaw, refetch: refetchAllowance } = useReadContract({
    address: selectedTokenIn,
    abi: ERC20ABI,
    functionName: "allowance",
    args: address ? [address, CONTRACTS.SimpleSwap] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Read fee from contract
  const { data: feeBps } = useReadContract({
    address: CONTRACTS.SimpleSwap,
    abi: SimpleSwapABI,
    functionName: "FEE_BPS",
  });

  // Wait for transaction confirmation
  const { isLoading: isConfirming, isSuccess, error: txError } = useWaitForTransactionReceipt({
    hash,
  });

  // Log transaction states
  useEffect(() => {
    if (hash) {
      console.log("Swap transaction submitted:", hash);
    }
    if (isConfirming) {
      console.log("Waiting for swap confirmation...");
    }
    if (isSuccess) {
      console.log("Swap confirmed successfully!");
    }
    if (txError) {
      console.error("Swap transaction error:", txError);
    }
  }, [hash, isConfirming, isSuccess, txError]);

  // Refetch balances when transaction succeeds
  useEffect(() => {
    if (isSuccess) {
      console.log("Refetching balances after successful swap...");
      // Immediate refetch
      refetchStETH();
      refetchUSDC();
      refetchAllowance();
      setNeedsApproval(false);

      // Delayed refetch
      setTimeout(() => {
        console.log("Delayed refetch for blockchain state update...");
        refetchStETH();
        refetchUSDC();
        refetchAllowance();
      }, 2000);

      // Final refetch
      setTimeout(() => {
        console.log("Final refetch...");
        refetchStETH();
        refetchUSDC();
        refetchAllowance();
      }, 5000);
    }
  }, [isSuccess, refetchStETH, refetchUSDC, refetchAllowance]);

  // Get quote for swap with decimal conversion
  const getQuote = async (amountIn: string): Promise<{ amountOut: number; fee: number } | null> => {
    if (!amountIn || parseFloat(amountIn) <= 0) return null;

    try {
      // Determine decimals based on token
      const decimalsIn = selectedTokenIn === CONTRACTS.USDC ? 6 : 18;
      const decimalsOut = selectedTokenOut === CONTRACTS.USDC ? 6 : 18;
      const amountWei = parseUnits(amountIn, decimalsIn);

      // Calculate fee in tokenIn decimals (0.2%)
      const fee = (amountWei * 20n) / 10000n;
      const amountAfterFee = amountWei - fee;

      // Convert to tokenOut decimals (1:1 price ratio)
      let amountOut: bigint;
      if (decimalsIn > decimalsOut) {
        // Example: stETH (18) -> USDC (6) = divide by 10^12
        amountOut = amountAfterFee / (10n ** BigInt(decimalsIn - decimalsOut));
      } else if (decimalsOut > decimalsIn) {
        // Example: USDC (6) -> stETH (18) = multiply by 10^12
        amountOut = amountAfterFee * (10n ** BigInt(decimalsOut - decimalsIn));
      } else {
        // Same decimals, no conversion needed
        amountOut = amountAfterFee;
      }

      return {
        amountOut: Number(formatUnits(amountOut, decimalsOut)),
        fee: Number(formatUnits(fee, decimalsIn)),
      };
    } catch (error) {
      console.error("Error getting quote:", error);
      return null;
    }
  };

  // Approve token for swap
  const approve = async (amount: string) => {
    if (!address) throw new Error("Wallet not connected");

    const decimals = selectedTokenIn === CONTRACTS.USDC ? 6 : 18;
    const amountWei = parseUnits(amount, decimals);

    writeContract({
      address: selectedTokenIn,
      abi: ERC20ABI,
      functionName: "approve",
      args: [CONTRACTS.SimpleSwap, amountWei],
    });
  };

  // Execute swap with approval check
  const swap = async (amountIn: string) => {
    if (!address) throw new Error("Wallet not connected");

    const decimals = selectedTokenIn === CONTRACTS.USDC ? 6 : 18;
    const amountWei = parseUnits(amountIn, decimals);

    console.log("Swap attempt:", {
      amountIn,
      amountWei: amountWei.toString(),
      tokenIn: selectedTokenIn,
      tokenOut: selectedTokenOut,
      currentAllowance: allowanceRaw ? allowanceRaw.toString() : "0",
      needsApproval: !allowanceRaw || allowanceRaw < amountWei
    });

    // Check if approval is needed
    if (!allowanceRaw || allowanceRaw < amountWei) {
      console.log("Approving token spend...");
      setNeedsApproval(true);
      writeContract({
        address: selectedTokenIn,
        abi: ERC20ABI,
        functionName: "approve",
        args: [CONTRACTS.SimpleSwap, amountWei],
      });
      return "approval";
    }

    // If already approved, proceed with swap
    console.log("Executing swap...");
    writeContract({
      address: CONTRACTS.SimpleSwap,
      abi: SimpleSwapABI,
      functionName: "swap",
      args: [selectedTokenIn, selectedTokenOut, amountWei],
    });
    return "swap";
  };

  // Flip tokens (reverse swap direction)
  const flipTokens = () => {
    const temp = selectedTokenIn;
    setSelectedTokenIn(selectedTokenOut);
    setSelectedTokenOut(temp);
  };

  // Get balance for selected token
  const getTokenBalance = (tokenAddress: `0x${string}`) => {
    if (tokenAddress === CONTRACTS.stETH) {
      return stETHBalance ? Number(formatEther(stETHBalance)) : 0;
    } else if (tokenAddress === CONTRACTS.USDC) {
      return usdcBalance ? Number(formatUnits(usdcBalance, 6)) : 0;
    }
    return 0;
  };

  // Get symbol for token
  const getTokenSymbol = (tokenAddress: `0x${string}`) => {
    if (tokenAddress === CONTRACTS.stETH) {
      return (stETHSymbol as string) || "stETH";
    } else if (tokenAddress === CONTRACTS.USDC) {
      return (usdcSymbol as string) || "USDC";
    }
    return "???";
  };

  return {
    // Token selection
    selectedTokenIn,
    selectedTokenOut,
    setSelectedTokenIn,
    setSelectedTokenOut,
    flipTokens,

    // Balances
    stETHBalance: stETHBalance ? Number(formatEther(stETHBalance)) : 0,
    usdcBalance: usdcBalance ? Number(formatUnits(usdcBalance, 6)) : 0,
    getTokenBalance,
    getTokenSymbol,

    // Fee info
    feePercentage: feeBps ? Number(feeBps) / 100 : 0.2,
    insuranceFeePercentage: feeBps ? (Number(feeBps) * 0.8) / 100 : 0.16,

    // Allowance
    allowance: allowanceRaw ? Number(formatEther(allowanceRaw)) : 0,
    needsApproval,

    // Actions
    getQuote,
    approve,
    swap,

    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    hash,
  };
}
