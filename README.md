# 🏰 Bastion Protocol

**AVS-Secured Lending Protocol with Automated Insurance & Basket Rebalancing**

Bastion is a decentralized lending protocol built on Base Sepolia that combines EigenLayer's Active Validation Services (AVS), automated insurance protection, and intelligent basket management to create a secure, efficient DeFi lending experience.

[![Live Demo](https://img.shields.io/badge/demo-live-green)](https://bastion-protocol-three.vercel.app)
[![License](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)
[![Network](https://img.shields.io/badge/network-Base%20Sepolia-orange)](https://sepolia.basescan.org)

---

## ✨ Features

### For Lenders (LPs)
- 🛡️ **Automatic Insurance**: Every deposit gets depeg protection
- 💰 **Dual Yield**: Earn from lending + swap fees
- 🔄 **Auto-Rebalancing**: Basket weights adjust based on volatility
- 💸 **Instant Payouts**: Automatic compensation on depeg events

### For Borrowers
- 📊 **Dynamic Fees**: 0.05-1.00% APR based on market volatility
- 🎯 **Basket Collateral**: Diversified assets (stETH, cbETH, rETH, USDe)
- ⚡ **Fast Loans**: Over-collateralized (150% ratio)
- 📈 **Health Monitoring**: Real-time position tracking

### For Traders
- 🔄 **Token Swaps**: Trade with 0.2% fee
- 🛡️ **Insurance Funding**: 80% of fees → insurance, 20% → protocol
- 🔢 **Smart Decimals**: Automatic conversion (18 ↔ 6 decimals)
- ⏱️ **Real-Time Quotes**: Live price updates

---

## 🏗️ Architecture

Bastion consists of four core modules:

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  Basket Vault   │──────│  Lending Module  │──────│ Insurance Pool  │
│  (Multi-Asset)  │      │  (Borrow/Lend)   │      │  (Depeg Cover)  │
└────────┬────────┘      └────────┬─────────┘      └────────┬────────┘
         │                        │                         │
         │                ┌───────┴────────┐                │
         │                │ AVS Operators  │                │
         │                │ (Verification) │                │
         │                └───────┬────────┘                │
         │                        │                         │
         └────────────────────────┴─────────────────────────┘
                            Chainlink Oracles
```

### 1. **Basket Management**
- Multi-asset collateral basket with automated rebalancing
- Dynamic weight adjustment using Chainlink price feeds
- Supports stETH, cbETH, rETH, and USDe
- DEX integration for automated swaps

### 2. **Insurance Protection**
- Automated depeg insurance funded by swap fees
- 80% of swap fees automatically fund insurance pool
- AVS-verified depeg detection (20% threshold)
- Automatic payout distribution to affected LPs

### 3. **Dynamic Fee System**
- Volatility-based lending fees
  - Low (<10%): 0.05% APR
  - Medium (10-14%): 0.30% APR
  - High (>14%): 1.00% APR

### 4. **AVS Integration**
- EigenLayer AVS operators provide security
- Depeg event verification
- Basket rebalancing triggers
- Slashing protection for malicious behavior

---

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Foundry
- Base Sepolia ETH ([Get from faucet](https://www.alchemy.com/faucets/base-sepolia))
- MetaMask or compatible wallet

### Installation

```bash
# Clone the repository
git clone https://github.com/big14way/bastion-protocol.git
cd bastion-protocol

# Install dependencies
npm install
forge install

# Setup environment
cp .env.example .env
# Add your PRIVATE_KEY to .env
```

### Deploy Contracts (Optional)

```bash
# Deploy full protocol
forge script script/BastionDemo.s.sol:BastionDemo \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

### Run Frontend

```bash
cd frontend
npm install
npm run dev
```

Visit **[http://localhost:3002](http://localhost:3002)**

### Get Test Tokens

```bash
# Mint test tokens to your wallet
cd "/path/to/bastion" && source .env && \
RECIPIENT=0xYourAddress forge script script/MintToUser.s.sol:MintToUser \
  --rpc-url https://sepolia.base.org --broadcast
```

---

## 📊 Live Contracts (Base Sepolia)

| Contract | Address | Purpose |
|----------|---------|---------|
| **BastionVault** | [`0xF5c0325F85b1d0606669956895c6876b15bc33b6`](https://sepolia.basescan.org/address/0xF5c0325F85b1d0606669956895c6876b15bc33b6) | Main vault for deposits/withdrawals |
| **LendingModule** | [`0x6825B4E72947fE813c840af63105434283c7db2B`](https://sepolia.basescan.org/address/0x6825B4E72947fE813c840af63105434283c7db2B) | Borrowing and lending logic |
| **InsuranceTranche** | [`0x2139FDE811D0aF95b5b030A4583aAFa572d0bfBF`](https://sepolia.basescan.org/address/0x2139FDE811D0aF95b5b030A4583aAFa572d0bfBF) | Depeg insurance coverage |
| **SimpleSwap** | [`0xCcbe164367A0f0a0E129eD88efC1C3641765Eb97`](https://sepolia.basescan.org/address/0xCcbe164367A0f0a0E129eD88efC1C3641765Eb97) | Token swaps with fee collection |
| **VolatilityOracle** | [`0xD1c62D4208b10AcAaC2879323f486D1fa5756840`](https://sepolia.basescan.org/address/0xD1c62D4208b10AcAaC2879323f486D1fa5756840) | Volatility calculations |
| **BastionTaskManager** | [`0x6997d539bC80f514e7B015545E22f3Db5672a5f8`](https://sepolia.basescan.org/address/0x6997d539bC80f514e7B015545E22f3Db5672a5f8) | AVS task coordination |
| **stETH (Mock)** | [`0x60D36283c134bF0f73B67626B47445455e1FbA9e`](https://sepolia.basescan.org/address/0x60D36283c134bF0f73B67626B47445455e1FbA9e) | Test stETH token |
| **USDC (Mock)** | [`0x7BE60377E17aD50b289F306996fa31494364c56a`](https://sepolia.basescan.org/address/0x7BE60377E17aD50b289F306996fa31494364c56a) | Test USDC token |

---

## 🔧 Technical Stack

**Smart Contracts**
- Solidity 0.8.26
- Foundry for testing & deployment
- OpenZeppelin for security
- EigenLayer AVS integration
- Chainlink price feeds

**Frontend**
- Next.js 16 + TypeScript
- Wagmi v3 + Viem
- RainbowKit for wallet connection
- TailwindCSS for styling
- Vercel for hosting

**Infrastructure**
- Base Sepolia L2
- GitHub for version control
- GitHub Actions for CI/CD

---

## 📖 How It Works

### 1. Deposit Flow
```
User deposits stETH → Vault mints LP shares → Insurance coverage activated
```

### 2. Borrow Flow
```
Check collateral → Calculate max borrow → Mint USDC loan → Track health factor
```

### 3. Insurance Flow
```
Swap collects 0.16% fee → Sent to InsuranceTranche → Available for depeg payouts
```

### 4. Depeg Response
```
Oracle detects depeg → AVS verifies → Insurance pays out → LPs made whole
```

---

## 🧪 Testing

```bash
# Run all tests
forge test -vvv

# Run specific test
forge test --match-test testDeposit -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Example Tests

```bash
# Test full protocol flow
forge script script/BastionDemo.s.sol --fork-url https://sepolia.base.org

# Test swap to insurance
forge script script/TestSwapInsuranceV2.s.sol --rpc-url https://sepolia.base.org --broadcast
```

---

## 🛡️ Security

- **Audited Contracts**: OpenZeppelin base contracts
- **AVS Verification**: Dual validation (Oracle + AVS)
- **Reentrancy Guards**: On all state-changing functions
- **Access Control**: Role-based permissions
- **Slashing Protection**: For malicious AVS operators

⚠️ **Testnet Only**: This is experimental software. Do not use with real funds.

---

## 🌐 Environment Variables

```bash
# Required
PRIVATE_KEY=your_wallet_private_key

# Optional
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=your_basescan_key
```

---

## 📚 Project Structure

```
bastion/
├── src/                    # Smart contracts
│   ├── BastionVault.sol
│   ├── LendingModule.sol
│   ├── InsuranceTranche.sol
│   ├── SimpleSwapFeeCollector.sol
│   └── avs/               # AVS integration
├── script/                # Deployment scripts
├── test/                  # Contract tests
├── frontend/              # Next.js app
│   ├── app/              # Pages
│   ├── components/       # React components
│   └── hooks/            # Custom hooks
└── deployments/          # Deployment records
```

---

## 🤝 Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

---

## 🔗 Links

- **Live Demo**: [https://bastion-protocol-three.vercel.app](https://bastion-protocol-three.vercel.app)
- **GitHub**: [github.com/big14way/Bastion](https://github.com/big14way/Bastion)
- **Base Sepolia Explorer**: [sepolia.basescan.org](https://sepolia.basescan.org)

---

## 🎯 Roadmap

- [x] Core lending protocol
- [x] Insurance module with AVS
- [x] Dynamic fee system
- [x] Swap integration with decimal conversion
- [x] Frontend deployment
- [ ] Mainnet launch
- [ ] Additional collateral assets
- [ ] Cross-chain support
- [ ] Mobile app

---

## 💡 Use Cases

1. **Risk-Averse Lenders**: Deposit with automatic insurance protection
2. **Yield Farmers**: Earn from lending + swap fees
3. **Leveraged Traders**: Borrow against basket collateral
4. **Arbitrageurs**: Exploit depeg opportunities
5. **AVS Operators**: Earn rewards for securing the protocol

---

## 🏆 Acknowledgments

Built with:
- [EigenLayer](https://www.eigenlayer.xyz/) for AVS infrastructure
- [Chainlink](https://chain.link/) for price feeds
- [OpenZeppelin](https://openzeppelin.com/) for secure contracts
- [Base](https://base.org/) for L2 scalability

---

**Made with ❤️ by the Bastion team**

⚠️ **Disclaimer**: This is experimental software deployed on testnet. Audit pending for mainnet launch.
