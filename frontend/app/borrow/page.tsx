"use client";

import { useState } from "react";
import Navigation from "@/components/Navigation";

export default function Borrow() {
  const [borrowAmount, setBorrowAmount] = useState("");

  const borrowStats = {
    lpPositionValue: 5000,
    maxLTV: 70, // 70%
    currentBorrowed: 2000,
    interestRate: 5.0, // 5% APY
    liquidationThreshold: 75, // 75%
  };

  const availableCredit = (borrowStats.lpPositionValue * borrowStats.maxLTV) / 100 - borrowStats.currentBorrowed;
  const currentLTV = (borrowStats.currentBorrowed / borrowStats.lpPositionValue) * 100;
  const healthFactor = borrowStats.lpPositionValue / (borrowStats.currentBorrowed || 1) * (borrowStats.liquidationThreshold / 100);

  const newBorrowAmount = parseFloat(borrowAmount) || 0;
  const newTotalBorrowed = borrowStats.currentBorrowed + newBorrowAmount;
  const newLTV = (newTotalBorrowed / borrowStats.lpPositionValue) * 100;
  const newHealthFactor = borrowStats.lpPositionValue / (newTotalBorrowed || 1) * (borrowStats.liquidationThreshold / 100);

  const handleBorrow = (e: React.FormEvent) => {
    e.preventDefault();
    console.log("Borrow:", borrowAmount);
    // Handle borrow logic here
  };

  const getHealthFactorColor = (hf: number) => {
    if (hf >= 2) return "text-green-600";
    if (hf >= 1.5) return "text-yellow-600";
    return "text-red-600";
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Borrow Against LP Position</h1>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Borrow Form */}
          <div className="lg:col-span-2 space-y-6">
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-xl font-semibold text-gray-900 mb-6">Borrow Funds</h2>

              <form onSubmit={handleBorrow} className="space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Borrow Amount
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      value={borrowAmount}
                      onChange={(e) => setBorrowAmount(e.target.value)}
                      placeholder="0.0"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      step="0.01"
                      min="0"
                      max={availableCredit}
                    />
                    <button
                      type="button"
                      onClick={() => setBorrowAmount(availableCredit.toString())}
                      className="absolute right-3 top-1/2 -translate-y-1/2 px-3 py-1 bg-blue-100 text-blue-600 rounded text-sm font-medium hover:bg-blue-200"
                    >
                      MAX
                    </button>
                  </div>
                  <p className="mt-2 text-sm text-gray-600">
                    Available credit: ${availableCredit.toFixed(2)}
                  </p>
                </div>

                {/* Projected Position */}
                {newBorrowAmount > 0 && (
                  <div className="bg-gray-50 rounded-lg p-4 space-y-3">
                    <h3 className="font-semibold text-gray-900">Projected Position</h3>
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600">Total Borrowed</span>
                        <span className="font-semibold text-gray-900">
                          ${newTotalBorrowed.toFixed(2)}
                        </span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600">Loan-to-Value</span>
                        <span className={`font-semibold ${newLTV > 65 ? "text-red-600" : "text-gray-900"}`}>
                          {newLTV.toFixed(2)}%
                        </span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600">Health Factor</span>
                        <span className={`font-semibold ${getHealthFactorColor(newHealthFactor)}`}>
                          {newHealthFactor.toFixed(2)}
                        </span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600">Est. Annual Interest</span>
                        <span className="font-semibold text-gray-900">
                          ${(newTotalBorrowed * borrowStats.interestRate / 100).toFixed(2)}
                        </span>
                      </div>
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={!borrowAmount || newBorrowAmount <= 0 || newBorrowAmount > availableCredit}
                  className="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors disabled:bg-gray-300 disabled:cursor-not-allowed"
                >
                  Borrow
                </button>

                <p className="text-xs text-gray-500 text-center">
                  Connect your wallet to borrow against your LP position
                </p>
              </form>
            </div>

            {/* Risk Warning */}
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <h3 className="font-semibold text-yellow-900 mb-2">Liquidation Risk</h3>
              <p className="text-sm text-yellow-800">
                If your health factor drops below 1.0, your position may be liquidated. Monitor your position
                carefully and consider adding collateral or repaying debt if your health factor approaches
                the liquidation threshold.
              </p>
            </div>
          </div>

          {/* Position Stats */}
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Current Position</h3>
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-gray-600">LP Position Value</p>
                  <p className="text-2xl font-bold text-gray-900">
                    ${borrowStats.lpPositionValue.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Current Borrowed</p>
                  <p className="text-2xl font-bold text-gray-900">
                    ${borrowStats.currentBorrowed.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Available Credit</p>
                  <p className="text-2xl font-bold text-green-600">
                    ${availableCredit.toFixed(2)}
                  </p>
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Risk Metrics</h3>
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between mb-2">
                    <span className="text-sm text-gray-600">Loan-to-Value</span>
                    <span className="text-sm font-semibold text-gray-900">
                      {currentLTV.toFixed(2)}% / {borrowStats.maxLTV}%
                    </span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className={`h-2 rounded-full ${
                        currentLTV > 65 ? "bg-red-500" : currentLTV > 50 ? "bg-yellow-500" : "bg-green-500"
                      }`}
                      style={{ width: `${(currentLTV / borrowStats.maxLTV) * 100}%` }}
                    ></div>
                  </div>
                </div>

                <div>
                  <div className="flex justify-between mb-2">
                    <span className="text-sm text-gray-600">Health Factor</span>
                    <span className={`text-sm font-semibold ${getHealthFactorColor(healthFactor)}`}>
                      {healthFactor.toFixed(2)}
                    </span>
                  </div>
                  <p className="text-xs text-gray-500">
                    Liquidation at &lt; 1.0
                  </p>
                </div>

                <div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Interest Rate</span>
                    <span className="text-sm font-semibold text-gray-900">
                      {borrowStats.interestRate}% APY
                    </span>
                  </div>
                </div>

                <div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Liquidation Threshold</span>
                    <span className="text-sm font-semibold text-gray-900">
                      {borrowStats.liquidationThreshold}%
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <p className="text-sm text-blue-800">
                <strong>LP Borrowing:</strong> Unlock liquidity from your LP position without selling.
                Your LP tokens serve as collateral, earning fees while you borrow.
              </p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
