"use client";

import { useState } from "react";
import Navigation from "@/components/Navigation";

export default function Vault() {
  const [tab, setTab] = useState<"deposit" | "withdraw">("deposit");
  const [amount, setAmount] = useState("");

  const vaultStats = {
    totalDeposits: 125000,
    yourDeposits: 5000,
    yourShares: 4850,
    sharePrice: 1.031,
    apy: 12.5,
  };

  const maxDeposit = 10000; // User's wallet balance
  const maxWithdraw = vaultStats.yourDeposits;

  const handleMax = () => {
    setAmount(tab === "deposit" ? maxDeposit.toString() : maxWithdraw.toString());
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    console.log(`${tab}:`, amount);
    // Handle deposit/withdraw logic here
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">ERC-4626 Vault</h1>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Deposit/Withdraw Form */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-lg shadow">
              {/* Tabs */}
              <div className="border-b border-gray-200">
                <div className="flex">
                  <button
                    onClick={() => setTab("deposit")}
                    className={`flex-1 px-6 py-4 text-center font-semibold ${
                      tab === "deposit"
                        ? "text-blue-600 border-b-2 border-blue-600"
                        : "text-gray-600 hover:text-gray-900"
                    }`}
                  >
                    Deposit
                  </button>
                  <button
                    onClick={() => setTab("withdraw")}
                    className={`flex-1 px-6 py-4 text-center font-semibold ${
                      tab === "withdraw"
                        ? "text-blue-600 border-b-2 border-blue-600"
                        : "text-gray-600 hover:text-gray-900"
                    }`}
                  >
                    Withdraw
                  </button>
                </div>
              </div>

              {/* Form */}
              <form onSubmit={handleSubmit} className="p-6 space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    {tab === "deposit" ? "Deposit Amount" : "Withdraw Amount"}
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      placeholder="0.0"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      step="0.01"
                      min="0"
                      max={tab === "deposit" ? maxDeposit : maxWithdraw}
                    />
                    <button
                      type="button"
                      onClick={handleMax}
                      className="absolute right-3 top-1/2 -translate-y-1/2 px-3 py-1 bg-blue-100 text-blue-600 rounded text-sm font-medium hover:bg-blue-200"
                    >
                      MAX
                    </button>
                  </div>
                  <p className="mt-2 text-sm text-gray-600">
                    Available: {tab === "deposit" ? maxDeposit : maxWithdraw} stETH
                  </p>
                </div>

                {/* Conversion Info */}
                {amount && parseFloat(amount) > 0 && (
                  <div className="bg-gray-50 rounded-lg p-4 space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">
                        {tab === "deposit" ? "You will receive" : "You will receive"}
                      </span>
                      <span className="font-semibold text-gray-900">
                        {tab === "deposit"
                          ? `≈ ${(parseFloat(amount) / vaultStats.sharePrice).toFixed(4)} bstETH`
                          : `≈ ${(parseFloat(amount) * vaultStats.sharePrice).toFixed(4)} stETH`}
                      </span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">Share Price</span>
                      <span className="font-semibold text-gray-900">
                        1 bstETH = {vaultStats.sharePrice} stETH
                      </span>
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  className="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors"
                >
                  {tab === "deposit" ? "Deposit" : "Withdraw"}
                </button>

                <p className="text-xs text-gray-500 text-center">
                  Connect your wallet to interact with the vault
                </p>
              </form>
            </div>
          </div>

          {/* Vault Stats */}
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Vault Stats</h3>
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-gray-600">Total Value Locked</p>
                  <p className="text-2xl font-bold text-gray-900">
                    ${vaultStats.totalDeposits.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Current APY</p>
                  <p className="text-2xl font-bold text-green-600">{vaultStats.apy}%</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Share Price</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {vaultStats.sharePrice} stETH
                  </p>
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Your Position</h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-600">Deposited</span>
                  <span className="font-semibold text-gray-900">
                    {vaultStats.yourDeposits.toLocaleString()} stETH
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Your Shares</span>
                  <span className="font-semibold text-gray-900">
                    {vaultStats.yourShares.toLocaleString()} bstETH
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Current Value</span>
                  <span className="font-semibold text-green-600">
                    ${(vaultStats.yourShares * vaultStats.sharePrice).toLocaleString()}
                  </span>
                </div>
              </div>
            </div>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <p className="text-sm text-blue-800">
                <strong>ERC-4626 Standard:</strong> This vault implements the tokenized vault standard,
                allowing you to earn yield while maintaining liquidity through tradeable shares.
              </p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
