import { useReadContracts, useAccount } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { InsuranceTrancheABI } from "@/lib/contracts/abis";
import { formatEther } from "viem";

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

  // Parse user position if connected
  const userPosition =
    address && data?.[4]?.status === "success"
      ? (data[4].result as any)
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

  return {
    // Pool stats
    poolBalance,
    totalLPShares,
    coverageRatio,

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