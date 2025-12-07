import { useReadContracts } from "wagmi";
import { useAccount } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { LendingModuleABI } from "@/lib/contracts/abis";
import { formatEther } from "viem";

export function useBorrowingCapacity() {
  const { address } = useAccount();

  const { data, isError, isLoading, refetch } = useReadContracts({
    contracts: address
      ? [
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "positions",
            args: [address],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getCurrentDebt",
            args: [address],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "getMaxBorrow",
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
            functionName: "defaultInterestRate",
            args: [],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "totalLendingPool",
            args: [],
          },
          {
            address: CONTRACTS.LendingModule,
            abi: LendingModuleABI,
            functionName: "totalBorrowed",
            args: [],
          },
        ]
      : [],
  });

  // Parse position data (struct)
  const position = data?.[0]?.status === "success" ? data[0].result as any : null;
  const collateralValue = position ? Number(formatEther(position[1])) : 0; // collateralValue is 2nd field
  const borrowedAmount = position ? Number(formatEther(position[2])) : 0; // borrowedAmount is 3rd field

  // Current debt includes accrued interest
  const currentDebt =
    data?.[1]?.status === "success"
      ? Number(formatEther(data[1].result as bigint))
      : borrowedAmount;

  // Available credit (max borrow - current debt)
  const availableCredit =
    data?.[2]?.status === "success"
      ? Number(formatEther(data[2].result as bigint))
      : 0;

  // Health factor (BASIS_POINTS = 10000 = 100%)
  const healthFactorRaw =
    data?.[3]?.status === "success"
      ? Number(data[3].result)
      : 10000;
  const healthFactor = healthFactorRaw / 100; // Convert to percentage

  // Interest rate (in basis points)
  const interestRate =
    data?.[4]?.status === "success"
      ? Number(data[4].result) / 100 // Convert basis points to percentage
      : 5.0; // Default 5%

  // LTV ratio hardcoded (70%)
  const maxLTV = 70.0;

  // Pool statistics
  const totalPool =
    data?.[5]?.status === "success"
      ? Number(formatEther(data[5].result as bigint))
      : 0;

  const totalBorrowed =
    data?.[6]?.status === "success"
      ? Number(formatEther(data[6].result as bigint))
      : 0;

  // Calculate current LTV
  const currentLTV =
    collateralValue > 0 ? (currentDebt / collateralValue) * 100 : 0;

  // Calculate available liquidity in pool
  const availableLiquidity = totalPool - totalBorrowed;

  return {
    lpPositionValue: collateralValue,
    currentBorrowed: borrowedAmount,
    currentDebt,
    availableCredit,
    healthFactor,
    interestRate,
    maxLTV,
    currentLTV,
    totalPool,
    totalBorrowed,
    availableLiquidity,
    hasPosition: position && position[6], // isActive is 7th field
    isLoading,
    isError,
    refetch,
  };
}
