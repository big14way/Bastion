"use client";

import { useState, useEffect } from "react";
import Navigation from "@/components/Navigation";
import { useLending } from "@/hooks/useLending";
import { useAccount } from "wagmi";

export default function Borrow() {
  const { address, isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState<"borrow" | "repay">("borrow");
  const [showBorrowSuccess, setShowBorrowSuccess] = useState(false);
  const [showRepaySuccess, setShowRepaySuccess] = useState(false);
  const [lastBorrowAmount, setLastBorrowAmount] = useState("");
  const [lastRepayAmount, setLastRepayAmount] = useState("");

  // Use the proper lending hook with repayment functions
  const {
    lpPositionValue,
    currentBorrowed,
    currentDebt,
    availableCredit,
    healthFactor,
    interestRate,
    maxLTV,
    currentLTV,
    hasPosition,
    borrowAmount,
    setBorrowAmount,
    repayAmount,
    setRepayAmount,
    borrow,
    repayWithApproval,
    isBorrowing,
    isRepaying,
    needsApproval,
    totalPool,
    totalBorrowed,
    availableLiquidity,
    isBorrowConfirmed,
    isRepayConfirmed,
    borrowTxHash,
    repayTxHash,
    refetch,
  } = useLending();

  const liquidationThreshold = 75; // 75% - could also fetch from contract

  const newBorrowAmount = parseFloat(borrowAmount) || 0;
  const newTotalBorrowed = currentBorrowed + newBorrowAmount;
  const newLTV = lpPositionValue > 0 ? (newTotalBorrowed / lpPositionValue) * 100 : 0;
  const newHealthFactor = newTotalBorrowed > 0 ? lpPositionValue / newTotalBorrowed * (liquidationThreshold / 100) : 0;

  // Handle successful transactions
  useEffect(() => {
    if (isBorrowConfirmed && borrowAmount) {
      setLastBorrowAmount(borrowAmount);
      setShowBorrowSuccess(true);

      // Immediate refetch
      refetch();

      // Delayed refetch for blockchain state propagation
      const refetchTimer1 = setTimeout(() => {
        console.log("Delayed refetch after borrow...");
        refetch();
      }, 2000);

      const refetchTimer2 = setTimeout(() => {
        console.log("Final refetch after borrow...");
        refetch();
      }, 5000);

      // Hide success message after 10 seconds
      const hideTimer = setTimeout(() => {
        setShowBorrowSuccess(false);
      }, 10000);

      return () => {
        clearTimeout(refetchTimer1);
        clearTimeout(refetchTimer2);
        clearTimeout(hideTimer);
      };
    }
  }, [isBorrowConfirmed, borrowAmount, refetch]);

  useEffect(() => {
    if (isRepayConfirmed && repayAmount) {
      setLastRepayAmount(repayAmount);
      setShowRepaySuccess(true);

      // Immediate refetch
      refetch();

      // Delayed refetch for blockchain state propagation
      const refetchTimer1 = setTimeout(() => {
        console.log("Delayed refetch after repay...");
        refetch();
      }, 2000);

      const refetchTimer2 = setTimeout(() => {
        console.log("Final refetch after repay...");
        refetch();
      }, 5000);

      // Hide success message after 10 seconds
      const hideTimer = setTimeout(() => {
        setShowRepaySuccess(false);
      }, 10000);

      return () => {
        clearTimeout(refetchTimer1);
        clearTimeout(refetchTimer2);
        clearTimeout(hideTimer);
      };
    }
  }, [isRepayConfirmed, repayAmount, refetch]);

  const handleBorrow = (e: React.FormEvent) => {
    e.preventDefault();
    if (borrowAmount && parseFloat(borrowAmount) > 0) {
      borrow();
    }
  };

  const handleRepay = (e: React.FormEvent) => {
    e.preventDefault();
    if (repayAmount && parseFloat(repayAmount) > 0) {
      repayWithApproval();
    }
  };

  const getHealthFactorColor = (hf: number) => {
    if (hf >= 2) return "text-green-400";
    if (hf >= 1.5) return "text-yellow-400";
    return "text-red-400";
  };

  const getHealthFactorStatus = (hf: number) => {
    if (hf >= 2) return "Safe";
    if (hf >= 1.5) return "Caution";
    if (hf >= 1) return "Risk";
    return "Danger";
  };

  return (
    <div className="min-h-screen">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Hero Section */}
        <div className="mb-12">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-white via-green-200 to-emerald-200 bg-clip-text text-transparent">
            Borrow Against LP Position
          </h1>
          <p className="text-gray-400 text-lg">Unlock liquidity from your LP tokens without selling your position</p>
        </div>

        {/* Success Messages */}
        {showBorrowSuccess && (
          <div className="mb-8 glass rounded-2xl p-6 border border-green-500/30 bg-gradient-to-br from-green-500/10 to-emerald-500/10 animate-fade-in">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-lg bg-green-500/20 flex items-center justify-center flex-shrink-0">
                <span className="text-2xl">✅</span>
              </div>
              <div className="flex-1">
                <h3 className="font-bold text-green-400 text-lg">Transaction Successful!</h3>
                <p className="text-gray-300">
                  You have successfully borrowed ${parseFloat(lastBorrowAmount).toFixed(2)} USDC
                </p>
                {borrowTxHash && (
                  <a
                    href={`https://sepolia.basescan.org/tx/${borrowTxHash}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-xs text-blue-400 hover:text-blue-300 underline mt-1 inline-block"
                  >
                    View on BaseScan →
                  </a>
                )}
              </div>
            </div>
          </div>
        )}

        {showRepaySuccess && (
          <div className="mb-8 glass rounded-2xl p-6 border border-green-500/30 bg-gradient-to-br from-green-500/10 to-emerald-500/10 animate-fade-in">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-lg bg-green-500/20 flex items-center justify-center flex-shrink-0">
                <span className="text-2xl">✅</span>
              </div>
              <div className="flex-1">
                <h3 className="font-bold text-green-400 text-lg">Repayment Successful!</h3>
                <p className="text-gray-300">
                  You have successfully repaid ${parseFloat(lastRepayAmount).toFixed(2)} USDC
                </p>
                {repayTxHash && (
                  <a
                    href={`https://sepolia.basescan.org/tx/${repayTxHash}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-xs text-blue-400 hover:text-blue-300 underline mt-1 inline-block"
                  >
                    View on BaseScan →
                  </a>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Alert if user has debt */}
        {currentDebt > 0 && (
          <div className="mb-8 glass rounded-2xl p-6 border border-yellow-500/30 bg-gradient-to-br from-yellow-500/10 to-orange-500/10">
            <div className="flex items-start space-x-3">
              <div className="w-10 h-10 rounded-lg bg-yellow-500/20 flex items-center justify-center flex-shrink-0">
                <span className="text-2xl">💳</span>
              </div>
              <div className="flex-1">
                <h3 className="font-bold text-yellow-400 mb-2 text-lg">Active Loan</h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div>
                    <p className="text-sm text-gray-400">Outstanding Debt</p>
                    <p className="text-xl font-bold text-white">${currentDebt.toFixed(2)}</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">Health Factor</p>
                    <p className={`text-xl font-bold ${getHealthFactorColor(healthFactor)}`}>
                      {healthFactor.toFixed(2)} ({getHealthFactorStatus(healthFactor)})
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">Annual Interest</p>
                    <p className="text-xl font-bold text-white">${(currentDebt * interestRate / 100).toFixed(2)}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Borrow/Repay Form */}
          <div className="lg:col-span-2 space-y-6">
            <div className="glass rounded-2xl p-8 border border-white/10">
              {/* Tab Switcher */}
              <div className="flex space-x-2 mb-8">
                <button
                  onClick={() => setActiveTab("borrow")}
                  className={`flex-1 py-3 px-6 rounded-xl font-bold transition-all ${
                    activeTab === "borrow"
                      ? "bg-gradient-to-r from-green-600 to-emerald-600 text-white shadow-lg shadow-green-500/20"
                      : "bg-white/5 text-gray-400 hover:bg-white/10"
                  }`}
                >
                  <span className="text-lg mr-2">💰</span> Borrow
                </button>
                <button
                  onClick={() => setActiveTab("repay")}
                  className={`flex-1 py-3 px-6 rounded-xl font-bold transition-all ${
                    activeTab === "repay"
                      ? "bg-gradient-to-r from-blue-600 to-cyan-600 text-white shadow-lg shadow-blue-500/20"
                      : "bg-white/5 text-gray-400 hover:bg-white/10"
                  }`}
                >
                  <span className="text-lg mr-2">💸</span> Repay
                </button>
              </div>

              {/* Borrow Tab */}
              {activeTab === "borrow" && (
                <form onSubmit={handleBorrow} className="space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-3">
                    Borrow Amount
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      value={borrowAmount}
                      onChange={(e) => setBorrowAmount(e.target.value)}
                      placeholder="0.0"
                      className="w-full px-6 py-4 bg-white/5 border border-white/10 rounded-xl text-white text-lg focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all"
                      step="0.01"
                      min="0"
                      max={availableCredit}
                    />
                    <button
                      type="button"
                      onClick={() => setBorrowAmount(availableCredit.toString())}
                      className="absolute right-4 top-1/2 -translate-y-1/2 px-4 py-2 bg-green-500/20 text-green-400 rounded-lg text-sm font-semibold hover:bg-green-500/30 transition-all border border-green-500/30"
                    >
                      MAX
                    </button>
                  </div>
                  <p className="mt-3 text-sm text-gray-400">
                    Available credit: <span className="text-white font-semibold">${availableCredit.toFixed(2)}</span>
                  </p>
                </div>

                {/* Projected Position */}
                {newBorrowAmount > 0 && (
                  <div className="glass-hover rounded-xl p-6 space-y-3 border border-white/10">
                    <h3 className="font-bold text-white text-lg mb-4">Projected Position</h3>
                    <div className="space-y-3">
                      <div className="flex justify-between items-center p-3 rounded-lg bg-white/5">
                        <span className="text-gray-400">Total Borrowed</span>
                        <span className="font-bold text-white">
                          ${newTotalBorrowed.toFixed(2)}
                        </span>
                      </div>
                      <div className="flex justify-between items-center p-3 rounded-lg bg-white/5">
                        <span className="text-gray-400">Loan-to-Value</span>
                        <span className={`font-bold ${newLTV > 65 ? "text-red-400" : "text-white"}`}>
                          {newLTV.toFixed(2)}%
                        </span>
                      </div>
                      <div className="flex justify-between items-center p-3 rounded-lg bg-white/5">
                        <span className="text-gray-400">Health Factor</span>
                        <span className={`font-bold ${getHealthFactorColor(newHealthFactor)}`}>
                          {newHealthFactor.toFixed(2)}
                        </span>
                      </div>
                      <div className="flex justify-between items-center p-3 rounded-lg bg-white/5">
                        <span className="text-gray-400">Est. Annual Interest</span>
                        <span className="font-bold text-white">
                          ${(newTotalBorrowed * interestRate / 100).toFixed(2)}
                        </span>
                      </div>
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={!isConnected || isBorrowing || !borrowAmount || newBorrowAmount <= 0 || newBorrowAmount > availableCredit}
                  className="w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white py-4 rounded-xl font-bold text-lg hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg shadow-green-500/20 hover:shadow-green-500/40 disabled:from-gray-600 disabled:to-gray-700 disabled:cursor-not-allowed disabled:shadow-none"
                >
                  {!isConnected ? "Connect Wallet" : isBorrowing ? "Borrowing..." : "Borrow Funds"}
                </button>

                {!isConnected && (
                  <p className="text-xs text-gray-500 text-center">
                    Connect your wallet to borrow against your LP position
                  </p>
                )}
                {isConnected && !hasPosition && (
                  <p className="text-xs text-yellow-500 text-center">
                    No LP position found. You need LP tokens to borrow.
                  </p>
                )}
                {isConnected && hasPosition && availableCredit === 0 && (
                  <p className="text-xs text-red-500 text-center">
                    No borrowing capacity available.
                  </p>
                )}
                {isBorrowing && (
                  <div className="glass rounded-xl p-4 border border-purple-500/30 bg-purple-500/10">
                    <p className="text-sm text-purple-400 text-center">
                      Processing borrow... Transaction is being confirmed on the blockchain.
                    </p>
                  </div>
                )}
              </form>
              )}

              {/* Repay Tab */}
              {activeTab === "repay" && (
                <form onSubmit={handleRepay} className="space-y-6">
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-3">
                      Repay Amount (USDC)
                    </label>
                    <div className="relative">
                      <input
                        type="number"
                        value={repayAmount}
                        onChange={(e) => setRepayAmount(e.target.value)}
                        placeholder="0.0"
                        className="w-full px-6 py-4 bg-white/5 border border-white/10 rounded-xl text-white text-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                        step="0.01"
                        min="0"
                        max={currentDebt}
                      />
                      <button
                        type="button"
                        onClick={() => setRepayAmount(currentDebt.toString())}
                        className="absolute right-4 top-1/2 -translate-y-1/2 px-4 py-2 bg-blue-500/20 text-blue-400 rounded-lg text-sm font-semibold hover:bg-blue-500/30 transition-all border border-blue-500/30"
                      >
                        FULL
                      </button>
                    </div>
                    <p className="mt-3 text-sm text-gray-400">
                      Current debt: <span className="text-white font-semibold">${currentDebt.toFixed(2)}</span>
                    </p>
                  </div>

                  {/* After Repayment Preview */}
                  {parseFloat(repayAmount) > 0 && (
                    <div className="glass-hover rounded-xl p-6 space-y-3 border border-white/10">
                      <h3 className="font-bold text-white text-lg mb-4">After Repayment</h3>
                      <div className="space-y-3">
                        <div className="flex justify-between items-center p-3 rounded-lg bg-white/5">
                          <span className="text-gray-400">Remaining Debt</span>
                          <span className="font-bold text-white">
                            ${Math.max(0, currentDebt - parseFloat(repayAmount)).toFixed(2)}
                          </span>
                        </div>
                        <div className="flex justify-between items-center p-3 rounded-lg bg-white/5">
                          <span className="text-gray-400">New Available Credit</span>
                          <span className="font-bold text-green-400">
                            ${(availableCredit + Math.min(parseFloat(repayAmount), currentDebt)).toFixed(2)}
                          </span>
                        </div>
                        {currentDebt - parseFloat(repayAmount) <= 0 && (
                          <div className="p-3 rounded-lg bg-green-500/10 border border-green-500/30">
                            <span className="text-green-400 font-semibold">✅ Loan will be fully repaid!</span>
                          </div>
                        )}
                      </div>
                    </div>
                  )}

                  {needsApproval && (
                    <div className="p-4 rounded-lg bg-blue-500/10 border border-blue-500/30">
                      <p className="text-sm text-blue-400">
                        ℹ️ This transaction will first approve USDC spending, then repay your loan.
                      </p>
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={!isConnected || isRepaying || !repayAmount || parseFloat(repayAmount) <= 0 || currentDebt === 0}
                    className="w-full bg-gradient-to-r from-blue-600 to-cyan-600 text-white py-4 rounded-xl font-bold text-lg hover:from-blue-700 hover:to-cyan-700 transition-all shadow-lg shadow-blue-500/20 hover:shadow-blue-500/40 disabled:from-gray-600 disabled:to-gray-700 disabled:cursor-not-allowed disabled:shadow-none"
                  >
                    {!isConnected ? "Connect Wallet" :
                     isRepaying ? "Processing..." :
                     needsApproval ? "Approve & Repay USDC" : "Repay USDC"}
                  </button>

                  {!isConnected && (
                    <p className="text-xs text-gray-500 text-center">
                      Connect your wallet to manage your loans
                    </p>
                  )}
                  {isConnected && currentDebt === 0 && (
                    <p className="text-xs text-gray-500 text-center">
                      You have no outstanding debt to repay
                    </p>
                  )}
                  {isRepaying && (
                    <div className="glass rounded-xl p-4 border border-blue-500/30 bg-blue-500/10">
                      <p className="text-sm text-blue-400 text-center">
                        {needsApproval ? "Approving USDC spending... Please confirm in your wallet." : "Processing repayment... Transaction is being confirmed on the blockchain."}
                      </p>
                    </div>
                  )}
                </form>
              )}
            </div>

            {/* Risk Warning */}
            <div className="glass rounded-2xl p-6 border border-yellow-500/30 bg-gradient-to-br from-yellow-500/10 to-orange-500/10">
              <div className="flex items-start space-x-3">
                <div className="w-10 h-10 rounded-lg bg-yellow-500/20 flex items-center justify-center flex-shrink-0">
                  <span className="text-2xl">⚠️</span>
                </div>
                <div>
                  <h3 className="font-bold text-yellow-400 mb-2 text-lg">Important Information</h3>
                  <ul className="text-sm text-gray-300 space-y-2">
                    <li>• <strong>Liquidation Risk:</strong> If health factor drops below 1.0, your position may be liquidated</li>
                    <li>• <strong>Interest Accrues:</strong> Your debt grows over time at {interestRate}% APY</li>
                    <li>• <strong>Monitor Health:</strong> Keep health factor above 1.5 for safety</li>
                    <li>• <strong>Repay Regularly:</strong> Reduce debt to improve health factor</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>

          {/* Position Stats Sidebar */}
          <div className="space-y-6">
            <div className="glass glass-hover rounded-2xl p-8 border border-white/10">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-white">Your Position</h3>
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500/20 to-cyan-500/20 flex items-center justify-center">
                  <span className="text-2xl">📊</span>
                </div>
              </div>
              <div className="space-y-4">
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Collateral Value</p>
                  <p className="text-2xl font-bold text-white">
                    ${lpPositionValue.toLocaleString()}
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Current Debt</p>
                  <p className="text-2xl font-bold text-white">
                    ${currentDebt.toFixed(2)}
                  </p>
                  {currentDebt > currentBorrowed && (
                    <p className="text-xs text-gray-500 mt-1">
                      (includes ${(currentDebt - currentBorrowed).toFixed(2)} interest)
                    </p>
                  )}
                </div>
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Available to Borrow</p>
                  <p className="text-2xl font-bold text-green-400">
                    ${availableCredit.toFixed(2)}
                  </p>
                </div>
              </div>
            </div>

            <div className="glass glass-hover rounded-2xl p-8 border border-white/10">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-white">Risk Metrics</h3>
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-red-500/20 to-pink-500/20 flex items-center justify-center">
                  <span className="text-2xl">⚡</span>
                </div>
              </div>
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between mb-3">
                    <span className="text-sm text-gray-400">Loan-to-Value</span>
                    <span className="text-sm font-bold text-white">
                      {currentLTV.toFixed(2)}% / {maxLTV}%
                    </span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
                    <div
                      className={`h-3 rounded-full transition-all ${
                        currentLTV > 65 ? "bg-gradient-to-r from-red-500 to-rose-500" :
                        currentLTV > 50 ? "bg-gradient-to-r from-yellow-500 to-orange-500" :
                        "bg-gradient-to-r from-green-500 to-emerald-500"
                      }`}
                      style={{ width: `${(currentLTV / maxLTV) * 100}%` }}
                    ></div>
                  </div>
                </div>

                {/* Health Factor with Visual Indicator */}
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <div className="flex justify-between mb-3">
                    <span className="text-sm text-gray-400">Health Factor</span>
                    <span className={`text-lg font-bold ${getHealthFactorColor(healthFactor)}`}>
                      {currentDebt > 0 ? healthFactor.toFixed(2) : "∞"}
                    </span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
                    <div
                      className={`h-3 rounded-full transition-all ${
                        healthFactor >= 2 ? "bg-gradient-to-r from-green-500 to-emerald-500" :
                        healthFactor >= 1.5 ? "bg-gradient-to-r from-yellow-500 to-orange-500" :
                        "bg-gradient-to-r from-red-500 to-rose-500"
                      }`}
                      style={{ width: currentDebt > 0 ? `${Math.min(100, (healthFactor / 3) * 100)}%` : '100%' }}
                    ></div>
                  </div>
                  <p className="text-xs text-gray-500 mt-2">
                    Status: <span className={getHealthFactorColor(healthFactor)}>
                      {getHealthFactorStatus(healthFactor)}
                    </span>
                  </p>
                </div>

                <div className="flex justify-between p-3 rounded-lg bg-white/5">
                  <span className="text-sm text-gray-400">Interest Rate</span>
                  <span className="text-sm font-bold text-white">
                    {interestRate}% APY
                  </span>
                </div>

                <div className="flex justify-between p-3 rounded-lg bg-white/5">
                  <span className="text-sm text-gray-400">Liquidation Threshold</span>
                  <span className="text-sm font-bold text-white">
                    {liquidationThreshold}%
                  </span>
                </div>
              </div>
            </div>

            {/* Pool Statistics */}
            <div className="glass rounded-2xl p-6 border border-blue-500/30 bg-gradient-to-br from-blue-500/10 to-cyan-500/10">
              <h3 className="font-bold text-cyan-400 mb-3">Lending Pool Stats</h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Total Pool</span>
                  <span className="text-white font-semibold">${totalPool.toLocaleString()}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Total Borrowed</span>
                  <span className="text-white font-semibold">${totalBorrowed.toLocaleString()}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Available</span>
                  <span className="text-cyan-400 font-semibold">${availableLiquidity.toLocaleString()}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Utilization</span>
                  <span className="text-white font-semibold">
                    {totalPool > 0 ? ((totalBorrowed / totalPool) * 100).toFixed(1) : 0}%
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
