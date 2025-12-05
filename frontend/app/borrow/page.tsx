"use client";

import { useState } from "react";
import Navigation from "@/components/Navigation";
import { useBorrowingCapacity } from "@/hooks";

export default function Borrow() {
  const [borrowAmount, setBorrowAmount] = useState("");

  // Fetch real-time borrowing data from blockchain
  const {
    lpPositionValue,
    currentBorrowed,
    availableCredit,
    healthFactor,
    interestRate,
    maxLTV,
    currentLTV,
  } = useBorrowingCapacity();

  const liquidationThreshold = 75; // 75% - could also fetch from contract

  const newBorrowAmount = parseFloat(borrowAmount) || 0;
  const newTotalBorrowed = currentBorrowed + newBorrowAmount;
  const newLTV = lpPositionValue > 0 ? (newTotalBorrowed / lpPositionValue) * 100 : 0;
  const newHealthFactor = newTotalBorrowed > 0 ? lpPositionValue / newTotalBorrowed * (liquidationThreshold / 100) : 0;

  const handleBorrow = (e: React.FormEvent) => {
    e.preventDefault();
    console.log("Borrow:", borrowAmount);
    // Handle borrow logic here
  };

  const getHealthFactorColor = (hf: number) => {
    if (hf >= 2) return "text-green-400";
    if (hf >= 1.5) return "text-yellow-400";
    return "text-red-400";
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

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Borrow Form */}
          <div className="lg:col-span-2 space-y-6">
            <div className="glass rounded-2xl p-8 border border-white/10">
              <div className="flex items-center space-x-3 mb-8">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-green-500/20 to-emerald-500/20 flex items-center justify-center">
                  <span className="text-2xl">💰</span>
                </div>
                <h2 className="text-2xl font-bold text-white">Borrow Funds</h2>
              </div>

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
                  disabled={!borrowAmount || newBorrowAmount <= 0 || newBorrowAmount > availableCredit}
                  className="w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white py-4 rounded-xl font-bold text-lg hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg shadow-green-500/20 hover:shadow-green-500/40 disabled:from-gray-600 disabled:to-gray-700 disabled:cursor-not-allowed disabled:shadow-none"
                >
                  Borrow Funds
                </button>

                <p className="text-xs text-gray-500 text-center">
                  Connect your wallet to borrow against your LP position
                </p>
              </form>
            </div>

            {/* Risk Warning */}
            <div className="glass rounded-2xl p-6 border border-yellow-500/30 bg-gradient-to-br from-yellow-500/10 to-orange-500/10">
              <div className="flex items-start space-x-3">
                <div className="w-10 h-10 rounded-lg bg-yellow-500/20 flex items-center justify-center flex-shrink-0">
                  <span className="text-2xl">⚠️</span>
                </div>
                <div>
                  <h3 className="font-bold text-yellow-400 mb-2 text-lg">Liquidation Risk</h3>
                  <p className="text-sm text-gray-300 leading-relaxed">
                    If your health factor drops below 1.0, your position may be liquidated. Monitor your position
                    carefully and consider adding collateral or repaying debt if your health factor approaches
                    the liquidation threshold.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Position Stats Sidebar */}
          <div className="space-y-6">
            <div className="glass glass-hover rounded-2xl p-8 border border-white/10">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-white">Current Position</h3>
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500/20 to-cyan-500/20 flex items-center justify-center">
                  <span className="text-2xl">📊</span>
                </div>
              </div>
              <div className="space-y-4">
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">LP Position Value</p>
                  <p className="text-3xl font-bold text-white">
                    ${lpPositionValue.toLocaleString()}
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Current Borrowed</p>
                  <p className="text-3xl font-bold text-white">
                    ${currentBorrowed.toLocaleString()}
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Available Credit</p>
                  <p className="text-3xl font-bold text-green-400">
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

                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <div className="flex justify-between mb-2">
                    <span className="text-sm text-gray-400">Health Factor</span>
                    <span className={`text-sm font-bold ${getHealthFactorColor(healthFactor)}`}>
                      {healthFactor.toFixed(2)}
                    </span>
                  </div>
                  <p className="text-xs text-gray-500">
                    Liquidation at &lt; 1.0
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

            <div className="glass rounded-2xl p-6 border border-blue-500/30 bg-gradient-to-br from-blue-500/10 to-cyan-500/10">
              <div className="flex items-start space-x-3">
                <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center flex-shrink-0 mt-1">
                  <span className="text-lg">ℹ️</span>
                </div>
                <div>
                  <p className="text-sm text-gray-300 leading-relaxed">
                    <strong className="text-blue-400">LP Borrowing:</strong> Unlock liquidity from your LP position without selling.
                    Your LP tokens serve as collateral, earning fees while you borrow.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
