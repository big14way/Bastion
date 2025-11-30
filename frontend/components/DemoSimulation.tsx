"use client";

import { useDemoMode } from "@/hooks/useDemoMode";

export default function DemoSimulation() {
  const { state, toggleDemoMode, triggerDepeg, resetDemo, canTriggerDepeg, isSimulationRunning } =
    useDemoMode();

  if (!state.isEnabled) {
    return (
      <div className="fixed bottom-8 right-8 z-50">
        <button
          onClick={toggleDemoMode}
          className="px-6 py-3 bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg font-semibold shadow-lg hover:shadow-xl transition-all duration-200 hover:scale-105"
        >
          Enable Demo Mode
        </button>
      </div>
    );
  }

  const getStepStatus = (step: typeof state.currentStep) => {
    const steps = ["idle", "depeg-detected", "avs-verifying", "payout-executing", "completed"];
    const currentIndex = steps.indexOf(state.currentStep);
    const stepIndex = steps.indexOf(step);

    if (stepIndex < currentIndex) return "completed";
    if (stepIndex === currentIndex) return "active";
    return "pending";
  };

  return (
    <div className="fixed inset-0 z-50 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl max-w-6xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="bg-gradient-to-r from-purple-600 to-blue-600 text-white p-6 rounded-t-2xl">
          <div className="flex justify-between items-center">
            <div>
              <h2 className="text-3xl font-bold mb-2">Bastion Demo Mode</h2>
              <p className="text-purple-100">
                Live simulation of depeg detection and insurance payout
              </p>
            </div>
            <button
              onClick={toggleDemoMode}
              className="px-4 py-2 bg-white bg-opacity-20 hover:bg-opacity-30 rounded-lg transition-all"
            >
              Exit Demo
            </button>
          </div>
        </div>

        <div className="p-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left Column - Controls & Status */}
          <div className="space-y-6">
            {/* Control Panel */}
            <div className="bg-gray-50 rounded-xl p-6">
              <h3 className="text-xl font-bold text-gray-900 mb-4">Control Panel</h3>

              <div className="space-y-4">
                <button
                  onClick={triggerDepeg}
                  disabled={!canTriggerDepeg}
                  className={`w-full py-4 rounded-lg font-bold text-lg transition-all transform ${
                    canTriggerDepeg
                      ? "bg-red-600 text-white hover:bg-red-700 hover:scale-105 shadow-lg hover:shadow-xl"
                      : "bg-gray-300 text-gray-500 cursor-not-allowed"
                  }`}
                >
                  {isSimulationRunning
                    ? "Simulation Running..."
                    : state.currentStep === "completed"
                    ? "Simulation Complete"
                    : "Trigger 25% stETH Depeg"}
                </button>

                <button
                  onClick={resetDemo}
                  disabled={isSimulationRunning}
                  className={`w-full py-3 rounded-lg font-semibold transition-all ${
                    isSimulationRunning
                      ? "bg-gray-200 text-gray-400 cursor-not-allowed"
                      : "bg-blue-600 text-white hover:bg-blue-700"
                  }`}
                >
                  Reset Simulation
                </button>
              </div>
            </div>

            {/* Progress Steps */}
            <div className="bg-gray-50 rounded-xl p-6">
              <h3 className="text-xl font-bold text-gray-900 mb-4">Simulation Progress</h3>

              <div className="space-y-4">
                {[
                  { step: "depeg-detected" as const, label: "Depeg Detected", icon: "⚠️" },
                  { step: "avs-verifying" as const, label: "AVS Verification", icon: "🔍" },
                  { step: "payout-executing" as const, label: "Payout Executing", icon: "💰" },
                  { step: "completed" as const, label: "Complete", icon: "✅" },
                ].map(({ step, label, icon }) => {
                  const status = getStepStatus(step);
                  return (
                    <div
                      key={step}
                      className={`flex items-center space-x-4 p-3 rounded-lg transition-all ${
                        status === "active"
                          ? "bg-blue-100 border-2 border-blue-500"
                          : status === "completed"
                          ? "bg-green-100 border-2 border-green-500"
                          : "bg-gray-100 border-2 border-gray-300"
                      }`}
                    >
                      <span className="text-2xl">{icon}</span>
                      <span
                        className={`font-semibold ${
                          status === "active"
                            ? "text-blue-900"
                            : status === "completed"
                            ? "text-green-900"
                            : "text-gray-500"
                        }`}
                      >
                        {label}
                      </span>
                      {status === "active" && (
                        <div className="ml-auto">
                          <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
                        </div>
                      )}
                      {status === "completed" && (
                        <div className="ml-auto text-green-600 font-bold">✓</div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>

            {/* AVS Operators Status */}
            {state.currentStep !== "idle" && (
              <div className="bg-gray-50 rounded-xl p-6">
                <h3 className="text-xl font-bold text-gray-900 mb-4">AVS Operators</h3>
                <div className="space-y-3">
                  {state.avsOperators.map((operator) => (
                    <div
                      key={operator.id}
                      className={`flex items-center justify-between p-3 rounded-lg ${
                        operator.status === "verified"
                          ? "bg-green-100 border border-green-500"
                          : "bg-white border border-gray-300"
                      }`}
                    >
                      <div>
                        <p className="font-semibold text-gray-900">{operator.name}</p>
                        <p className="text-sm text-gray-600">
                          Stake: ${operator.stake.toLocaleString()}
                        </p>
                      </div>
                      <div>
                        {operator.status === "verified" ? (
                          <span className="px-3 py-1 bg-green-600 text-white rounded-full text-sm font-semibold">
                            Verified ✓
                          </span>
                        ) : (
                          <span className="px-3 py-1 bg-gray-400 text-white rounded-full text-sm">
                            Pending
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Right Column - Metrics & Timeline */}
          <div className="space-y-6">
            {/* Before/After Comparison */}
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 rounded-xl p-6 border-2 border-blue-200">
              <h3 className="text-xl font-bold text-gray-900 mb-4">LP Position Value</h3>

              <div className="grid grid-cols-2 gap-4 mb-6">
                <div className="bg-white rounded-lg p-4 shadow">
                  <p className="text-sm text-gray-600 mb-1">Before Depeg</p>
                  <p className="text-2xl font-bold text-gray-900">
                    ${state.lpBalanceBefore.toLocaleString()}
                  </p>
                </div>

                <div className="bg-white rounded-lg p-4 shadow">
                  <p className="text-sm text-gray-600 mb-1">After Insurance</p>
                  <p className="text-2xl font-bold text-green-600">
                    ${state.lpBalanceAfter.toLocaleString()}
                  </p>
                </div>
              </div>

              {state.insurancePayoutAmount > 0 && (
                <div className="bg-gradient-to-r from-green-500 to-emerald-600 text-white rounded-lg p-4 shadow-lg">
                  <p className="text-sm opacity-90 mb-1">Insurance Payout</p>
                  <p className="text-3xl font-bold">
                    +${state.insurancePayoutAmount.toLocaleString()}
                  </p>
                  <p className="text-sm mt-2 opacity-90">
                    Loss recovered:{" "}
                    {(
                      (state.insurancePayoutAmount /
                        (state.lpBalanceBefore - state.lpBalanceAfter + state.insurancePayoutAmount)) *
                      100
                    ).toFixed(0)}
                    %
                  </p>
                </div>
              )}
            </div>

            {/* Asset Prices */}
            {state.depegPercentage > 0 && (
              <div className="bg-gray-50 rounded-xl p-6">
                <h3 className="text-xl font-bold text-gray-900 mb-4">Asset Prices</h3>
                <div className="space-y-3">
                  <div className="flex justify-between items-center p-3 bg-red-100 border border-red-400 rounded-lg">
                    <div>
                      <p className="font-semibold text-gray-900">stETH</p>
                      <p className="text-sm text-gray-600">Lido Staked ETH</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xl font-bold text-red-600">
                        ${state.stETHPrice.toFixed(2)}
                      </p>
                      <p className="text-sm text-red-700 font-semibold">
                        -{state.depegPercentage}%
                      </p>
                    </div>
                  </div>

                  <div className="flex justify-between items-center p-3 bg-green-100 border border-green-400 rounded-lg">
                    <div>
                      <p className="font-semibold text-gray-900">cbETH</p>
                      <p className="text-sm text-gray-600">Coinbase Staked ETH</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xl font-bold text-green-600">
                        ${state.cbETHPrice.toFixed(2)}
                      </p>
                      <p className="text-sm text-green-700">Normal</p>
                    </div>
                  </div>

                  <div className="flex justify-between items-center p-3 bg-green-100 border border-green-400 rounded-lg">
                    <div>
                      <p className="font-semibold text-gray-900">rETH</p>
                      <p className="text-sm text-gray-600">Rocket Pool ETH</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xl font-bold text-green-600">
                        ${state.rETHPrice.toFixed(2)}
                      </p>
                      <p className="text-sm text-green-700">Normal</p>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Event Timeline */}
            <div className="bg-gray-50 rounded-xl p-6">
              <h3 className="text-xl font-bold text-gray-900 mb-4">Event Timeline</h3>
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {state.events
                  .slice()
                  .reverse()
                  .map((event, index) => (
                    <div
                      key={index}
                      className={`flex items-start space-x-3 p-3 rounded-lg ${
                        event.type === "error"
                          ? "bg-red-100 border border-red-300"
                          : event.type === "warning"
                          ? "bg-yellow-100 border border-yellow-300"
                          : event.type === "success"
                          ? "bg-green-100 border border-green-300"
                          : "bg-blue-100 border border-blue-300"
                      }`}
                    >
                      <span className="text-lg">
                        {event.type === "error"
                          ? "🔴"
                          : event.type === "warning"
                          ? "⚠️"
                          : event.type === "success"
                          ? "✅"
                          : "ℹ️"}
                      </span>
                      <div className="flex-1">
                        <p
                          className={`text-sm font-semibold ${
                            event.type === "error"
                              ? "text-red-900"
                              : event.type === "warning"
                              ? "text-yellow-900"
                              : event.type === "success"
                              ? "text-green-900"
                              : "text-blue-900"
                          }`}
                        >
                          {event.message}
                        </p>
                        <p className="text-xs text-gray-600 mt-1">
                          {event.timestamp.toLocaleTimeString()}
                        </p>
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
