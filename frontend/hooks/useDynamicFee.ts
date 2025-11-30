import { useReadContracts } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { VolatilityOracleABI, BastionHookABI } from "@/lib/contracts/abis";

export function useDynamicFee() {
  const { data, isError, isLoading, refetch } = useReadContracts({
    contracts: [
      {
        address: CONTRACTS.VolatilityOracle,
        abi: VolatilityOracleABI,
        functionName: "getVolatility",
      },
      {
        address: CONTRACTS.BastionHook,
        abi: BastionHookABI,
        functionName: "getFeeRate",
      },
    ],
  });

  const volatility =
    data?.[0]?.status === "success"
      ? Number(data[0].result) / 100 // Convert from basis points to percentage
      : 0;

  const feeRate =
    data?.[1]?.status === "success"
      ? Number(data[1].result) / 10000 // Convert from basis points to percentage
      : 0;

  // Determine fee tier based on volatility
  let feeTier: "LOW" | "MEDIUM" | "HIGH";
  if (volatility < 10) {
    feeTier = "LOW";
  } else if (volatility < 14) {
    feeTier = "MEDIUM";
  } else {
    feeTier = "HIGH";
  }

  return {
    volatility,
    feeRate,
    feeTier,
    isLoading,
    isError,
    refetch,
  };
}
