# Bastion Protocol - Quick Start Guide

## 🚀 Run the Demo in 3 Steps

### Step 1: Install Dependencies
```bash
cd frontend
npm install
```

### Step 2: Start the Development Server
```bash
npm run dev
```

### Step 3: Open the Demo
Open your browser to [http://localhost:3000](http://localhost:3000)

## 🎮 Using the Demo Mode

### Activate Demo Mode
1. Look for the **"Enable Demo Mode"** button in the bottom-right corner
2. Click it to open the interactive simulation modal

### Run the Simulation
1. Click the red **"Trigger 25% stETH Depeg"** button
2. Watch the simulation unfold:
   - ⚠️ Depeg detected (1.5s)
   - 🔍 AVS operators verify (3.2s)
   - 💰 Insurance payout executes (2.0s)
   - ✅ Complete with metrics

### Key Metrics to Show
- **LP Balance Before**: $50,000
- **Insurance Payout**: ~$3,187
- **LP Balance After**: ~$53,187
- **Loss Recovered**: 85%
- **Consensus**: 4/4 operators verified

### Reset and Run Again
Click **"Reset Simulation"** to run the demo multiple times

## 📱 Pages Available

- **Dashboard** (`/`) - Main page with demo mode
- **Vault** (`/vault`) - Deposit/Withdraw interface
- **Borrow** (`/borrow`) - LP borrowing interface
- **Insurance** (`/insurance`) - Coverage and claims

## 🎯 Hackathon Talking Points

### What to Emphasize

1. **Automated Protection**: No manual intervention needed
2. **AVS Integration**: Decentralized verification via EigenLayer
3. **Fast Response**: ~10 seconds from detection to payout
4. **Transparent Process**: Every step visible in event timeline
5. **Pro-Rata Distribution**: Fair insurance distribution

### Demo Flow for Judges

1. **Start**: Show the normal dashboard
2. **Enable**: Activate demo mode
3. **Explain**: Describe what will happen
4. **Trigger**: Click the depeg button
5. **Narrate**: Talk through each step
6. **Highlight**: Point out the metrics
7. **Reset**: Show it can run again

## 🛠️ Technical Stack

- **Frontend**: Next.js 16, React 19, TypeScript
- **Styling**: Tailwind CSS
- **Blockchain**: wagmi, viem, RainbowKit
- **Smart Contracts**: Solidity, Uniswap V4, EigenLayer AVS
- **Build**: Webpack (for WalletConnect compatibility)

## 📖 Documentation

- **Demo Guide**: [frontend/DEMO_MODE.md](frontend/DEMO_MODE.md)
- **Implementation Status**: [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)
- **Frontend README**: [frontend/README.md](frontend/README.md)

## 🐛 Troubleshooting

### Build Fails
```bash
# Use Webpack instead of Turbopack
npm run build --webpack
```

### Demo Not Appearing
- Ensure you're on the Dashboard page (`/`)
- Try refreshing the browser
- Check console for errors

### Simulation Stuck
- Click "Reset Simulation"
- Disable and re-enable demo mode

## 🎨 Visual Highlights

- **Purple/Blue Gradient**: Professional branding
- **Animated Progress**: Real-time step indicators
- **Color-Coded Events**: Easy-to-follow timeline
- **Before/After Cards**: Clear value comparison
- **Responsive Design**: Works on all screen sizes

## 🚀 Production Deployment (Future)

### Deploy Contracts
```bash
cd ..
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast
```

### Update Contract Addresses
Edit `frontend/lib/contracts/addresses.ts` with deployed addresses

### Deploy Frontend
```bash
# Vercel
vercel deploy

# Or Netlify
netlify deploy --prod
```

## 📊 What's Implemented

✅ **100% Complete**
- Smart Contracts (BastionHook, InsuranceTranche, LendingModule, BastionVault)
- EigenLayer AVS Integration
- Frontend with Real-Time Data
- Interactive Demo Mode
- Beautiful UI/UX
- Documentation

## 🎉 Ready for Hackathon!

The Bastion protocol is **fully implemented** and ready to demonstrate.

**Run the demo, impress the judges, and win the hackathon!** 🏆

---

**Questions?** Check [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for detailed feature breakdown.
