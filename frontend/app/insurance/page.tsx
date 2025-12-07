"use client";

import Navigation from "@/components/Navigation";
import { useInsurance, usePayoutDetails } from "@/hooks/useInsurance";
import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useEffect, useState } from "react";
import { CONTRACTS } from "@/lib/contracts/addresses";

export default function Insurance() {
  const { isConnected } = useAccount();
  const {
    poolBalance,
    totalLPShares,
    coverageRatio,
    stETHBalance,
    usdcBalance,
    userCoverage,
    userShares,
    hasInsurance,
    payoutCount,
    assetCount,
    isLoading,
    isError,
    fetchPayoutHistory,
    claimPayout,
    isClaimPending,
    isClaimConfirming,
    isClaimConfirmed,
    claimTxHash,
  } = useInsurance();

  // Fetch detailed payout information
  const { payouts, isLoading: isPayoutsLoading, refetch: refetchPayouts } = usePayoutDetails(payoutCount);

  const [payoutHistory, setPayoutHistory] = useState<any[]>([]);

  // Fetch asset and payout details
  useEffect(() => {
    const loadDetails = async () => {
      const payouts = await fetchPayoutHistory();
      setPayoutHistory(payouts);
    };
    loadDetails();
  }, [assetCount, payoutCount]);

  // Refetch payout details when claim is confirmed
  useEffect(() => {
    if (isClaimConfirmed) {
      // Refetch payout details with delays
      setTimeout(() => refetchPayouts(), 1000);
      setTimeout(() => refetchPayouts(), 3000);
      setTimeout(() => refetchPayouts(), 6000);
    }
  }, [isClaimConfirmed, refetchPayouts]);

  // Mock data for recent claims and covered assets (can be replaced with real data later)
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

  const depegThreshold = 20; // Default 20%

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

        {/* Connect Wallet Message */}
        {!isConnected && (
          <div className="glass rounded-2xl p-6 mb-8 border border-yellow-500/30 bg-yellow-500/10">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xl font-bold text-yellow-400 mb-2">Connect Wallet</h3>
                <p className="text-gray-400">Connect your wallet to view your insurance coverage</p>
              </div>
              <ConnectButton />
            </div>
          </div>
        )}

        {/* Coverage Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Total Coverage</p>
              <span className="text-2xl">🛡️</span>
            </div>
            <p className="text-3xl font-bold text-white">
              {isLoading ? (
                <span className="text-gray-500">Loading...</span>
              ) : isError ? (
                <span className="text-red-500">Error</span>
              ) : (
                `${totalLPShares.toFixed(2)} LP`
              )}
            </p>
            <p className="text-xs text-gray-500 mt-1">Total LP shares protected</p>
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Your Coverage</p>
              <span className="text-2xl">👤</span>
            </div>
            {!isConnected ? (
              <p className="text-sm text-gray-500">Connect wallet</p>
            ) : (
              <>
                <p className="text-3xl font-bold bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">
                  ${userCoverage.toFixed(2)}
                </p>
                {hasInsurance && (
                  <p className="text-xs text-green-400 mt-1">✓ Protected</p>
                )}
                {userShares > 0 && (
                  <p className="text-xs text-gray-500 mt-1">{userShares.toFixed(4)} shares</p>
                )}
              </>
            )}
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Pool Balance</p>
              <span className="text-2xl">💰</span>
            </div>
            <p className="text-3xl font-bold text-green-400">
              {isLoading ? (
                <span className="text-gray-500">Loading...</span>
              ) : (
                `$${poolBalance.toFixed(2)}`
              )}
            </p>
            <div className="mt-3 space-y-1">
              <p className="text-xs text-gray-400">Collected Premiums:</p>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">stETH:</span>
                <span className="text-green-400 font-semibold">{stETHBalance.toFixed(4)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">USDC:</span>
                <span className="text-green-400 font-semibold">{usdcBalance.toFixed(4)}</span>
              </div>
            </div>
            <p className="text-xs text-gray-500 mt-2">
              {(stETHBalance + usdcBalance) > 0 ? "Available for payouts" : "Awaiting premium deposits"}
            </p>
          </div>

          <div className="glass glass-hover rounded-2xl p-6 border border-white/10">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm text-gray-400 font-medium">Coverage Ratio</p>
              <span className="text-2xl">📊</span>
            </div>
            <p className="text-3xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
              {coverageRatio.toFixed(1)}%
            </p>
            {payoutCount > 0 && (
              <p className="text-xs text-gray-500 mt-1">{payoutCount} payouts made</p>
            )}
          </div>
        </div>

        {/* Claim Payouts Section */}
        {isConnected && userShares > 0 && payoutCount > 0 && (
          <div className="mb-8">
            <div className="glass rounded-2xl border border-white/10 overflow-hidden">
              <div className="px-8 py-6 border-b border-white/10 bg-gradient-to-r from-green-500/10 to-emerald-500/10">
                <h2 className="text-2xl font-bold text-white">Claim Insurance Payouts</h2>
                <p className="text-gray-400 text-sm mt-1">
                  You have {payoutCount} payout event{payoutCount > 1 ? 's' : ''} available to claim
                </p>
              </div>
              <div className="p-8">
                <div className="space-y-4">
                  {/* Map through actual payouts from contract */}
                  {isPayoutsLoading ? (
                    <div className="text-center py-8 text-gray-400">Loading payout details...</div>
                  ) : payouts.length > 0 ? (
                    payouts.slice(0, 5).map((payout) => (
                      <div
                        key={payout.index}
                        className={`glass-hover rounded-xl p-6 border ${
                          payout.hasClaimed
                            ? "border-green-500/30 bg-green-500/5"
                            : "border-white/10"
                        } flex items-center justify-between`}
                      >
                        <div className="flex-1">
                          <div className="flex items-center gap-3 mb-2">
                            <h3 className="font-bold text-white text-lg">
                              Payout Event #{payout.index}
                            </h3>
                            {payout.hasClaimed && (
                              <span className="px-3 py-1 bg-green-500/20 text-green-400 text-xs font-semibold rounded-full">
                                ✓ Claimed
                              </span>
                            )}
                          </div>
                          <p className="text-sm text-gray-400">
                            {payout.hasClaimed
                              ? "You've successfully claimed this payout"
                              : "Depeg event detected - claim your pro-rata share"}
                          </p>
                          <div className="mt-3 flex items-center space-x-4 text-sm">
                            <span className="text-gray-400">
                              Your claimable:{" "}
                              <span className="text-green-400 font-semibold">
                                {payout.claimableAmount.toFixed(6)} USDC
                              </span>
                            </span>
                            <span className="text-gray-400">•</span>
                            <span className="text-gray-400">
                              Deviation:{" "}
                              <span className="text-orange-400 font-semibold">
                                {(payout.deviation / 100).toFixed(1)}%
                              </span>
                            </span>
                            <span className="text-gray-400">•</span>
                            <span className="text-gray-400">
                              Total pool payout:{" "}
                              <span className="text-white font-semibold">
                                {payout.totalPayout.toFixed(2)} USDC
                              </span>
                            </span>
                          </div>
                        </div>
                        <button
                          onClick={() => claimPayout(payout.index)}
                          disabled={payout.hasClaimed || isClaimPending || isClaimConfirming || payout.claimableAmount === 0}
                          className="px-6 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white rounded-xl font-bold hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg shadow-green-500/20 hover:shadow-green-500/40 disabled:from-gray-600 disabled:to-gray-700 disabled:cursor-not-allowed disabled:shadow-none"
                        >
                          {payout.hasClaimed
                            ? "Claimed"
                            : isClaimPending || isClaimConfirming
                            ? "Claiming..."
                            : payout.claimableAmount === 0
                            ? "No Claim"
                            : "Claim Payout"}
                        </button>
                      </div>
                    ))
                  ) : (
                    <div className="text-center py-8 text-gray-400">No payouts available</div>
                  )}
                </div>

                {/* Success message */}
                {isClaimConfirmed && claimTxHash && (
                  <div className="mt-6 glass rounded-xl p-4 border border-green-500/30 bg-green-500/10 space-y-2">
                    <p className="text-sm text-green-400 text-center">
                      ✅ Claim successful! Your payout has been transferred to your wallet.
                    </p>
                    <a
                      href={`https://sepolia.basescan.org/tx/${claimTxHash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block text-center text-xs text-blue-400 hover:text-blue-300 underline"
                    >
                      View on BaseScan →
                    </a>
                  </div>
                )}

                {/* Processing message */}
                {(isClaimPending || isClaimConfirming) && (
                  <div className="mt-6 glass rounded-xl p-4 border border-blue-500/30 bg-blue-500/10">
                    <p className="text-sm text-blue-400 text-center">
                      Processing claim... Transaction is being confirmed on the blockchain.
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* No claims message */}
        {isConnected && userShares > 0 && payoutCount === 0 && (
          <div className="mb-8">
            <div className="glass rounded-2xl p-6 border border-blue-500/30 bg-blue-500/10">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">✓</span>
                <div>
                  <h3 className="font-bold text-blue-400 mb-1">No Claims Available</h3>
                  <p className="text-sm text-gray-300">
                    You have {userShares.toFixed(4)} LP shares protected. Claims will appear here when depeg events occur.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

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
                {assetCount > 0 ? (
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
                ) : (
                  <div className="py-12 text-center">
                    <div className="flex flex-col items-center space-y-3">
                      <div className="w-16 h-16 rounded-full bg-gray-800 flex items-center justify-center">
                        <span className="text-3xl">📊</span>
                      </div>
                      <p className="text-gray-400 font-medium">Monitoring System Active</p>
                      <p className="text-sm text-gray-500 max-w-md">
                        Assets will be configured and monitored via Chainlink price feeds once deployed to mainnet
                      </p>
                      <div className="mt-4 flex items-center space-x-2 text-xs text-gray-500">
                        <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></span>
                        <span>Real-time monitoring ready</span>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Recent Claims */}
            <div className="glass rounded-2xl border border-white/10 overflow-hidden">
              <div className="px-8 py-6 border-b border-white/10 bg-gradient-to-r from-green-500/10 to-emerald-500/10">
                <h2 className="text-2xl font-bold text-white">Recent Claims</h2>
                <p className="text-gray-400 text-sm mt-1">
                  {payoutCount > 0 ? `${payoutCount} total payouts processed` : "No depeg events recorded on-chain"}
                </p>
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
                    {payoutCount > 0 && payoutHistory.length > 0 ? (
                      payoutHistory.map((payout, idx) => (
                        <tr key={idx} className="hover:bg-white/5 transition-colors">
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span className="font-bold text-white">{payout.asset}</span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-400">
                            {new Date(payout.timestamp).toLocaleDateString()}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span className="text-red-400 font-bold">{payout.deviation}%</span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-white font-semibold">
                            ${payout.payout.toLocaleString()}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span className="px-3 py-1 inline-flex text-xs leading-5 font-bold rounded-lg bg-green-500/20 text-green-400 border border-green-500/30">
                              Paid
                            </span>
                          </td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan={5} className="px-6 py-12 text-center">
                          <div className="flex flex-col items-center space-y-3">
                            <div className="w-16 h-16 rounded-full bg-gray-800 flex items-center justify-center">
                              <span className="text-3xl">✅</span>
                            </div>
                            <p className="text-gray-400 font-medium">No depeg events recorded</p>
                            <p className="text-sm text-gray-500 max-w-md">
                              The insurance pool is ready to protect LPs when basket assets depeg beyond 20% threshold
                            </p>
                          </div>
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          {/* Coverage Details Sidebar */}
          <div className="space-y-6">
            {/* On-chain Data Indicator */}
            <div className="glass rounded-xl p-4 border border-blue-500/30 bg-blue-500/10">
              <div className="flex items-center space-x-3">
                <div className="w-2 h-2 bg-blue-400 rounded-full animate-pulse"></div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-blue-400">
                    {isLoading ? "Fetching on-chain data..." : "Live on Base Sepolia"}
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    Contract: {CONTRACTS.InsuranceTranche.slice(0, 10)}...
                  </p>
                </div>
              </div>
            </div>

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
                    {depegThreshold}%
                  </p>
                  <p className="text-xs text-gray-500 leading-relaxed">
                    Protection triggers when asset depegs beyond this threshold
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-3">Coverage Ratio</p>
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-2xl font-bold text-white">
                      {coverageRatio.toFixed(1)}%
                    </span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
                    <div
                      className="bg-gradient-to-r from-purple-500 to-pink-500 h-3 rounded-full transition-all"
                      style={{ width: `${Math.min(coverageRatio, 100)}%` }}
                    ></div>
                  </div>
                  <p className="text-xs text-gray-500 mt-2">
                    Pool balance relative to total coverage
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-2">Premium Rate</p>
                  <p className="text-xl font-bold text-white mb-1">20% of Fees</p>
                  <p className="text-xs text-gray-500 leading-relaxed">
                    Automatically collected from swap fees via Uniswap V4 hooks
                  </p>
                </div>

                {isConnected && userShares > 0 && (
                  <div className="p-4 rounded-xl bg-gradient-to-br from-blue-500/10 to-cyan-500/10 border border-blue-500/30">
                    <p className="text-sm text-blue-400 mb-2">Your Position</p>
                    <p className="text-lg font-bold text-white mb-1">{userShares.toFixed(4)} LP Shares</p>
                    <p className="text-sm font-semibold text-cyan-400">${userCoverage.toFixed(2)} Coverage</p>
                    <p className="text-xs text-gray-400 mt-2">
                      {hasInsurance ? "✓ Actively protected" : "Position registered"}
                    </p>
                  </div>
                )}
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
                      <span>20% of swap fees fund insurance pool</span>
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