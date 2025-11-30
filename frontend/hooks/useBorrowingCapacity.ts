import { useReadContracts } from "wagmi";
import { useAccount } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { LendingModuleABI } from "@/lib/contracts/abis";

export function useBorrowingCapacity() {
  const { address } = useAccount();

  const { data, isError, isLoading, refetch } = useReadContracts({
    contracts: address
      ? [
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getCollateralValue",
            args: [address],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getBorrowedAmount",
            args: [address],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getAvailableCredit",
            args: [address],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getHealthFactor",
            args: [address],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getInterestRate",
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getLTV",
          },
        ]
      : [],
  });

  const collateralValue =
    data?.[0]?.status === "success"
      ? Number(data[0].result) / 1e18
      : 0;
  const borrowedAmount =
    data?.[1]?.status === "success"
      ? Number(data[1].result) / 1e18
      : 0;
  const availableCredit =
    data?.[2]?.status === "success"
      ? Number(data[2].result) / 1e18
      : 0;
  const healthFactor =
    data?.[3]?.status === "success"
      ? Number(data[3].result) / 1e18
      : 0;
  const interestRate =
    data?.[4]?.status === "success"
      ? Number(data[4].result) / 100 // Assuming basis points
      : 0;
  const ltv =
    data?.[5]?.status === "success"
      ? Number(data[5].result) / 100 // Assuming basis points
      : 0;

  const currentLTV =
    collateralValue > 0 ? (borrowedAmount / collateralValue) * 100 : 0;

  return {
    lpPositionValue: collateralValue,
    currentBorrowed: borrowedAmount,
    availableCredit,
    healthFactor,
    interestRate,
    maxLTV: ltv,
    currentLTV,
    isLoading,
    isError,
    refetch,
  };
}
