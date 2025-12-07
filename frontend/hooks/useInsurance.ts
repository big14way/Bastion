import { useReadContracts, useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { InsuranceTrancheABI, ERC20ABI } from "@/lib/contracts/abis";
import { formatEther } from "viem";
import { useEffect } from "react";

export function useInsurance() {
  const { address } = useAccount();

  // Fetch all insurance contract data
  const { data, isError, isLoading, refetch } = useReadContracts({
    contracts: [
      // Pool data
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "insurancePoolBalance",
      },
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "totalLPShares",
      },
      // Payout history
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "getPayoutHistoryCount",
      },
      // Configured assets
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "getConfiguredAssetCount",
      },
      // Collected premium tokens
      {
        address: CONTRACTS.stETH,
        abi: ERC20ABI,
        functionName: "balanceOf",
        args: [CONTRACTS.InsuranceTranche],
      },
      {
        address: CONTRACTS.USDC,
        abi: ERC20ABI,
        functionName: "balanceOf",
        args: [CONTRACTS.InsuranceTranche],
      },
      // User position (if connected)
      ...(address
        ? [
            {
              address: CONTRACTS.InsuranceTranche,
              abi: InsuranceTrancheABI,
              functionName: "lpPositions",
              args: [address],
            },
          ]
        : []),
    ],
  });

  // Parse the basic data
  const poolBalance =
    data?.[0]?.status === "success"
      ? Number(formatEther(data[0].result as bigint))
      : 0;

  const totalLPShares =
    data?.[1]?.status === "success"
      ? Number(formatEther(data[1].result as bigint))
      : 0;

  const payoutCount =
    data?.[2]?.status === "success" ? Number(data[2].result) : 0;

  const assetCount =
    data?.[3]?.status === "success" ? Number(data[3].result) : 0;

  const stETHBalance =
    data?.[4]?.status === "success"
      ? Number(formatEther(data[4].result as bigint))
      : 0;

  const usdcBalance =
    data?.[5]?.status === "success"
      ? Number(formatEther(data[5].result as bigint))
      : 0;

  // Parse user position if connected
  const userPosition =
    address && data?.[6]?.status === "success"
      ? (data[6].result as any)
      : null;

  const userShares = userPosition
    ? Number(formatEther(userPosition[0] || 0n))
    : 0;

  const userIsActive = userPosition ? userPosition[2] === true : false;

  // Calculate coverage ratio (pool balance per share)
  const coverageRatio =
    totalLPShares > 0 ? (poolBalance / totalLPShares) * 100 : 0;

  // Calculate user's share of the pool
  const userCoverage =
    userShares > 0 && poolBalance > 0 && totalLPShares > 0
      ? (userShares / totalLPShares) * poolBalance
      : 0;

  // Fetch configured assets details
  const fetchAssetDetails = async () => {
    if (assetCount === 0) return [];

    const assetPromises = [];
    for (let i = 0; i < Math.min(assetCount, 10); i++) {
      // Limit to 10 assets for now
      assetPromises.push(
        // This would be done with wagmi but keeping it simple for now
        Promise.resolve({
          name: i === 0 ? "stETH" : i === 1 ? "cbETH" : i === 2 ? "rETH" : "USDe",
          address: "0x" + "0".repeat(38) + i.toString().padStart(2, "0"),
          isActive: false,
        })
      );
    }
    return Promise.all(assetPromises);
  };

  // Fetch payout history
  const fetchPayoutHistory = async () => {
    if (payoutCount === 0) return [];

    const payoutPromises = [];
    for (let i = 0; i < Math.min(payoutCount, 5); i++) {
      // Limit to 5 most recent
      payoutPromises.push(
        // This would be done with wagmi but keeping it simple for now
        Promise.resolve({
          asset: "Asset",
          payout: 0,
          timestamp: Date.now(),
          deviation: 0,
        })
      );
    }
    return Promise.all(payoutPromises);
  };

  // Write contract for claiming payouts
  const { writeContract, data: claimTxHash, isPending: isClaimPending } = useWriteContract();

  const { isLoading: isClaimConfirming, isSuccess: isClaimConfirmed } =
    useWaitForTransactionReceipt({ hash: claimTxHash });

  // Refetch after claim
  useEffect(() => {
    if (isClaimConfirmed) {
      refetch();

      // Delayed refetch
      setTimeout(() => refetch(), 2000);
      setTimeout(() => refetch(), 5000);
    }
  }, [isClaimConfirmed, refetch]);

  // Claim payout function
  const claimPayout = async (payoutIndex: number) => {
    if (!address) throw new Error("Wallet not connected");

    writeContract({
      address: CONTRACTS.InsuranceTranche,
      abi: InsuranceTrancheABI,
      functionName: "claimPayout",
      args: [BigInt(payoutIndex)],
    });
  };

  // Get claimable amount for a payout
  const getClaimableAmount = async (payoutIndex: number) => {
    if (!address) return 0;

    // This would use readContract but simplified for now
    return 0;
  };

  return {
    // Pool stats
    poolBalance,
    totalLPShares,
    coverageRatio,
    stETHBalance,
    usdcBalance,

    // User stats
    userShares,
    userCoverage,
    hasInsurance: userIsActive,

    // History stats
    payoutCount,
    assetCount,

    // Fetchers for detailed data
    fetchAssetDetails,
    fetchPayoutHistory,

    // Claim functions
    claimPayout,
    getClaimableAmount,
    isClaimPending,
    isClaimConfirming,
    isClaimConfirmed,
    claimTxHash,

    // Loading states
    isLoading,
    isError,
    refetch,
  };
}

