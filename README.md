# 🛡️ Bastion Protocol

**Next-Generation DeFi Protocol with Uniswap V4 Hooks, EigenLayer AVS, and Automated Risk Management**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.26-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://book.getfoundry.sh/)

## 🎯 Overview

Bastion Protocol combines cutting-edge DeFi technologies to create secure, yield-generating vaults with automated liquidity provision and insurance protection. The protocol leverages:

- **Uniswap V4 Hooks** for custom liquidity management
- **EigenLayer AVS** for decentralized validation
- **ERC-4626 Vaults** for standardized yield generation
- **Multi-tiered Insurance** for depositor protection
- **Real-time Risk Management** with volatility oracles

## ✅ Current Status

**LIVE ON BASE SEPOLIA TESTNET** with working deposits, withdrawals, and real on-chain data!

### Deployed Contracts (Base Sepolia - Chain ID: 84532)

| Contract | Address | Status |
|----------|---------|--------|
| **BastionVault** | [`0xF5c0325F85b1d0606669956895c6876b15bc33b6`](https://sepolia.basescan.org/address/0xF5c0325F85b1d0606669956895c6876b15bc33b6) | ✅ Live |
| **stETH (Mock)** | [`0x60D36283c134bF0f73B67626B47445455e1FbA9e`](https://sepolia.basescan.org/address/0x60D36283c134bF0f73B67626B47445455e1FbA9e) | ✅ Live |
| **InsuranceTranche** | `0x4d88c574A9D573a5C62C692e4714F61829d7E4a6` | ✅ Deployed |
| **LendingModule** | `0x6997d539bC80f514e7B015545E22f3Db5672a5f8` | ✅ Deployed |
| **VolatilityOracle** | `0xD1c62D4208b10AcAaC2879323f486D1fa5756840` | ✅ Deployed |

## 🚀 Quick Start

### Prerequisites

- MetaMask or WalletConnect wallet
- Base Sepolia ETH (get from [faucet](https://www.alchemy.com/faucets/base-sepolia))
- Node.js 18+ and npm

### 1. Run the Frontend

```bash
# Clone and enter the repository
git clone <repo-url>
cd bastion

# Install and run frontend
cd frontend
npm install
npm run dev

# Open http://localhost:3000
```

### 2. Connect Your Wallet

1. Open the app at http://localhost:3000
2. Connect your wallet (MetaMask/WalletConnect)
3. Switch to Base Sepolia network
4. You'll see your wallet address in the UI

### 3. Get Test Tokens

The app will show you a command to mint tokens when your balance is zero. Run it in your terminal:

```bash
cd bastion
source .env
RECIPIENT=0xYourWalletAddress forge script script/MintToUser.s.sol:MintToUser \
  --rpc-url https://sepolia.base.org --broadcast
```

### 4. Make a Deposit

1. Navigate to the Vault page
2. Enter amount to deposit (e.g., 10 stETH)
3. Click "Deposit" - it will automatically approve and deposit
4. Watch your vault shares update in real-time!

### 5. Withdraw Funds

1. Switch to "Withdraw" tab
2. Enter shares to redeem
3. Click "Withdraw"
4. Tokens return to your wallet

## 🧪 Testing & Verification

### Smart Contract Testing

```bash
# Run all tests
forge test -vvv

# Run specific test
forge test --match-path test/BastionVault.t.sol -vvv

# Test coverage
forge coverage

# Gas report
forge test --gas-report
```

### Verify On-Chain State

```bash
# Check vault balance
cast call 0xF5c0325F85b1d0606669956895c6876b15bc33b6 "totalAssets()" --rpc-url https://sepolia.base.org | cast --from-wei

# Check user shares
cast call 0xF5c0325F85b1d0606669956895c6876b15bc33b6 "balanceOf(address)" <your-address> --rpc-url https://sepolia.base.org
```

## 📦 What's Included

### Smart Contracts

| Contract | Description | Status |
|----------|-------------|--------|
| [BastionHook.sol](src/BastionHook.sol) | Uniswap V4 hook with dynamic fees | ✅ Complete |
| [InsuranceTranche.sol](src/InsuranceTranche.sol) | Insurance premium collection & payouts | ✅ Complete |
| [LendingModule.sol](src/LendingModule.sol) | LP token collateralization | ✅ Complete |
| [BastionVault.sol](src/BastionVault.sol) | ERC-4626 multi-asset vault | ✅ Complete |
| [VolatilityOracle.sol](src/VolatilityOracle.sol) | Volatility data provider | ✅ Complete |
| [BastionServiceManager.sol](src/avs/BastionServiceManager.sol) | EigenLayer AVS service | ✅ Complete |
| [BastionTaskManager.sol](src/avs/BastionTaskManager.sol) | Depeg verification tasks | ✅ Complete |

### Frontend Application

| Page | Description | Features |
|------|-------------|----------|
| [Dashboard](frontend/app/page.tsx) | Main overview | Real-time data, demo mode |
| [Vault](frontend/app/vault/page.tsx) | Deposit/Withdraw | ERC-4626 interface |
| [Borrow](frontend/app/borrow/page.tsx) | LP Borrowing | Health factor, LTV |
| [Insurance](frontend/app/insurance/page.tsx) | Coverage Status | Claims, premiums |

### Demo Mode

**🎮 Interactive Hackathon Demo**
- One-click activation
- 25% stETH depeg simulation
- 4 AVS operators with real-time verification
- Before/After LP balance comparison
- Insurance payout visualization
- Live event timeline

See [frontend/DEMO_MODE.md](frontend/DEMO_MODE.md) for presentation guide.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Frontend (Next.js)                │
│  ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Dashboard  │  │  Vault   │  │     Borrow    │  │
│  │  + Demo     │  │          │  │               │  │
│  └─────────────┘  └──────────┘  └───────────────┘  │
└────────────┬────────────────────────────────────────┘
             │ wagmi / viem
             ▼
┌─────────────────────────────────────────────────────┐
│              Smart Contracts (Solidity)             │
│  ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
│  │BastionHook  │  │Insurance │  │    Lending    │  │
│  │(Dynamic Fee)│  │ Tranche  │  │    Module     │  │
│  └─────────────┘  └──────────┘  └───────────────┘  │
└────────────┬────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────┐
│          EigenLayer AVS (Depeg Verification)        │
│  ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Service    │  │   Task   │  │   Operator    │  │
│  │  Manager    │  │ Manager  │  │   Service     │  │
│  └─────────────┘  └──────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 💻 Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) v18+
- [Git](https://git-scm.com/)

### Installation

```bash
# Clone repository
git clone https://github.com/big14way/Bastion.git
cd Bastion

# Install Solidity dependencies
forge install

# Install frontend dependencies
cd frontend && npm install
```

### Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test file
forge test --match-path test/BastionHook.t.sol

# Generate gas report
forge test --gas-report

# Generate coverage
forge coverage
```

### Build

```bash
# Build contracts
forge build

# Build frontend
cd frontend && npm run build
```

## 📚 Documentation

### Core Documentation

- [QUICK_START.md](QUICK_START.md) - Get started in 3 steps
- [SUMMARY.md](SUMMARY.md) - Complete project summary
- [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) - 100% completion verification

### Frontend Documentation

- [frontend/README.md](frontend/README.md) - Frontend setup
- [frontend/DEMO_MODE.md](frontend/DEMO_MODE.md) - Demo presentation guide

### Technical Documentation

- [AVS_IMPLEMENTATION_SUMMARY.md](AVS_IMPLEMENTATION_SUMMARY.md) - EigenLayer AVS integration
- [BLS_UPGRADE_PATH.md](BLS_UPGRADE_PATH.md) - Future BLS signature upgrade

## 🚢 Deployment

### Deployment Scripts

| Script | Purpose |
|--------|---------|
| [DeployBastion.s.sol](script/DeployBastion.s.sol) | Deploy core protocol |
| [DeployAVS.s.sol](script/DeployAVS.s.sol) | Deploy AVS contracts |
| [VerifyContracts.s.sol](script/VerifyContracts.s.sol) | Verify on explorer |

### Deployment Process

1. **Setup Environment**
   ```bash
   cp .env.example .env
   # Add PRIVATE_KEY, RPC URLs, API keys
   ```

2. **Deploy Core Contracts**
   ```bash
   forge script script/DeployBastion.s.sol \
     --rpc-url base-sepolia \
     --broadcast \
     --verify
   ```

   This will:
   - Mine correct hook address with required flags
   - Deploy BastionHook, InsuranceTranche, LendingModule, BastionVault
   - Deploy mock tokens (stETH, cbETH, rETH, USDe, USDC)
   - Initialize Uniswap V4 pool
   - Save addresses to `deployments/{chainId}.json`

3. **Deploy AVS Contracts**
   ```bash
   forge script script/DeployAVS.s.sol \
     --rpc-url base-sepolia \
     --broadcast
   ```

4. **Verify Contracts**
   ```bash
   forge script script/VerifyContracts.s.sol
   # Follow the generated commands to verify each contract
   ```

5. **Update Frontend**
   ```bash
   # Copy addresses from deployments/{chainId}.json
   # to frontend/lib/contracts/addresses.ts
   ```

### Supported Networks

- **Base Sepolia** (84532) - Testnet ✅
- **Base Mainnet** (8453) - Production
- **Ethereum Sepolia** (11155111) - Testnet
- **Ethereum Mainnet** (1) - Production

## 🔧 Configuration

### Dynamic Fee Configuration

```solidity
// Fee tiers based on volatility
- Low volatility (< 10%): 0.05% fee
- Medium volatility (10-14%): 0.30% fee
- High volatility (≥ 14%): 1.00% fee

// Update volatility
VolatilityOracle(oracle).updateVolatility(1200); // 12%
```

### Insurance Configuration

```solidity
// Configure depeg threshold
InsuranceTranche(insurance).setDepegThreshold(2000); // 20%

// Collect premiums (20% of swap fees)
BastionHook sends premiums automatically

// Register LP positions
InsuranceTranche(insurance).updateLPPosition(lpAddress, shares);
```

### Lending Configuration

```solidity
// Borrow limits
- Max LTV: 70%
- Liquidation threshold: 75%
- Base interest rate: 5%

// Borrow against LP position
LendingModule(lending).borrow(amount);
```

## 🎯 Use Cases

### For Liquidity Providers
1. Deposit assets into Bastion Vault
2. Receive vault shares (ERC-4626)
3. Automatic insurance against depegs
4. Borrow against LP positions
5. Earn swap fees from dynamic fee mechanism

### For Protocols
1. Integrate Bastion for basket exposure
2. Leverage insurance for risk management
3. Use vault shares as collateral
4. Build on top of Uniswap V4 infrastructure

### For AVS Operators
1. Register with EigenLayer
2. Run Bastion operator service
3. Verify depeg events
4. Earn operator rewards

## 🛠️ Technology Stack

### Smart Contracts
- **Solidity** ^0.8.24
- **Foundry** - Development framework
- **Uniswap V4** - Hooks & Pool Manager
- **EigenLayer** - AVS framework
- **OpenZeppelin** - Security libraries

### Frontend
- **Next.js** 16 - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **wagmi** 3.0 - Ethereum React hooks
- **viem** 2.40 - TypeScript Ethereum client
- **RainbowKit** - Wallet connection

### Infrastructure
- **Chainlink** - Price oracles (future)
- **The Graph** - Indexing (future)
- **IPFS** - Decentralized storage (future)

## 📊 Project Stats

- **Smart Contracts**: 7 core contracts
- **Test Coverage**: 58 tests across 3 test files
- **Frontend Pages**: 4 fully functional pages
- **Custom Hooks**: 5 React hooks for blockchain data
- **Lines of Code**: 2000+ Solidity, 1500+ TypeScript

## 🤝 Contributing

Contributions are welcome! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Write tests for all new features
- Follow Solidity style guide
- Document all public functions
- Run `forge fmt` before committing
- Ensure all tests pass

## 🔐 Security

**⚠️ This is experimental software. Use at your own risk.**

### Security Considerations

- Contracts have NOT been audited
- Do not use with real funds on mainnet
- Test thoroughly on testnet first
- Report security issues privately

### Bug Bounty

Planning to launch bug bounty program after audit.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Uniswap** - For Uniswap V4 hooks framework
- **EigenLayer** - For AVS infrastructure
- **OpenZeppelin** - For secure contract libraries
- **Foundry** - For amazing development tools

## 📞 Contact

- **GitHub**: [@big14way](https://github.com/big14way)
- **Project**: [Bastion Protocol](https://github.com/big14way/Bastion)

## 🗺️ Roadmap

### Phase 1: MVP (✅ Complete)
- [x] Core smart contracts
- [x] EigenLayer AVS integration
- [x] Frontend with real-time data
- [x] Interactive demo mode
- [x] Deployment scripts

### Phase 2: Testnet Launch (🔄 In Progress)
- [ ] Deploy to Base Sepolia
- [ ] Run AVS operator nodes
- [ ] Community testing
- [ ] Bug fixes and improvements

### Phase 3: Audit & Mainnet (📋 Planned)
- [ ] Smart contract audit
- [ ] Bug bounty program
- [ ] Mainnet deployment
- [ ] Liquidity mining program

### Phase 4: Expansion (💡 Future)
- [ ] Additional asset support
- [ ] Cross-chain deployment
- [ ] Governance token
- [ ] DAO formation

---

**Built with ❤️ for the Ethereum ecosystem**

🏆 **Ready for Hackathon Demo!**
