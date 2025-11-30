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
        return "text-green-600 bg-green-100";
      case "warning":
        return "text-yellow-600 bg-yellow-100";
      case "depegged":
        return "text-red-600 bg-red-100";
      default:
        return "text-gray-600 bg-gray-100";
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Insurance Coverage</h1>

        {/* Coverage Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 mb-1">Total Coverage</p>
            <p className="text-2xl font-bold text-gray-900">
              ${insuranceStats.totalCoverage.toLocaleString()}
            </p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 mb-1">Your Coverage</p>
            <p className="text-2xl font-bold text-blue-600">
              ${insuranceStats.yourCoverage.toLocaleString()}
            </p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 mb-1">Pool Balance</p>
            <p className="text-2xl font-bold text-green-600">
              ${insuranceStats.poolBalance.toLocaleString()}
            </p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 mb-1">Coverage Ratio</p>
            <p className="text-2xl font-bold text-purple-600">
              {insuranceStats.coverageRatio}%
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Covered Assets */}
          <div className="lg:col-span-2 space-y-6">
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <h2 className="text-xl font-semibold text-gray-900">Covered Assets</h2>
              </div>
              <div className="p-6">
                <div className="space-y-4">
                  {coveredAssets.map((asset) => (
                    <div
                      key={asset.name}
                      className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                    >
                      <div className="flex items-center space-x-4">
                        <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white font-bold text-lg">
                          {asset.name.charAt(0)}
                        </div>
                        <div>
                          <p className="font-semibold text-gray-900">{asset.name}</p>
                          <p className="text-sm text-gray-600">
                            Price: ${asset.currentPrice.toFixed(2)}
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <span
                          className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(
                            asset.status
                          )}`}
                        >
                          {asset.status.toUpperCase()}
                        </span>
                        <p className="text-sm text-gray-600 mt-1">
                          Deviation: {asset.deviation}%
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Recent Claims */}
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <h2 className="text-xl font-semibold text-gray-900">Recent Claims</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Asset
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Date
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Depeg %
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Payout
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Status
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {recentClaims.map((claim) => (
                      <tr key={claim.id}>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="font-medium text-gray-900">{claim.asset}</span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                          {claim.date}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="text-red-600 font-medium">{claim.depegAmount}%</span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          ${claim.payout.toLocaleString()}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
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

          {/* Coverage Details */}
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Coverage Details</h3>
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-gray-600 mb-2">Depeg Threshold</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {insuranceStats.depegThreshold}%
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    Protection triggers when asset depegs beyond this threshold
                  </p>
                </div>

                <div className="pt-4 border-t border-gray-200">
                  <p className="text-sm text-gray-600 mb-2">Coverage Ratio</p>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-lg font-semibold text-gray-900">
                      {insuranceStats.coverageRatio}%
                    </span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className="bg-blue-500 h-2 rounded-full"
                      style={{ width: `${insuranceStats.coverageRatio}%` }}
                    ></div>
                  </div>
                </div>

                <div className="pt-4 border-t border-gray-200">
                  <p className="text-sm text-gray-600 mb-1">Premium Rate</p>
                  <p className="text-lg font-semibold text-gray-900">10% of Fees</p>
                  <p className="text-xs text-gray-500 mt-1">
                    Automatically deducted from swap fees
                  </p>
                </div>
              </div>
            </div>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h3 className="font-semibold text-blue-900 mb-2">AVS Consensus</h3>
              <p className="text-sm text-blue-800">
                Insurance payouts require consensus from EigenLayer AVS operators, ensuring
                verified depeg events before processing claims. This dual validation (AVS + Chainlink)
                prevents false claims.
              </p>
            </div>

            <div className="bg-green-50 border border-green-200 rounded-lg p-4">
              <h3 className="font-semibold text-green-900 mb-2">How It Works</h3>
              <ul className="text-sm text-green-800 space-y-1">
                <li>• 10% of swap fees fund insurance pool</li>
                <li>• Automatic protection for all LPs</li>
                <li>• Pro-rata payout distribution</li>
                <li>• No additional premium required</li>
              </ul>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
