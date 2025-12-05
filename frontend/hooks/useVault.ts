import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useEffect, useState } from "react";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { BastionVaultABI, ERC20ABI } from "@/lib/contracts/abis";

export function useVault() {
  const { address } = useAccount();
  const { writeContract, data: hash, isPending } = useWriteContract();
  const [needsApproval, setNeedsApproval] = useState(false);

  // Get the underlying asset address from the vault
  const { data: assetAddress } = useReadContract({
    address: CONTRACTS.BastionVault,
    abi: BastionVaultABI,
    functionName: "asset",
  });

  // Read token symbol
  const { data: tokenSymbol } = useReadContract({
    address: assetAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: "symbol",
    query: {
      enabled: !!assetAddress,
    },
  });

  // Read user's token balance
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: assetAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!assetAddress,
    },
  });

  // Read user's allowance (returns BigInt)
  const { data: allowanceRaw, refetch: refetchAllowance } = useReadContract({
    address: assetAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: "allowance",
    args: address ? [address, CONTRACTS.BastionVault] : undefined,
    query: {
      enabled: !!address && !!assetAddress,
    },
  });

  // Read total assets in vault
  const { data: totalAssets, refetch: refetchTotalAssets } = useReadContract({
    address: CONTRACTS.BastionVault,
    abi: BastionVaultABI,
    functionName: "totalAssets",
  });

  // Read total shares supply
  const { data: totalSupply, refetch: refetchTotalSupply } = useReadContract({
    address: CONTRACTS.BastionVault,
    abi: BastionVaultABI,
    functionName: "totalSupply",
  });

  // Read user's share balance
  const { data: userShares, refetch: refetchUserShares } = useReadContract({
    address: CONTRACTS.BastionVault,
    abi: BastionVaultABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Read max redeemable shares for user
  const { data: maxRedeemableShares, refetch: refetchMaxRedeem } = useReadContract({
    address: CONTRACTS.BastionVault,
    abi: BastionVaultABI,
    functionName: "maxRedeem",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Convert user shares to assets
  const { data: userAssetsRaw, refetch: refetchUserAssets } = useReadContract({
    address: CONTRACTS.BastionVault,
    abi: BastionVaultABI,
    functionName: "convertToAssets",
    args: userShares ? [userShares] : undefined,
    query: {
      enabled: !!userShares,
    },
  });

  // Calculate share price (1 share = X assets)
  const sharePrice = totalSupply && totalAssets && totalSupply > 0n
    ? Number(formatEther(totalAssets)) / Number(formatEther(totalSupply))
    : 1.0;

  // Wait for transaction confirmation
  const { isLoading: isConfirming, isSuccess, error: txError } = useWaitForTransactionReceipt({
    hash,
  });

  // Log transaction states
  useEffect(() => {
    if (hash) {
      console.log("Transaction submitted:", hash);
    }
    if (isConfirming) {
      console.log("Waiting for confirmation...");
    }
    if (isSuccess) {
      console.log("Transaction confirmed successfully!");
    }
    if (txError) {
      console.error("Transaction error:", txError);
    }
  }, [hash, isConfirming, isSuccess, txError]);

  // Refetch all data when transaction succeeds
  useEffect(() => {
    if (isSuccess) {
      console.log("Refetching vault data after successful transaction...");
      refetchTotalAssets();
      refetchTotalSupply();
      refetchUserShares();
      refetchMaxRedeem();
      refetchUserAssets();
      refetchTokenBalance();
      refetchAllowance();
      setNeedsApproval(false);
    }
  }, [isSuccess, refetchTotalAssets, refetchTotalSupply, refetchUserShares, refetchMaxRedeem, refetchUserAssets, refetchTokenBalance, refetchAllowance]);

  // Approve function
  const approve = async (amount: string) => {
    if (!address) throw new Error("Wallet not connected");
    if (!assetAddress) throw new Error("Asset address not found");

    const amountWei = parseEther(amount);

    writeContract({
      address: assetAddress as `0x${string}`,
      abi: ERC20ABI,
      functionName: "approve",
      args: [CONTRACTS.BastionVault, amountWei],
    });
  };

  // Combined approve and deposit function
  const depositWithApproval = async (amount: string) => {
    if (!address) throw new Error("Wallet not connected");

    // Use the asset address from the hook or fallback to the known stETH address
    const tokenAddress = assetAddress || CONTRACTS.stETH;
    if (!tokenAddress) throw new Error("Asset address not loaded. Please wait...");

    const amountWei = parseEther(amount);

    console.log("Deposit attempt:", {
      amount,
      amountWei: amountWei.toString(),
      tokenAddress,
      vaultAddress: CONTRACTS.BastionVault,
      currentAllowance: allowanceRaw ? allowanceRaw.toString() : "0",
      needsApproval: !allowanceRaw || allowanceRaw < amountWei
    });

    // Check if approval is needed (compare BigInt values)
    if (!allowanceRaw || allowanceRaw < amountWei) {
      // First approve
      console.log("Approving token spend...");
      setNeedsApproval(true);
      writeContract({
        address: tokenAddress as `0x${string}`,
        abi: ERC20ABI,
        functionName: "approve",
        args: [CONTRACTS.BastionVault, amountWei],
      });
      return "approval";
    }

    // If already approved, proceed with deposit
    console.log("Depositing to vault...");
    writeContract({
      address: CONTRACTS.BastionVault,
      abi: BastionVaultABI,
      functionName: "deposit",
      args: [amountWei, address],
    });
    return "deposit";
  };

  // Withdraw (redeem) function
  const withdraw = async (shares: string) => {
    if (!address) throw new Error("Wallet not connected");

    const sharesWei = parseEther(shares);

    writeContract({
      address: CONTRACTS.BastionVault,
      abi: BastionVaultABI,
      functionName: "redeem",
      args: [sharesWei, address, address],
    });
  };

  // Log current vault state for debugging
  useEffect(() => {
    console.log("Vault state:", {
      totalAssets: totalAssets ? formatEther(totalAssets) : "0",
      totalSupply: totalSupply ? formatEther(totalSupply) : "0",
      userShares: userShares ? formatEther(userShares) : "0",
      userAssets: userAssetsRaw ? formatEther(userAssetsRaw) : "0",
      tokenBalance: tokenBalance ? formatEther(tokenBalance) : "0",
      allowance: allowanceRaw ? formatEther(allowanceRaw) : "0",
      assetAddress,
      vaultAddress: CONTRACTS.BastionVault
    });
  }, [totalAssets, totalSupply, userShares, userAssetsRaw, tokenBalance, allowanceRaw, assetAddress]);

  return {
    // Vault stats
    totalAssets: totalAssets ? Number(formatEther(totalAssets)) : 0,
    totalShares: totalSupply ? Number(formatEther(totalSupply)) : 0,
    sharePrice,

    // User stats
    userShares: userShares ? Number(formatEther(userShares)) : 0,
    userAssets: userAssetsRaw ? Number(formatEther(userAssetsRaw)) : 0,
    maxWithdrawShares: maxRedeemableShares ? Number(formatEther(maxRedeemableShares)) : 0,

    // Token info
    assetAddress: assetAddress as `0x${string}` | undefined,
    tokenSymbol: tokenSymbol as string | undefined,
    tokenBalance: tokenBalance ? Number(formatEther(tokenBalance)) : 0,
    allowance: allowanceRaw ? Number(formatEther(allowanceRaw)) : 0,
    needsApproval,

    // Actions
    approve,
    deposit: depositWithApproval,
    withdraw,

    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    hash,
  };
}
