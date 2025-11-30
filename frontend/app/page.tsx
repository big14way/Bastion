"use client";

import Navigation from "@/components/Navigation";
import { useBasketComposition, useInsuranceCoverage, useDynamicFee } from "@/hooks";

export default function Dashboard() {
  // Fetch real-time blockchain data
  const { assets: basketAssets, totalValue } = useBasketComposition();
  const { coverageRatio, poolBalance } = useInsuranceCoverage();
  const { volatility, feeRate, feeTier } = useDynamicFee();

  // Mock APY for now - would calculate from actual fee revenue
  const apy = 12.5;
  const insuranceCoverage = coverageRatio || 85;

  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Dashboard</h1>

        {/* Key Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 mb-1">Total Value Locked</p>
            <p className="text-3xl font-bold text-gray-900">
              ${totalValue.toLocaleString()}
            </p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 mb-1">Current APY</p>
            <p className="text-3xl font-bold text-green-600">{apy}%</p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 mb-1">Insurance Coverage</p>
            <p className="text-3xl font-bold text-blue-600">{insuranceCoverage}%</p>
          </div>
        </div>

        {/* Basket Composition */}
        <div className="bg-white rounded-lg shadow mb-8">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-xl font-semibold text-gray-900">Basket Composition</h2>
          </div>
          <div className="p-6">
            <div className="space-y-4">
              {basketAssets.map((asset) => (
                <div key={asset.symbol} className="flex items-center justify-between">
                  <div className="flex items-center space-x-4">
                    <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white font-bold">
                      {asset.symbol.charAt(0)}
                    </div>
                    <div>
                      <p className="font-semibold text-gray-900">{asset.name}</p>
                      <p className="text-sm text-gray-600">{asset.symbol}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-semibold text-gray-900">{asset.weight}%</p>
                    <p className="text-sm text-gray-600">${asset.value.toLocaleString()}</p>
                  </div>
                </div>
              ))}
            </div>

            {/* Composition Bar */}
            <div className="mt-6">
              <div className="flex h-4 rounded-full overflow-hidden">
                {basketAssets.map((asset, index) => (
                  <div
                    key={asset.symbol}
                    style={{ width: `${asset.weight}%` }}
                    className={`${
                      index === 0 ? "bg-blue-500" :
                      index === 1 ? "bg-purple-500" :
                      index === 2 ? "bg-pink-500" :
                      "bg-orange-500"
                    }`}
                  />
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Risk Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Dynamic Fee Tier</h3>
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-gray-600">Current Volatility</span>
                <span className="font-semibold text-gray-900">
                  {volatility.toFixed(2)}%
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-600">Fee Tier</span>
                <span className={`font-semibold ${
                  feeTier === "LOW" ? "text-green-600" :
                  feeTier === "MEDIUM" ? "text-yellow-600" :
                  "text-red-600"
                }`}>
                  {feeTier} ({feeRate.toFixed(2)}%)
                </span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div className={`h-2 rounded-full ${
                  feeTier === "LOW" ? "bg-green-500" :
                  feeTier === "MEDIUM" ? "bg-yellow-500" :
                  "bg-red-500"
                }`} style={{ width: `${Math.min(volatility * 2, 100)}%` }}></div>
              </div>
              <p className="text-sm text-gray-500">
                Fees automatically adjust based on market volatility (0.05% - 1.00%)
              </p>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Insurance Pool Status</h3>
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-gray-600">Pool Balance</span>
                <span className="font-semibold text-gray-900">
                  ${poolBalance.toLocaleString()}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-600">Coverage Ratio</span>
                <span className="font-semibold text-blue-600">
                  {coverageRatio.toFixed(0)}%
                </span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div className="bg-blue-500 h-2 rounded-full" style={{ width: `${coverageRatio}%` }}></div>
              </div>
              <p className="text-sm text-gray-500">
                Protected against depeg events exceeding 20% threshold
              </p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
