"use client";

import { useState, useEffect } from "react";
import Navigation from "@/components/Navigation";
import { useVault } from "@/hooks";
import { useAccount, useBalance } from "wagmi";

export default function Vault() {
  const [tab, setTab] = useState<"deposit" | "withdraw">("deposit");
  const [amount, setAmount] = useState("");

  const { address } = useAccount();

  // Get vault data from on-chain
  const {
    totalAssets,
    sharePrice,
    userShares,
    userAssets,
    maxWithdrawShares,
    tokenSymbol,
    tokenBalance,
    allowance,
    needsApproval,
    approve,
    deposit,
    withdraw,
    isPending,
    isConfirming,
    isSuccess,
    hash,
  } = useVault();

  // Log transaction hash when available
  useEffect(() => {
    if (hash) {
      console.log("Transaction hash:", hash);
      console.log(`View on BaseScan: https://sepolia.basescan.org/tx/${hash}`);
    }
  }, [hash]);

  const vaultStats = {
    totalDeposits: totalAssets,
    yourDeposits: userAssets,
    yourShares: userShares,
    sharePrice: sharePrice,
    apy: 12.5, // TODO: Calculate from actual fee revenue
  };

  const maxDeposit = tokenBalance || 0;
  const maxWithdraw = maxWithdrawShares || 0;

  const handleMax = () => {
    setAmount(tab === "deposit" ? maxDeposit.toString() : maxWithdraw.toString());
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!amount || parseFloat(amount) <= 0) return;

    try {
      if (tab === "deposit") {
        const result = await deposit(amount);
        // If it was an approval, show message to user
        if (result === "approval") {
          console.log("Approval transaction sent. After confirmation, click deposit again.");
        }
      } else {
        await withdraw(amount);
      }
      // Clear amount after successful transaction
      if (isSuccess) {
        setAmount("");
      }
    } catch (error) {
      console.error("Transaction error:", error);
    }
  };

  // Check if user needs to approve for deposit
  const amountNum = parseFloat(amount) || 0;
  const needsApprove = tab === "deposit" && amountNum > 0 && amountNum > allowance;

  return (
    <div className="min-h-screen">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Hero Section */}
        <div className="mb-12">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-white via-indigo-200 to-purple-200 bg-clip-text text-transparent">
            ERC-4626 Vault
          </h1>
          <p className="text-gray-400 text-lg">Deposit assets and earn yield through secure, tokenized vault shares</p>
        </div>

        {/* Wallet Info Banner - Show if connected but no balance */}
        {address && tokenBalance === 0 && (
          <div className="glass rounded-xl p-6 mb-8 border border-yellow-500/30 bg-yellow-500/5">
            <div className="flex items-start space-x-4">
              <span className="text-2xl">💡</span>
              <div className="flex-1">
                <h3 className="text-lg font-semibold text-yellow-400 mb-2">Get Test Tokens</h3>
                <p className="text-gray-300 mb-3">Your wallet is connected but has no stETH tokens. Run this command to mint 100 test tokens:</p>
                <div className="bg-black/30 rounded-lg p-3 font-mono text-sm text-gray-200 break-all">
                  cd "/Users/user/gwill/web3/ bastion" && source .env && RECIPIENT={address} forge script script/MintToUser.s.sol:MintToUser --rpc-url https://sepolia.base.org --broadcast
                </div>
                <p className="text-xs text-gray-400 mt-2">Connected wallet: {address}</p>
              </div>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Deposit/Withdraw Form */}
          <div className="lg:col-span-2">
            <div className="glass rounded-2xl border border-white/10 overflow-hidden">
              {/* Tabs */}
              <div className="border-b border-white/10 bg-gradient-to-r from-indigo-500/10 to-purple-500/10">
                <div className="flex">
                  <button
                    onClick={() => setTab("deposit")}
                    className={`flex-1 px-8 py-6 text-center font-semibold transition-all ${
                      tab === "deposit"
                        ? "text-white bg-white/10 border-b-2 border-indigo-400"
                        : "text-gray-400 hover:text-white hover:bg-white/5"
                    }`}
                  >
                    <span className="text-xl mr-2">💰</span>
                    Deposit
                  </button>
                  <button
                    onClick={() => setTab("withdraw")}
                    className={`flex-1 px-8 py-6 text-center font-semibold transition-all ${
                      tab === "withdraw"
                        ? "text-white bg-white/10 border-b-2 border-purple-400"
                        : "text-gray-400 hover:text-white hover:bg-white/5"
                    }`}
                  >
                    <span className="text-xl mr-2">💸</span>
                    Withdraw
                  </button>
                </div>
              </div>

              {/* Form */}
              <form onSubmit={handleSubmit} className="p-8 space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-3">
                    {tab === "deposit" ? "Deposit Amount" : "Withdraw Amount"}
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      placeholder="0.0"
                      className="w-full px-6 py-4 bg-white/5 border border-white/10 rounded-xl text-white text-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
                      step="0.01"
                      min="0"
                    />
                    <button
                      type="button"
                      onClick={handleMax}
                      className="absolute right-4 top-1/2 -translate-y-1/2 px-4 py-2 bg-indigo-500/20 text-indigo-400 rounded-lg text-sm font-semibold hover:bg-indigo-500/30 transition-all border border-indigo-500/30"
                    >
                      MAX
                    </button>
                  </div>
                  <p className="mt-3 text-sm text-gray-400">
                    Available: <span className="text-white font-semibold">{tab === "deposit" ? maxDeposit.toFixed(4) : maxWithdraw.toFixed(4)} {tokenSymbol || "tokens"}</span>
                  </p>
                </div>

                {/* Conversion Info */}
                {amount && parseFloat(amount) > 0 && (
                  <div className="glass-hover rounded-xl p-6 space-y-3 border border-white/10">
                    <div className="flex justify-between items-center">
                      <span className="text-gray-400">
                        {tab === "deposit" ? "You will receive" : "You will receive"}
                      </span>
                      <span className="font-bold text-white text-lg">
                        {tab === "deposit"
                          ? `≈ ${(parseFloat(amount) / vaultStats.sharePrice).toFixed(4)} bstETH`
                          : `≈ ${(parseFloat(amount) * vaultStats.sharePrice).toFixed(4)} ${tokenSymbol || "tokens"}`}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-400">Share Price</span>
                      <span className="font-semibold text-indigo-400">
                        1 bstETH = {vaultStats.sharePrice} {tokenSymbol || "tokens"}
                      </span>
                    </div>
                    {tab === "deposit" && allowance > 0 && (
                      <div className="flex justify-between items-center">
                        <span className="text-gray-400">Current Allowance</span>
                        <span className="font-semibold text-green-400">
                          {allowance.toFixed(4)} {tokenSymbol}
                        </span>
                      </div>
                    )}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={!address || isPending || isConfirming || !amount || parseFloat(amount) <= 0}
                  className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 text-white py-4 rounded-xl font-bold text-lg hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg shadow-indigo-500/20 hover:shadow-indigo-500/40 disabled:from-gray-600 disabled:to-gray-700 disabled:cursor-not-allowed disabled:shadow-none"
                >
                  {isPending
                    ? (needsApprove ? "Approving..." : "Processing...")
                    : isConfirming
                    ? "Confirming..."
                    : isSuccess
                    ? "Success!"
                    : tab === "deposit"
                    ? (needsApprove ? `Approve & Deposit` : "Deposit Assets")
                    : "Withdraw Assets"}
                </button>

                {/* Info message for approval flow */}
                {needsApprove && !isPending && !isConfirming && (
                  <div className="glass rounded-xl p-4 border border-yellow-500/30 bg-yellow-500/10">
                    <p className="text-sm text-yellow-400 text-center">
                      First transaction will approve {tokenSymbol || "tokens"}. After confirmation, click deposit again to complete.
                    </p>
                  </div>
                )}

                {!address && (
                  <p className="text-xs text-gray-500 text-center">
                    Connect your wallet to interact with the vault
                  </p>
                )}

                {isSuccess && (
                  <div className="glass rounded-xl p-4 border border-green-500/30 bg-green-500/10">
                    <p className="text-sm text-green-400 text-center">
                      Transaction successful! Your {tab} has been completed.
                    </p>
                  </div>
                )}
              </form>
            </div>
          </div>

          {/* Vault Stats Sidebar */}
          <div className="space-y-6">
            <div className="glass glass-hover rounded-2xl p-8 border border-white/10">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-white">Vault Stats</h3>
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500/20 to-cyan-500/20 flex items-center justify-center">
                  <span className="text-2xl">📊</span>
                </div>
              </div>
              <div className="space-y-4">
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Total Value Locked</p>
                  <p className="text-3xl font-bold text-white">
                    ${vaultStats.totalDeposits.toLocaleString()}
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Current APY</p>
                  <p className="text-3xl font-bold bg-gradient-to-r from-green-400 to-emerald-400 bg-clip-text text-transparent">
                    {vaultStats.apy}%
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-white/5 border border-white/10">
                  <p className="text-sm text-gray-400 mb-1">Share Price</p>
                  <p className="text-2xl font-bold text-indigo-400">
                    {vaultStats.sharePrice} stETH
                  </p>
                </div>
              </div>
            </div>

            <div className="glass glass-hover rounded-2xl p-8 border border-white/10">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-white">Your Position</h3>
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500/20 to-pink-500/20 flex items-center justify-center">
                  <span className="text-2xl">👤</span>
                </div>
              </div>
              <div className="space-y-3">
                <div className="flex justify-between p-3 rounded-lg bg-white/5">
                  <span className="text-gray-400">Deposited</span>
                  <span className="font-bold text-white">
                    {vaultStats.yourDeposits.toLocaleString()} stETH
                  </span>
                </div>
                <div className="flex justify-between p-3 rounded-lg bg-white/5">
                  <span className="text-gray-400">Your Shares</span>
                  <span className="font-bold text-white">
                    {vaultStats.yourShares.toLocaleString()} bstETH
                  </span>
                </div>
                <div className="flex justify-between p-3 rounded-lg bg-white/5">
                  <span className="text-gray-400">Current Value</span>
                  <span className="font-bold text-green-400">
                    ${(vaultStats.yourShares * vaultStats.sharePrice).toLocaleString()}
                  </span>
                </div>
              </div>
            </div>

            <div className="glass rounded-2xl p-6 border border-indigo-500/30 bg-gradient-to-br from-indigo-500/10 to-purple-500/10">
              <div className="flex items-start space-x-3">
                <div className="w-8 h-8 rounded-lg bg-indigo-500/20 flex items-center justify-center flex-shrink-0 mt-1">
                  <span className="text-lg">ℹ️</span>
                </div>
                <div>
                  <p className="text-sm text-gray-300 leading-relaxed">
                    <strong className="text-indigo-400">ERC-4626 Standard:</strong> This vault implements the tokenized vault standard,
                    allowing you to earn yield while maintaining liquidity through tradeable shares.
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
