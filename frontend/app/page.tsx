"use client";

import Navigation from "@/components/Navigation";
import DemoSimulation from "@/components/DemoSimulation";
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
    <div className="min-h-screen">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Hero Section */}
        <div className="mb-12">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-white via-indigo-200 to-purple-200 bg-clip-text text-transparent">
            Dashboard
          </h1>
          <p className="text-gray-400 text-lg">Monitor your protocol metrics and AVS performance</p>
        </div>

        {/* Key Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-4">
              <p className="text-sm text-gray-400 font-medium">Total Value Locked</p>
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500/20 to-cyan-500/20 flex items-center justify-center">
                <span className="text-2xl">💎</span>
              </div>
            </div>
            <p className="text-4xl font-bold text-white mb-2">
              ${totalValue.toLocaleString()}
            </p>
            <div className="flex items-center space-x-2 text-sm">
              <span className="text-green-400">+12.5%</span>
              <span className="text-gray-500">vs last month</span>
            </div>
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-4">
              <p className="text-sm text-gray-400 font-medium">Current APY</p>
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-green-500/20 to-emerald-500/20 flex items-center justify-center">
                <span className="text-2xl">📈</span>
              </div>
            </div>
            <p className="text-4xl font-bold bg-gradient-to-r from-green-400 to-emerald-400 bg-clip-text text-transparent mb-2">
              {apy}%
            </p>
            <div className="flex items-center space-x-2 text-sm">
              <span className="text-green-400">+2.3%</span>
              <span className="text-gray-500">from fees</span>
            </div>
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-4">
              <p className="text-sm text-gray-400 font-medium">Insurance Coverage</p>
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500/20 to-pink-500/20 flex items-center justify-center">
                <span className="text-2xl">🛡️</span>
              </div>
            </div>
            <p className="text-4xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent mb-2">
              {insuranceCoverage}%
            </p>
            <div className="flex items-center space-x-2 text-sm">
              <span className="text-purple-400">Protected</span>
              <span className="text-gray-500">by AVS</span>
            </div>
          </div>
        </div>

        {/* Basket Composition */}
        <div className="glass rounded-2xl border border-white/10 mb-8 overflow-hidden">
          <div className="px-8 py-6 border-b border-white/10 bg-gradient-to-r from-indigo-500/10 to-purple-500/10">
            <h2 className="text-2xl font-bold text-white">Basket Composition</h2>
            <p className="text-gray-400 text-sm mt-1">Multi-asset portfolio distribution</p>
          </div>
          <div className="p-8">
            <div className="space-y-4">
              {basketAssets.map((asset, index) => (
                <div key={asset.symbol} className="glass-hover p-4 rounded-xl border border-white/5 transition-all">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-4">
                      <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-white font-bold text-lg shadow-lg ${
                        index === 0 ? "bg-gradient-to-br from-blue-500 to-cyan-500" :
                        index === 1 ? "bg-gradient-to-br from-purple-500 to-pink-500" :
                        index === 2 ? "bg-gradient-to-br from-pink-500 to-rose-500" :
                        "bg-gradient-to-br from-orange-500 to-amber-500"
                      }`}>
                        {asset.symbol.charAt(0)}
                      </div>
                      <div>
                        <p className="font-bold text-white text-lg">{asset.name}</p>
                        <p className="text-sm text-gray-400">{asset.symbol}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-bold text-white text-xl">{asset.weight}%</p>
                      <p className="text-sm text-gray-400">${asset.value.toLocaleString()}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* Composition Bar */}
            <div className="mt-8">
              <div className="flex h-3 rounded-full overflow-hidden shadow-lg">
                {basketAssets.map((asset, index) => (
                  <div
                    key={asset.symbol}
                    style={{ width: `${asset.weight}%` }}
                    className={`transition-all hover:opacity-80 ${
                      index === 0 ? "bg-gradient-to-r from-blue-500 to-cyan-500" :
                      index === 1 ? "bg-gradient-to-r from-purple-500 to-pink-500" :
                      index === 2 ? "bg-gradient-to-r from-pink-500 to-rose-500" :
                      "bg-gradient-to-r from-orange-500 to-amber-500"
                    }`}
                  />
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Risk Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div className="glass rounded-2xl p-8 border border-white/10">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold text-white">Dynamic Fee Tier</h3>
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-yellow-500/20 to-orange-500/20 flex items-center justify-center">
                <span className="text-2xl">⚡</span>
              </div>
            </div>
            <div className="space-y-4">
              <div className="flex justify-between items-center p-3 rounded-xl bg-white/5">
                <span className="text-gray-300 font-medium">Current Volatility</span>
                <span className="font-bold text-white text-lg">
                  {volatility.toFixed(2)}%
                </span>
              </div>
              <div className="flex justify-between items-center p-3 rounded-xl bg-white/5">
                <span className="text-gray-300 font-medium">Fee Tier</span>
                <span className={`font-bold text-lg px-3 py-1 rounded-lg ${
                  feeTier === "LOW" ? "bg-green-500/20 text-green-400" :
                  feeTier === "MEDIUM" ? "bg-yellow-500/20 text-yellow-400" :
                  "bg-red-500/20 text-red-400"
                }`}>
                  {feeTier} ({feeRate.toFixed(2)}%)
                </span>
              </div>
              <div className="mt-4">
                <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
                  <div className={`h-3 rounded-full transition-all ${
                    feeTier === "LOW" ? "bg-gradient-to-r from-green-500 to-emerald-500" :
                    feeTier === "MEDIUM" ? "bg-gradient-to-r from-yellow-500 to-orange-500" :
                    "bg-gradient-to-r from-red-500 to-rose-500"
                  }`} style={{ width: `${Math.min(volatility * 2, 100)}%` }}></div>
                </div>
              </div>
              <p className="text-sm text-gray-400 mt-4 leading-relaxed">
                Fees automatically adjust based on market volatility (0.05% - 1.00%)
              </p>
            </div>
          </div>

          <div className="glass rounded-2xl p-8 border border-white/10">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold text-white">AVS Insurance Pool</h3>
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center">
                <span className="text-2xl">🛡️</span>
              </div>
            </div>
            <div className="space-y-4">
              <div className="flex justify-between items-center p-3 rounded-xl bg-white/5">
                <span className="text-gray-300 font-medium">Pool Balance</span>
                <span className="font-bold text-white text-lg">
                  ${poolBalance.toLocaleString()}
                </span>
              </div>
              <div className="flex justify-between items-center p-3 rounded-xl bg-white/5">
                <span className="text-gray-300 font-medium">Coverage Ratio</span>
                <span className="font-bold text-indigo-400 text-lg">
                  {coverageRatio.toFixed(0)}%
                </span>
              </div>
              <div className="mt-4">
                <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
                  <div className="bg-gradient-to-r from-indigo-500 to-purple-500 h-3 rounded-full transition-all" style={{ width: `${coverageRatio}%` }}></div>
                </div>
              </div>
              <p className="text-sm text-gray-400 mt-4 leading-relaxed">
                Protected by EigenLayer AVS against depeg events exceeding 20% threshold
              </p>
            </div>
          </div>
        </div>
      </main>

      {/* Demo Simulation Component */}
      <DemoSimulation />
    </div>
  );
}