// Hook to fetch asset depeg status
export function useAssetDepegStatus(assets: string[]) {
  const { data, isLoading } = useReadContracts({
    contracts: assets.map((asset) => ({
      address: CONTRACTS.InsuranceTranche,
      abi: InsuranceTrancheABI,
      functionName: "checkDepeg",
      args: [asset],
    })),
  });

  const depegStatuses = data?.map((result, index) => {
    if (result?.status === "success") {
      const [isDepegged, currentPrice, deviation] = result.result as [
        boolean,
        bigint,
        bigint
      ];
      return {
        asset: assets[index],
        isDepegged,
        currentPrice: Number(currentPrice) / 1e8, // Chainlink uses 8 decimals
        deviation: Number(deviation) / 100, // Convert basis points to percentage
      };
    }
    return {
      asset: assets[index],
      isDepegged: false,
      currentPrice: 1.0,
      deviation: 0,
    };
  });

  return {
    depegStatuses: depegStatuses || [],
    isLoading,
  };
}

// Hook to fetch payout details for display
export function usePayoutDetails(payoutCount: number) {
  const { address } = useAccount();

  // Fetch details for each payout event
  const { data, isLoading, refetch } = useReadContracts({
    contracts: Array.from({ length: payoutCount }).flatMap((_, index) => [
      // Get payout history
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "payoutHistory",
        args: [BigInt(index)],
      },
      // Get claimable amount for this user
      ...(address
        ? [
            {
              address: CONTRACTS.InsuranceTranche,
              abi: InsuranceTrancheABI,
              functionName: "getClaimableAmount",
              args: [address, BigInt(index)],
            },
            // Check if already claimed
            {
              address: CONTRACTS.InsuranceTranche,
              abi: InsuranceTrancheABI,
              functionName: "hasClaimed",
              args: [BigInt(index), address],
            },
          ]
        : []),
    ]),
    query: {
      enabled: payoutCount > 0,
    },
  });

  // Parse payout details
  const payouts = [];
  const itemsPerPayout = address ? 3 : 1; // history + claimable + hasClaimed if connected

  for (let i = 0; i < payoutCount; i++) {
    const baseIndex = i * itemsPerPayout;
    const historyData = data?.[baseIndex];

    if (historyData?.status === "success") {
      const [asset, totalPayout, timestamp, price, deviation] = historyData.result as [
        string,
        bigint,
        bigint,
        bigint,
        bigint
      ];

      const claimableData = address ? data?.[baseIndex + 1] : null;
      const hasClaimedData = address ? data?.[baseIndex + 2] : null;

      const claimableAmount =
        claimableData?.status === "success"
          ? Number(formatEther(claimableData.result as bigint))
          : 0;

      const hasClaimed =
        hasClaimedData?.status === "success" ? (hasClaimedData.result as boolean) : false;

      payouts.push({
        index: i,
        asset,
        totalPayout: Number(formatEther(totalPayout)),
        timestamp: Number(timestamp),
        price: Number(price) / 1e8, // Chainlink 8 decimals
        deviation: Number(deviation), // basis points
        claimableAmount,
        hasClaimed,
      });
    }
  }

  return {
    payouts,
    isLoading,
    refetch,
  };
}