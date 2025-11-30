# Bastion Demo Mode - Hackathon Demonstration Guide

## Overview

The Bastion Demo Mode provides a visually impressive, interactive simulation of the entire depeg detection and insurance payout flow. Perfect for hackathon presentations and demonstrations.

## Features

### 1. Interactive Depeg Simulation
- **One-Click Demo Activation**: Toggle demo mode with a floating button in the bottom-right corner
- **Realistic 25% stETH Depeg**: Simulates a severe depeg event exceeding the 20% threshold
- **Animated Progress**: Visual indicators showing each step of the process

### 2. AVS Operator Verification
- **4 Mock Operators**: Displays realistic operator nodes with stake amounts
- **Real-time Verification**: Watch as each operator verifies the depeg event
- **Consensus Visualization**: Shows 4/4 operators reaching consensus

### 3. Insurance Payout Execution
- **Before/After Comparison**: Clear visualization of LP position values
- **Payout Calculation**: Automatic calculation based on depeg severity and coverage ratio
- **Loss Recovery Metrics**: Shows percentage of loss recovered

### 4. Live Event Timeline
- **Timestamped Events**: Every action is logged with precise timestamps
- **Color-Coded Messages**:
  - 🔴 Error: Depeg detected
  - ⚠️ Warning: Threshold exceeded
  - ℹ️ Info: Process updates
  - ✅ Success: Completed actions

### 5. Asset Price Tracking
- **Real-time Price Display**: Shows the 25% depeg in stETH
- **Comparative View**: Other assets (cbETH, rETH) remain pegged

## How to Use for Hackathon Demo

### Starting the Demo

1. **Navigate to Dashboard**: Open the Bastion frontend at `http://localhost:3000`

2. **Enable Demo Mode**: Click the "Enable Demo Mode" button in the bottom-right corner

3. **Review the Interface**: The demo modal opens with:
   - Control Panel (left)
   - Metrics & Timeline (right)

### Running the Simulation

1. **Trigger Depeg**: Click the red "Trigger 25% stETH Depeg" button

2. **Watch the Flow**:
   - **Step 1** (1.5s): Depeg detected, price drops to $0.75
   - **Step 2** (3.2s): AVS operators begin verification
   - **Step 3** (4.0s): All operators verify (4/4 consensus)
   - **Step 4** (2.0s): Insurance payout executes
   - **Step 5**: Completion with final metrics

3. **Show Key Metrics**:
   - LP balance before: $50,000
   - Insurance payout: ~$3,187 (calculated based on 30% stETH exposure)
   - LP balance after: ~$53,187
   - Loss recovered: 85%

4. **Reset & Repeat**: Click "Reset Simulation" to run again

## Key Talking Points for Judges

### 1. Automated Insurance
- "No manual intervention required - AVS operators automatically detect and verify depeg events"
- "Consensus-based verification ensures accuracy and prevents false positives"

### 2. Fast Response Time
- "Entire process completes in ~10 seconds from detection to payout"
- "Users are protected immediately when a threshold-exceeding depeg occurs"

### 3. Transparent Process
- "Every step is visible in the event timeline"
- "Users can see exactly which operators verified the event"

### 4. EigenLayer AVS Integration
- "Leverages EigenLayer's AVS for decentralized verification"
- "Operators are economically incentivized to verify accurately"

### 5. Pro-Rata Payouts
- "Insurance is distributed proportionally based on LP share"
- "Coverage ratio determines payout amount (85% in this demo)"

## Technical Implementation

### Architecture

```
DemoSimulation Component
├── useDemoMode Hook (State Management)
│   ├── Demo State (enabled, step, metrics)
│   ├── Event Timeline
│   └── Operator Status
├── Control Panel
│   ├── Trigger Button
│   └── Reset Button
├── Progress Indicators
│   ├── 4-Step Progress Bar
│   └── AVS Operator Cards
└── Metrics Display
    ├── LP Position Comparison
    ├── Asset Prices
    └── Event Timeline
```

### Simulation Steps

1. **Idle**: Demo enabled, waiting for trigger
2. **Depeg Detected**: stETH price drops, threshold exceeded
3. **AVS Verifying**: 4 operators verify the depeg event
4. **Payout Executing**: Insurance contract distributes funds
5. **Completed**: Final metrics displayed

### Customization

To modify the simulation parameters, edit `/Users/user/gwill/web3/ bastion/frontend/hooks/useDemoMode.ts`:

```typescript
// Initial LP balance
lpBalanceBefore: 50000,

// Depeg percentage
depegPercentage: 25,  // 25% depeg

// Basket composition (30% stETH)
const depegLoss = lpValue * 0.25 * 0.3;

// Coverage ratio (85%)
const payout = Math.floor(depegLoss * 0.85);

// Number of operators
avsOperators: [/* 4 operators */]
```

## Visual Design Highlights

### Color Scheme
- **Purple/Blue Gradient**: Primary branding and headers
- **Red**: Depeg alerts and errors
- **Green**: Successful payouts and verified operators
- **Yellow**: Warnings and medium-risk indicators

### Animations
- **Spinning Loader**: Active step indicator
- **Smooth Transitions**: Step progression
- **Hover Effects**: Button interactions
- **Scale Effects**: Call-to-action buttons

### Layout
- **Responsive Grid**: 2-column layout on desktop
- **Modal Overlay**: Full-screen demo mode
- **Scrollable Timeline**: Event history
- **Card-Based Design**: Clean, modern interface

## Best Practices for Presentation

1. **Start Clean**: Begin with demo mode disabled to show the normal dashboard

2. **Build Anticipation**: Explain what will happen before triggering the depeg

3. **Narrate the Steps**: Talk through each step as it happens

4. **Highlight the Numbers**: Point out the LP value change and payout amount

5. **Show the Timeline**: Emphasize the transparency of the event log

6. **Reset and Show Again**: Run the simulation 2-3 times if time permits

## Troubleshooting

### Demo Not Appearing
- Ensure you're on the Dashboard page (`/`)
- Check browser console for errors
- Try refreshing the page

### Simulation Stuck
- Click "Reset Simulation"
- If that doesn't work, disable and re-enable demo mode

### Button Disabled
- Demo can only run when in "idle" state
- Wait for current simulation to complete or reset

## Future Enhancements

Potential additions for production:
- [ ] Multiple depeg scenarios (5%, 10%, 25%, 50%)
- [ ] Different asset depegs (cbETH, rETH, USDe)
- [ ] Adjustable coverage ratios
- [ ] Multiple LP positions with different values
- [ ] Failed verification scenarios
- [ ] Network congestion simulation
- [ ] Gas cost estimates

---

**Built with**: Next.js 16, React 19, TypeScript, Tailwind CSS, wagmi, viem, RainbowKit
**Demo Mode**: Fully client-side simulation, no blockchain required
**Perfect for**: Hackathon demos, investor presentations, user onboarding
