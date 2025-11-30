import { useReadContracts } from "wagmi";
import { useAccount } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { InsuranceTrancheABI } from "@/lib/contracts/abis";

export function useInsuranceCoverage() {
  const { address } = useAccount();

  const { data, isError, isLoading, refetch } = useReadContracts({
    contracts: [
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "getTotalPremiums",
      },
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "getTotalCoverage",
      },
      {
        address: CONTRACTS.InsuranceTranche,
        abi: InsuranceTrancheABI,
        functionName: "getCoverageRatio",
      },
      ...(address
        ? [
            {
              address: CONTRACTS.InsuranceTranche,
              abi: InsuranceTrancheABI,
              functionName: "getCoverageForLP",
              args: [address],
            },
          ]
        : []),
    ],
  });

  const totalPremiums =
    data?.[0]?.status === "success"
      ? Number(data[0].result) / 1e18
      : 0;
  const totalCoverage =
    data?.[1]?.status === "success"
      ? Number(data[1].result) / 1e18
      : 0;
  const coverageRatio =
    data?.[2]?.status === "success"
      ? Number(data[2].result) / 100 // Assuming basis points
      : 0;
  const userCoverage =
    address && data?.[3]?.status === "success"
      ? Number(data[3].result) / 1e18
      : 0;

  return {
    poolBalance: totalPremiums,
    totalCoverage,
    coverageRatio,
    userCoverage,
    isLoading,
    isError,
    refetch,
  };
}
