import { useReadContracts } from "wagmi";
import { useAccount } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { InsuranceTrancheABI } from "@/lib/contracts/abis";
import { formatEther } from "viem";

export function useInsuranceCoverage() {
  const { address } = useAccount();

  const { data, isError, isLoading, refetch } = useReadContracts({
    contracts: [
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "insurancePoolBalance",
        args: [],
      },
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "totalLPShares",
        args: [],
      },
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "getPayoutHistoryCount",
        args: [],
      },
      ...(address
        ? [
            {
              address: CONTRACTS.InsuranceTranche,
              abi: InsuranceTrancheABI,
              functionName: "getLPPosition",
              args: [address],
            },
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

  // Insurance pool balance
  const poolBalance =
    data?.[0]?.status === "success"
      ? Number(formatEther(data[0].result as bigint))
      : 0;

  // Total LP shares covered
  const totalLPShares =
    data?.[1]?.status === "success"
      ? Number(formatEther(data[1].result as bigint))
      : 0;

  // Payout history count
  const payoutCount =
    data?.[2]?.status === "success"
      ? Number(data[2].result)
      : 0;

  // User LP position (if exists)
  const userPosition = address && data?.[3]?.status === "success"
    ? data[3].result as any
    : null;

  // Alternative user position data
  const userPositionAlt = address && data?.[4]?.status === "success"
    ? data[4].result as any
    : null;

  // Parse user coverage amount
  const userShares = userPosition
    ? Number(formatEther(userPosition[0] || 0n)) // shares is first field
    : userPositionAlt
    ? Number(formatEther(userPositionAlt[0] || 0n))
    : 0;

  // Calculate coverage ratio (pool balance / total shares)
  const coverageRatio = totalLPShares > 0
    ? (poolBalance / totalLPShares) * 100
    : 0;

  // Calculate user coverage amount
  const userCoverage = userShares > 0 && totalLPShares > 0
    ? (userShares / totalLPShares) * poolBalance
    : 0;

  // Check if user has active position
  const hasInsurance = userPosition
    ? userPosition[2] === true // isActive is 3rd field
    : userPositionAlt
    ? userPositionAlt[2] === true
    : false;

  return {
    poolBalance,
    totalCoverage: totalLPShares,
    coverageRatio,
    userCoverage,
    userShares,
    hasInsurance,
    payoutCount,
    isLoading,
    isError,
    refetch,
  };
}
