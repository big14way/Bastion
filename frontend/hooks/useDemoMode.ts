"use client";

import { useState, useCallback } from "react";

export type DemoStep = "idle" | "depeg-detected" | "avs-verifying" | "payout-executing" | "completed";

export interface DemoState {
  isEnabled: boolean;
  currentStep: DemoStep;
  depegPercentage: number;

  // Mock data for before/after comparison
  lpBalanceBefore: number;
  lpBalanceAfter: number;
  insurancePayoutAmount: number;

  // AVS simulation data
  avsOperators: Array<{
    id: number;
    name: string;
    status: "pending" | "verified" | "rejected";
    stake: number;
  }>;

  // Asset prices
  stETHPrice: number;
  cbETHPrice: number;
  rETHPrice: number;

  // Timeline events
  events: Array<{
    timestamp: Date;
    type: "info" | "warning" | "success" | "error";
    message: string;
  }>;
}

const INITIAL_STATE: DemoState = {
  isEnabled: false,
  currentStep: "idle",
  depegPercentage: 0,
  lpBalanceBefore: 50000,
  lpBalanceAfter: 50000,
  insurancePayoutAmount: 0,
  avsOperators: [
    { id: 1, name: "Operator Alpha", status: "pending", stake: 500000 },
    { id: 2, name: "Operator Beta", status: "pending", stake: 350000 },
    { id: 3, name: "Operator Gamma", status: "pending", stake: 425000 },
    { id: 4, name: "Operator Delta", status: "pending", stake: 280000 },
  ],
  stETHPrice: 1.0,
  cbETHPrice: 1.0,
  rETHPrice: 1.0,
  events: [],
};

export function useDemoMode() {
  const [state, setState] = useState<DemoState>(INITIAL_STATE);

  const toggleDemoMode = useCallback(() => {
    setState((prev) => ({
      ...INITIAL_STATE,
      isEnabled: !prev.isEnabled,
      events: !prev.isEnabled
        ? [
            {
              timestamp: new Date(),
              type: "info",
              message: "Demo mode activated. Ready to simulate depeg event.",
            },
          ]
        : [],
    }));
  }, []);

  const addEvent = useCallback((type: DemoState["events"][0]["type"], message: string) => {
    setState((prev) => ({
      ...prev,
      events: [...prev.events, { timestamp: new Date(), type, message }],
    }));
  }, []);

  const triggerDepeg = useCallback(async () => {
    if (state.currentStep !== "idle") return;

    setState((prev) => ({
      ...prev,
      currentStep: "depeg-detected",
      depegPercentage: 25,
      stETHPrice: 0.75, // 25% depeg
    }));

    addEvent("error", "stETH depeg detected: -25% from peg");
    addEvent("warning", "Price deviation exceeds 20% threshold");

    // Simulate depeg detection delay
    await new Promise((resolve) => setTimeout(resolve, 1500));

    setState((prev) => ({
      ...prev,
      currentStep: "avs-verifying",
    }));

    addEvent("info", "AVS operators notified of depeg event");
    addEvent("info", "Waiting for operator verification consensus...");

    // Simulate operators verifying one by one
    for (let i = 0; i < 4; i++) {
      await new Promise((resolve) => setTimeout(resolve, 800));

      setState((prev) => ({
        ...prev,
        avsOperators: prev.avsOperators.map((op) =>
          op.id === i + 1 ? { ...op, status: "verified" as const } : op
        ),
      }));

      addEvent("success", `${state.avsOperators[i].name} verified depeg event`);
    }

    await new Promise((resolve) => setTimeout(resolve, 1000));

    setState((prev) => ({
      ...prev,
      currentStep: "payout-executing",
    }));

    addEvent("info", "Consensus reached: 4/4 operators verified");
    addEvent("info", "Initiating insurance payout...");

    // Calculate payout
    const lpValue = state.lpBalanceBefore;
    const depegLoss = lpValue * 0.25 * 0.3; // 30% of basket is stETH
    const payout = Math.floor(depegLoss * 0.85); // 85% coverage ratio

    await new Promise((resolve) => setTimeout(resolve, 2000));

    setState((prev) => ({
      ...prev,
      currentStep: "completed",
      insurancePayoutAmount: payout,
      lpBalanceAfter: prev.lpBalanceBefore + payout,
    }));

    addEvent("success", `Insurance payout executed: $${payout.toLocaleString()}`);
    addEvent("success", `LP position restored to $${(state.lpBalanceBefore + payout).toLocaleString()}`);
  }, [state, addEvent]);

  const resetDemo = useCallback(() => {
    setState((prev) => ({
      ...INITIAL_STATE,
      isEnabled: prev.isEnabled,
      events: prev.isEnabled
        ? [
            {
              timestamp: new Date(),
              type: "info",
              message: "Demo reset. Ready for new simulation.",
            },
          ]
        : [],
    }));
  }, []);

  return {
    state,
    toggleDemoMode,
    triggerDepeg,
    resetDemo,
    canTriggerDepeg: state.isEnabled && state.currentStep === "idle",
    isSimulationRunning: state.currentStep !== "idle" && state.currentStep !== "completed",
  };
}
