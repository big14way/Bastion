"use client";

import Navigation from "@/components/Navigation";

export default function Insurance() {
  const insuranceStats = {
    totalCoverage: 85000,
    yourCoverage: 4250,
    poolBalance: 8500,
    coverageRatio: 85,
    depegThreshold: 20,
  };

  const recentClaims = [
    {
      id: 1,
      asset: "USDe",
      date: "2024-11-15",
      depegAmount: 25,
      payout: 2500,
      status: "Paid",
    },
    {
      id: 2,
      asset: "stETH",
      date: "2024-10-28",
      depegAmount: 22,
      payout: 1800,
      status: "Paid",
    },
    {
      id: 3,
      asset: "cbETH",
      date: "2024-09-12",
      depegAmount: 21,
      payout: 1200,
      status: "Paid",
    },
  ];

  const coveredAssets = [
    {
      name: "stETH",
      currentPrice: 1.0,
      targetPrice: 1.0,
      deviation: 0,
      status: "healthy",
    },
    {
      name: "cbETH",
      currentPrice: 1.0,
      targetPrice: 1.0,
      deviation: 0,
      status: "healthy",
    },
    {
      name: "rETH",
      currentPrice: 1.0,
      targetPrice: 1.0,
      deviation: 0,
      status: "healthy",
    },
    {
      name: "USDe",
      currentPrice: 1.0,
      targetPrice: 1.0,
      deviation: 0,
      status: "healthy",
    },
  ];

  const getStatusColor = (status: string) => {
    switch (status) {
      case "healthy":
        return "text-green-400 bg-green-500/20 border-green-500/30";
      case "warning":
        return "text-yellow-400 bg-yellow-500/20 border-yellow-500/30";
      case "depegged":
        return "text-red-400 bg-red-500/20 border-red-500/30";
      default:
        return "text-gray-400 bg-gray-500/20 border-gray-500/30";
    }
  };

  return (
    <div className="min-h-screen">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Hero Section */}
        <div className="mb-12">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-white via-purple-200 to-pink-200 bg-clip-text text-transparent">
            Insurance Coverage
          </h1>
          <p className="text-gray-400 text-lg">AVS-secured protection against depeg events for all basket assets</p>
        </div>

        {/* Coverage Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Total Coverage</p>
              <span className="text-2xl">🛡️</span>
            </div>
            <p className="text-3xl font-bold text-white">
              ${insuranceStats.totalCoverage.toLocaleString()}
            </p>
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Your Coverage</p>
              <span className="text-2xl">👤</span>
            </div>
            <p className="text-3xl font-bold bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">
              ${insuranceStats.yourCoverage.toLocaleString()}
            </p>
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Pool Balance</p>
              <span className="text-2xl">💰</span>
            </div>
            <p className="text-3xl font-bold text-green-400">
              ${insuranceStats.poolBalance.toLocaleString()}
            </p>
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Coverage Ratio</p>
              <span className="text-2xl">📊</span>
            </div>
            <p className="text-3xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
              {insuranceStats.coverageRatio}%
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Covered Assets & Claims */}
          <div className="lg:col-span-2 space-y-6">
            {/* Covered Assets */}
            <div className="glass rounded-2xl border border-white/10 overflow-hidden">
              <div className="px-8 py-6 border-b border-white/10 bg-gradient-to-r from-purple-500/10 to-pink-500/10">
                <h2 className="text-2xl font-bold text-white">Covered Assets</h2>
                <p className="text-gray-400 text-sm mt-1">Real-time monitoring of all basket assets</p>
              </div>
              <div className="p-6">
                <div className="space-y-4">
                  {coveredAssets.map((asset, index) => (
                    <div
                      key={asset.name}
                      className="flex items-center justify-between p-5 glass-hover rounded-xl border border-white/10"
                    >
                      <div className="flex items-center space-x-4">
                        <div className={`w-14 h-14 rounded-xl flex items-center justify-center text-white font-bold text-xl shadow-lg ${
                          index === 0 ? "bg-gradient-to-br from-blue-500 to-cyan-500" :
                          index === 1 ? "bg-gradient-to-br from-purple-500 to-pink-500" :
                          index === 2 ? "bg-gradient-to-br from-pink-500 to-rose-500" :
                          "bg-gradient-to-br from-orange-500 to-amber-500"
                        }`}>
                          {asset.name.charAt(0)}
                        </div>
                        <div>
                          <p className="font-bold text-white text-lg">{asset.name}</p>
                          <p className="text-sm text-gray-400">
                            Price: <span className="text-white">${asset.currentPrice.toFixed(2)}</span>
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <span
                          className={`px-4 py-2 rounded-lg text-sm font-bold border ${getStatusColor(
                            asset.status
                          )}`}
                        >
                          {asset.status.toUpperCase()}
                        </span>
                        <p className="text-sm text-gray-400 mt-2">
                          Deviation: <span className="text-white font-semibold">{asset.deviation}%</span>
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Recent Claims */}
            <div className="glass rounded-2xl border border-white/10 overflow-hidden">
              <div className="px-8 py-6 border-b border-white/10 bg-gradient-to-r from-green-500/10 to-emerald-500/10">
                <h2 className="text-2xl font-bold text-white">Recent Claims</h2>
                <p className="text-gray-400 text-sm mt-1">Historical depeg events and payouts</p>
              </div>
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-white/10">
                  <thead className="bg-white/5">
                    <tr>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">
                        Asset
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">
                        Date
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">
                        Depeg %
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">
                        Payout
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-400 uppercase tracking-wider">
                        Status
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/10">
                    {recentClaims.map((claim) => (
                      <tr key={claim.id} className="hover:bg-white/5 transition-colors">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="font-bold text-white">{claim.asset}</span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-400">
                          {claim.date}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="text-red-400 font-bold">{claim.depegAmount}%</span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-white font-semibold">
                          ${claim.payout.toLocaleString()}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="px-3 py-1 inline-flex text-xs leading-5 font-bold rounded-lg bg-green-500/20 text-green-400 border border-green-500/30">
                            {claim.status}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          {/* Coverage Details Sidebar */}
          <div className="space-y-6">
            <div className="glass glass-hover rounded-2xl p-8 border border-white/10">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-white">Coverage Details</h3>
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500/20 to-pink-500/20 flex items-center justify-center">
                  <span className="text-2xl">ℹ️</span>
                </div>
              </div>
              <div className="space-y-6">
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-2">Depeg Threshold</p>
                  <p className="text-3xl font-bold text-white mb-2">
                    {insuranceStats.depegThreshold}%
                  </p>
                  <p className="text-xs text-gray-500 leading-relaxed">
                    Protection triggers when asset depegs beyond this threshold
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-3">Coverage Ratio</p>
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-2xl font-bold text-white">
                      {insuranceStats.coverageRatio}%
                    </span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
                    <div
                      className="bg-gradient-to-r from-purple-500 to-pink-500 h-3 rounded-full transition-all"
                      style={{ width: `${insuranceStats.coverageRatio}%` }}
                    ></div>
                  </div>
                </div>

                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-2">Premium Rate</p>
                  <p className="text-xl font-bold text-white mb-1">10% of Fees</p>
                  <p className="text-xs text-gray-500 leading-relaxed">
                    Automatically deducted from swap fees
                  </p>
                </div>
              </div>
            </div>

            <div className="glass rounded-2xl p-6 border border-indigo-500/30 bg-gradient-to-br from-indigo-500/10 to-purple-500/10">
              <div className="flex items-start space-x-3">
                <div className="w-10 h-10 rounded-lg bg-indigo-500/20 flex items-center justify-center flex-shrink-0">
                  <span className="text-2xl">🔒</span>
                </div>
                <div>
                  <h3 className="font-bold text-indigo-400 mb-2 text-lg">AVS Consensus</h3>
                  <p className="text-sm text-gray-300 leading-relaxed">
                    Insurance payouts require consensus from EigenLayer AVS operators, ensuring
                    verified depeg events before processing claims. This dual validation (AVS + Chainlink)
                    prevents false claims.
                  </p>
                </div>
              </div>
            </div>

            <div className="glass rounded-2xl p-6 border border-green-500/30 bg-gradient-to-br from-green-500/10 to-emerald-500/10">
              <div className="flex items-start space-x-3">
                <div className="w-10 h-10 rounded-lg bg-green-500/20 flex items-center justify-center flex-shrink-0">
                  <span className="text-2xl">✓</span>
                </div>
                <div>
                  <h3 className="font-bold text-green-400 mb-3 text-lg">How It Works</h3>
                  <ul className="text-sm text-gray-300 space-y-2">
                    <li className="flex items-center space-x-2">
                      <span className="text-green-400">•</span>
                      <span>10% of swap fees fund insurance pool</span>
                    </li>
                    <li className="flex items-center space-x-2">
                      <span className="text-green-400">•</span>
                      <span>Automatic protection for all LPs</span>
                    </li>
                    <li className="flex items-center space-x-2">
                      <span className="text-green-400">•</span>
                      <span>Pro-rata payout distribution</span>
                    </li>
                    <li className="flex items-center space-x-2">
                      <span className="text-green-400">•</span>
                      <span>No additional premium required</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
