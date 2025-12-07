"use client";

import { useState, useEffect } from "react";
import Navigation from "@/components/Navigation";
import { useSwap } from "@/hooks";
import { useAccount } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";

export default function Swap() {
  const [amountIn, setAmountIn] = useState("");
  const [quote, setQuote] = useState<{ amountOut: number; fee: number } | null>(null);

  const { address } = useAccount();

  const {
    selectedTokenIn,
    selectedTokenOut,
    flipTokens,
    stETHBalance,
    usdcBalance,
    getTokenBalance,
    getTokenSymbol,
    feePercentage,
    insuranceFeePercentage,
    allowance,
    needsApproval,
    getQuote,
    swap,
    isPending,
    isConfirming,
    isSuccess,
    hash,
  } = useSwap();

  // Get quote when amount changes
  useEffect(() => {
    const fetchQuote = async () => {
      if (amountIn && parseFloat(amountIn) > 0) {
        const result = await getQuote(amountIn);
        setQuote(result);
      } else {
        setQuote(null);
      }
    };
    fetchQuote();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [amountIn, selectedTokenIn, selectedTokenOut]);

  // Log transaction hash when available
  useEffect(() => {
    if (hash) {
      console.log("Swap transaction hash:", hash);
      console.log(`View on BaseScan: https://sepolia.basescan.org/tx/${hash}`);
    }
  }, [hash]);

  const tokenInBalance = getTokenBalance(selectedTokenIn);
  const tokenInSymbol = getTokenSymbol(selectedTokenIn);
  const tokenOutSymbol = getTokenSymbol(selectedTokenOut);

  const handleMax = () => {
    setAmountIn(tokenInBalance.toString());
  };

  const handleFlip = () => {
    flipTokens();
    setAmountIn("");
    setQuote(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!amountIn || parseFloat(amountIn) <= 0) return;

    try {
      const result = await swap(amountIn);
      // If it was an approval, show message to user
      if (result === "approval") {
        console.log("Approval transaction sent. After confirmation, click swap again.");
      }
      // Clear amount after successful swap
      if (isSuccess) {
        setAmountIn("");
        setQuote(null);
      }
    } catch (error) {
      console.error("Swap error:", error);
    }
  };

  // Check if user needs to approve
  const amountNum = parseFloat(amountIn) || 0;
  const needsApprove = amountNum > 0 && amountNum > allowance;

  return (
    <div className="min-h-screen">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Hero Section */}
        <div className="mb-12">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-white via-cyan-200 to-blue-200 bg-clip-text text-transparent">
            Token Swap
          </h1>
          <p className="text-gray-400 text-lg">Swap stETH ↔ USDC with 0.2% fee. 80% of fees fund insurance protection.</p>
        </div>

        {/* Wallet Info Banner - Show if connected but no balance */}
        {address && stETHBalance === 0 && usdcBalance === 0 && (
          <div className="glass rounded-xl p-6 mb-8 border border-yellow-500/30 bg-yellow-500/5">
            <div className="flex items-start space-x-4">
              <span className="text-2xl">💡</span>
              <div className="flex-1">
                <h3 className="text-lg font-semibold text-yellow-400 mb-2">Get Test Tokens</h3>
                <p className="text-gray-300 mb-3">Your wallet is connected but has no tokens. Run this command to mint test tokens:</p>
                <div className="bg-black/30 rounded-lg p-3 font-mono text-sm text-gray-200 break-all">
                  cd "/Users/user/gwill/web3/ bastion" && source .env && RECIPIENT={address} forge script script/MintToUser.s.sol:MintToUser --rpc-url https://sepolia.base.org --broadcast
                </div>
                <p className="text-xs text-gray-400 mt-2">Connected wallet: {address}</p>
              </div>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Swap Form */}
          <div className="lg:col-span-2">
            <div className="glass rounded-2xl border border-white/10 overflow-hidden">
              {/* Header */}
              <div className="border-b border-white/10 bg-gradient-to-r from-cyan-500/10 to-blue-500/10">
                <div className="px-8 py-6">
                  <h2 className="text-2xl font-bold text-white">
                    <span className="text-xl mr-2">🔄</span>
                    Swap Tokens
                  </h2>
                </div>
              </div>

              {/* Form */}
              <form onSubmit={handleSubmit} className="p-8 space-y-6">
                {/* Token In */}
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-3">
                    You Pay
                  </label>
                  <div className="glass-hover rounded-xl border border-white/10 p-4">
                    <div className="flex items-center justify-between mb-2 gap-4">
                      <input
                        type="number"
                        value={amountIn}
                        onChange={(e) => setAmountIn(e.target.value)}
                        placeholder="0.0"
                        className="bg-transparent text-white text-2xl font-bold outline-none flex-1 min-w-0"
                        step="0.01"
                        min="0"
                      />
                      <div className="flex items-center space-x-3 flex-shrink-0">
                        <button
                          type="button"
                          onClick={handleMax}
                          className="px-3 py-1 bg-cyan-500/20 text-cyan-400 rounded-lg text-xs font-semibold hover:bg-cyan-500/30 transition-all border border-cyan-500/30"
                        >
                          MAX
                        </button>
                        <div className="px-4 py-2 bg-white/5 rounded-lg border border-white/10">
                          <span className="font-bold text-white">{tokenInSymbol}</span>
                        </div>
                      </div>
                    </div>
                    <p className="text-sm text-gray-400">
                      Balance: <span className="text-white font-semibold">{tokenInBalance.toFixed(4)}</span>
                    </p>
                  </div>
                </div>

                {/* Flip Button */}
                <div className="flex justify-center">
                  <button
                    type="button"
                    onClick={handleFlip}
                    className="p-3 bg-gradient-to-r from-cyan-500/20 to-blue-500/20 rounded-full border border-white/20 hover:border-white/40 transition-all hover:scale-110 shadow-lg"
                  >
                    <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
                    </svg>
                  </button>
                </div>

                {/* Token Out */}
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-3">
                    You Receive
                  </label>
                  <div className="glass-hover rounded-xl border border-white/10 p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="text-2xl font-bold text-white">
                        {quote ? quote.amountOut.toFixed(4) : "0.0"}
                      </div>
                      <div className="px-4 py-2 bg-white/5 rounded-lg border border-white/10">
                        <span className="font-bold text-white">{tokenOutSymbol}</span>
                      </div>
                    </div>
                    <p className="text-sm text-gray-400">
                      Balance: <span className="text-white font-semibold">{getTokenBalance(selectedTokenOut).toFixed(4)}</span>
                    </p>
                  </div>
                </div>

                {/* Swap Details */}
                {quote && (
                  <div className="glass-hover rounded-xl p-6 space-y-3 border border-white/10">
                    <div className="flex justify-between items-center">
                      <span className="text-gray-400">Exchange Rate</span>
                      <span className="font-semibold text-white">
                        1 {tokenInSymbol} = {(quote.amountOut / parseFloat(amountIn)).toFixed(4)} {tokenOutSymbol}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-400">Total Fee ({feePercentage}%)</span>
                      <span className="font-semibold text-red-400">
                        {quote.fee.toFixed(4)} {tokenInSymbol}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-400">To Insurance ({insuranceFeePercentage}%)</span>
                      <span className="font-semibold text-green-400">
                        {(quote.fee * 0.8).toFixed(4)} {tokenInSymbol}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-400">Protocol Revenue</span>
                      <span className="font-semibold text-purple-400">
                        {(quote.fee * 0.2).toFixed(4)} {tokenInSymbol}
                      </span>
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={!address || isPending || isConfirming || !amountIn || parseFloat(amountIn) <= 0}
                  className="w-full bg-gradient-to-r from-cyan-600 to-blue-600 text-white py-4 rounded-xl font-bold text-lg hover:from-cyan-700 hover:to-blue-700 transition-all shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 disabled:from-gray-600 disabled:to-gray-700 disabled:cursor-not-allowed disabled:shadow-none"
                >
                  {isPending
                    ? (needsApprove ? "Approving..." : "Processing...")
                    : isConfirming
                    ? "Confirming..."
                    : isSuccess
                    ? "Success!"
                    : needsApprove
                    ? `Approve & Swap`
                    : "Swap Tokens"}
                </button>

                {/* Info message for approval flow */}
                {needsApprove && !isPending && !isConfirming && (
                  <div className="glass rounded-xl p-4 border border-yellow-500/30 bg-yellow-500/10">
                    <p className="text-sm text-yellow-400 text-center">
                      First transaction will approve {tokenInSymbol}. After confirmation, click swap again to complete.
                    </p>
                  </div>
                )}

                {!address && (
                  <p className="text-xs text-gray-500 text-center">
                    Connect your wallet to swap tokens
                  </p>
                )}

                {isSuccess && hash && (
                  <div className="glass rounded-xl p-4 border border-green-500/30 bg-green-500/10 space-y-2">
                    <p className="text-sm text-green-400 text-center">
                      Swap successful! Your tokens have been exchanged.
                    </p>
                    <a
                      href={`https://sepolia.basescan.org/tx/${hash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block text-center text-xs text-blue-400 hover:text-blue-300 underline"
                    >
                      View on BaseScan →
                    </a>
                  </div>
                )}
              </form>
            </div>
          </div>

          {/* Stats Sidebar */}
          <div className="space-y-6">
            {/* Swap Info */}
            <div className="glass rounded-2xl p-6 border border-white/10">
              <h3 className="text-xl font-bold mb-6 text-white">How It Works</h3>
              <div className="space-y-4">
                <div className="flex items-start space-x-3">
                  <span className="text-2xl">🔄</span>
                  <div>
                    <p className="font-semibold text-white">Simple Swap</p>
                    <p className="text-sm text-gray-400">1:1 exchange rate for testing</p>
                  </div>
                </div>
                <div className="flex items-start space-x-3">
                  <span className="text-2xl">💰</span>
                  <div>
                    <p className="font-semibold text-white">0.2% Fee</p>
                    <p className="text-sm text-gray-400">Small fee on each swap</p>
                  </div>
                </div>
                <div className="flex items-start space-x-3">
                  <span className="text-2xl">🛡️</span>
                  <div>
                    <p className="font-semibold text-white">80% to Insurance</p>
                    <p className="text-sm text-gray-400">Automatically funds protection</p>
                  </div>
                </div>
                <div className="flex items-start space-x-3">
                  <span className="text-2xl">📊</span>
                  <div>
                    <p className="font-semibold text-white">20% Protocol Revenue</p>
                    <p className="text-sm text-gray-400">Supports protocol development</p>
                  </div>
                </div>
              </div>
            </div>

            {/* Token Balances */}
            <div className="glass rounded-2xl p-6 border border-white/10">
              <h3 className="text-xl font-bold mb-6 text-white">Your Balances</h3>
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <span className="text-gray-400">stETH</span>
                  <span className="font-bold text-white">{stETHBalance.toFixed(4)}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-400">USDC</span>
                  <span className="font-bold text-white">{usdcBalance.toFixed(4)}</span>
                </div>
              </div>
            </div>

            {/* Insurance Link */}
            <div className="glass rounded-2xl p-6 border border-green-500/30 bg-gradient-to-br from-green-500/10 to-emerald-500/10">
              <h3 className="text-lg font-bold mb-2 text-green-400">Insurance Pool</h3>
              <p className="text-sm text-gray-300 mb-4">
                Every swap automatically funds the insurance pool, protecting all LPs from depeg events.
              </p>
              <a
                href="/insurance"
                className="block text-center px-4 py-2 bg-green-500/20 border border-green-500/30 rounded-lg text-green-400 font-semibold hover:bg-green-500/30 transition-all"
              >
                View Insurance →
              </a>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
