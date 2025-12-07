"use client";

import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatEther, parseEther } from "viem";
import { useEffect, useState } from "react";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { LendingModuleABI, ERC20ABI } from "@/lib/contracts/abis";

export function useLending() {
  const { address } = useAccount();
  // const { isConnected } = useAccount();
  const [borrowAmount, setBorrowAmount] = useState("");
  const [repayAmount, setRepayAmount] = useState("");

  // Read contracts data
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
            functionName: "LTV_RATIO",
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
          {
            address: CONTRACTS.USDC,
            abi: ERC20ABI,
            functionName: "allowance",
            args: [address, CONTRACTS.LendingModule],
          },
        ]
      : [],
  });

  // Parse position data (struct)
  const position = data?.[0]?.status === "success" ? data[0].result as any : null;

  // Debug logging
  console.log("Raw data[0]:", data?.[0]);
  if (position) {
    console.log("Position data:", position);
    console.log("Position type:", typeof position);
    if (Array.isArray(position)) {
      console.log("Position is array, length:", position.length);
      console.log("Position[0]:", position[0]);
      console.log("Position[1]:", position[1]);
      console.log("Position[6]:", position[6]);
    }
  }

  const lpTokenAmount = position && position[0] ? Number(formatEther(position[0])) : 0;
  const collateralValue = position && position[1] ? Number(formatEther(position[1])) : 0;
  const borrowedAmount = position && position[2] ? Number(formatEther(position[2])) : 0;

  // Current debt includes accrued interest
  const currentDebt =
    data?.[1]?.status === "success"
      ? Number(formatEther(data[1].result as bigint))
      : borrowedAmount;

  // Available credit
  const availableCredit =
    data?.[2]?.status === "success"
      ? Number(formatEther(data[2].result as bigint))
      : 0;

  // Health factor
  const healthFactorRaw =
    data?.[3]?.status === "success"
      ? Number(data[3].result)
      : 10000;
  const healthFactor = healthFactorRaw / 100;

  // Interest rate
  const interestRate =
    data?.[4]?.status === "success"
      ? Number(data[4].result) / 100
      : 5.0;

  // Max LTV
  const maxLTV =
    data?.[5]?.status === "success"
      ? Number(data[5].result) / 100
      : 70.0;

  // Pool statistics
  const totalPool =
    data?.[6]?.status === "success"
      ? Number(formatEther(data[6].result as bigint))
      : 0;

  const totalBorrowed =
    data?.[7]?.status === "success"
      ? Number(formatEther(data[7].result as bigint))
      : 0;

  // USDC allowance
  const allowanceRaw = data?.[8]?.status === "success" ? data[8].result as bigint : 0n;

  // Calculate current LTV
  const currentLTV = collateralValue > 0 ? (currentDebt / collateralValue) * 100 : 0;

  // Calculate available liquidity
  const availableLiquidity = totalPool - totalBorrowed;

  // Write contracts
  const {
    writeContract: borrowWrite,
    data: borrowTxHash,
    isPending: isBorrowPending,
    error: borrowError,
  } = useWriteContract();

  const {
    writeContract: repayWrite,
    data: repayTxHash,
    isPending: isRepayPending,
    error: repayError,
  } = useWriteContract();

  const {
    writeContract: approveWrite,
    data: approveTxHash,
    isPending: isApprovePending,
  } = useWriteContract();

  // Wait for transactions
  const { isLoading: isBorrowConfirming, isSuccess: isBorrowConfirmed } =
    useWaitForTransactionReceipt({ hash: borrowTxHash });

  const { isLoading: isRepayConfirming, isSuccess: isRepayConfirmed } =
    useWaitForTransactionReceipt({ hash: repayTxHash });

  const { isLoading: isApproveConfirming, isSuccess: isApproveConfirmed } =
    useWaitForTransactionReceipt({ hash: approveTxHash });

  // Refetch data after transactions
  useEffect(() => {
    if (isBorrowConfirmed || isRepayConfirmed || isApproveConfirmed) {
      // Immediately refetch data
      refetch();

      // Delayed refetch to account for blockchain state propagation
      setTimeout(() => {
        console.log("Delayed refetch for lending data...");
        refetch();
      }, 2000);

      // Another refetch after 5 seconds for safety
      setTimeout(() => {
        console.log("Final refetch for lending data...");
        refetch();
      }, 5000);

      // Clear input fields after successful transaction
      if (isBorrowConfirmed) {
        setBorrowAmount("");
      }
      if (isRepayConfirmed) {
        setRepayAmount("");
      }

      // Refetch again after a short delay to ensure chain state is updated
      const timer = setTimeout(() => {
        refetch();
      }, 2000);

      return () => clearTimeout(timer);
    }
  }, [isBorrowConfirmed, isRepayConfirmed, isApproveConfirmed, refetch]);

  // Borrow function
  const borrow = async () => {
    if (!borrowAmount || parseFloat(borrowAmount) <= 0) return;
    if (!address) return;

    const amountWei = parseEther(borrowAmount);

    borrowWrite({
      address: CONTRACTS.LendingModule,
      abi: LendingModuleABI,
      functionName: "borrow",
      args: [amountWei],
    });
  };

  // Repay with approval
  const repayWithApproval = async () => {
    if (!repayAmount || parseFloat(repayAmount) <= 0) return;
    if (!address) return;

    const amountWei = parseEther(repayAmount);

    // Check if approval is needed
    if (allowanceRaw < amountWei) {
      // Need approval first
      approveWrite({
        address: CONTRACTS.USDC,
        abi: ERC20ABI,
        functionName: "approve",
        args: [CONTRACTS.LendingModule, amountWei],
      });
    } else {
      // Direct repay
      repayWrite({
        address: CONTRACTS.LendingModule,
        abi: LendingModuleABI,
        functionName: "repay",
        args: [amountWei],
      });
    }
  };

  // Simple check: if we have collateral value, we have a position
  const hasPosition = collateralValue > 0;

  return {
    // Position data
    lpPositionValue: collateralValue,
    lpTokenAmount,
    currentBorrowed: borrowedAmount,
    currentDebt,
    availableCredit,
    healthFactor,
    interestRate,
    maxLTV,
    currentLTV,
    hasPosition, // Simple check based on collateral value

    // Pool data
    totalPool,
    totalBorrowed,
    availableLiquidity,

    // Input state
    borrowAmount,
    setBorrowAmount,
    repayAmount,
    setRepayAmount,

    // Actions
    borrow,
    repayWithApproval,

    // Loading states
    isLoading,
    isError,
    isBorrowing: isBorrowPending || isBorrowConfirming,
    isRepaying: isRepayPending || isRepayConfirming || isApprovePending || isApproveConfirming,
    isBorrowConfirmed,
    isRepayConfirmed,
    needsApproval: repayAmount ? parseEther(repayAmount) > allowanceRaw : false,

    // Transaction hashes
    borrowTxHash,
    repayTxHash,

    // Errors
    borrowError,
    repayError,

    // Refetch - expose this for manual refresh
    refetch,
  };
}