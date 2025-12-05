# Bastion Protocol

A next-generation DeFi protocol combining Uniswap V4 hooks, EigenLayer AVS validation, and automated risk management to provide secure yield-generating vaults with liquidity provision and insurance protection.

## Live Deployment

**Base Sepolia Testnet (Chain ID: 84532)**

| Contract | Address | Status |
|----------|---------|--------|
| BastionVault | `0xF5c0325F85b1d0606669956895c6876b15bc33b6` | ✅ Live |
| InsuranceTranche | `0xa6212BbC875009948cBf2429Dc23f962261Dd5Dc` | ✅ Live |
| LendingModule | `0x6825B4E72947fE813c840af63105434283c7db2B` | ✅ Live |
| VolatilityOracle | `0xD1c62D4208b10AcAaC2879323f486D1fa5756840` | ✅ Live |
| stETH (Mock) | `0x60D36283c134bF0f73B67626B47445455e1FbA9e` | ✅ Live |
| USDC (Mock) | `0x7BE60377E17aD50b289F306996fa31494364c56a` | ✅ Live |

## Quick Start

### Prerequisites
- MetaMask or WalletConnect wallet
- Base Sepolia ETH ([faucet](https://www.alchemy.com/faucets/base-sepolia))
- Node.js 18+

### 1. Setup & Run

```bash
# Clone repository
git clone https://github.com/big14way/Bastion.git
cd bastion

# Install and run frontend
cd frontend
npm install
npm run dev

# Open http://localhost:3000
```

### 2. Get Test Tokens

```bash
# From project root
source .env
RECIPIENT=0xYourWalletAddress forge script script/MintToUser.s.sol:MintToUser \
  --rpc-url https://sepolia.base.org --broadcast
```

### 3. Use the Protocol

**Vault Operations:**
- Deposit stETH to receive vault shares
- Withdraw shares to reclaim assets
- Automatic yield generation and insurance coverage

**Borrowing:**
- Use LP positions as collateral
- Borrow up to 70% LTV
- Monitor health factor (liquidation at 1.0)
- 5% APY interest rate

**Insurance:**
- Automatic coverage for LP positions
- Protection against depegs
- Real-time coverage tracking

## Features

### Core Protocol Features

1. **ERC-4626 Vaults**
   - Standardized vault interface
   - Multi-asset support (stETH, cbETH, rETH, USDe)
   - Automatic yield optimization
   - Real-time share calculation

2. **Collateralized Borrowing**
   - Borrow USDC against LP positions
   - Maximum 70% LTV ratio
   - Health factor monitoring with visual indicators
   - Automatic interest accrual at 5% APY
   - One-click repayment with approval handling

3. **Insurance Protection**
   - Automatic insurance for all depositors
   - Coverage against asset depegs
   - Premium collection from swap fees
   - Claims processed via EigenLayer AVS

4. **Dynamic Fee Management**
   - Volatility-based fee tiers
   - Low: 0.05%, Medium: 0.30%, High: 1.00%
   - Automatic premium collection
   - Real-time oracle updates

### Frontend Features

1. **Dashboard**
   - Real-time protocol metrics
   - TVL tracking
   - Insurance pool status
   - User position overview

2. **Vault Page**
   - Deposit/withdraw interface
   - Share balance tracking
   - Transaction history
   - Success notifications

3. **Borrow Page**
   - Tabbed interface for borrowing/repayment
   - Health factor visualization with color coding
   - Available credit display
   - Automatic refresh after transactions
   - Success messages with auto-dismiss

4. **Insurance Page**
   - Live coverage tracking from blockchain
   - Pool balance monitoring
   - Coverage ratio display
   - Claims interface (coming soon)

## Architecture

```
┌────────────────────────────────────┐
│     Frontend (Next.js + wagmi)     │
├────────────────────────────────────┤
│        Smart Contracts              │
│  ┌──────────┐  ┌───────────────┐   │
│  │  Vault   │  │   Insurance   │   │
│  │ ERC-4626 │  │   Tranche     │   │
│  └──────────┘  └───────────────┘   │
│  ┌──────────┐  ┌───────────────┐   │
│  │ Lending  │  │   Volatility  │   │
│  │  Module  │  │    Oracle     │   │
│  └──────────┘  └───────────────┘   │
├────────────────────────────────────┤
│     EigenLayer AVS Integration     │
│  ┌──────────────────────────────┐  │
│  │  Service & Task Managers     │  │
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
```

## Development

### Smart Contract Development

```bash
# Run tests
forge test -vvv

# Coverage report
forge coverage

# Gas optimization report
forge test --gas-report

# Format code
forge fmt
```

### Frontend Development

```bash
cd frontend

# Development server
npm run dev

# Build for production
npm run build

# Type checking
npm run type-check
```

### Deployment

```bash
# Deploy core contracts
forge script script/DeployBastion.s.sol \
  --rpc-url base-sepolia \
  --broadcast \
  --verify

# Deploy insurance with test data
forge script script/DeployInsurance.s.sol \
  --rpc-url base-sepolia \
  --broadcast

# Setup test positions
forge script script/SetupInsuranceData.s.sol \
  --rpc-url base-sepolia \
  --broadcast
```

## Technical Implementation

### Smart Contracts

**BastionVault.sol**
- ERC-4626 compliant vault
- Multi-asset deposits (stETH, cbETH, rETH, USDe)
- Automated yield strategies
- Integration with insurance and lending modules

**LendingModule.sol**
- LP token collateralization
- Health factor calculation
- Interest accrual mechanism
- Liquidation protection

**InsuranceTranche.sol**
- LP position tracking
- Premium collection from fees
- Depeg event handling
- Claims processing

**VolatilityOracle.sol**
- Real-time volatility tracking
- Dynamic fee calculation
- Price feed integration

### Frontend Hooks

**useLending.ts**
- Real-time position tracking
- Automatic data refresh on transactions
- Health factor monitoring
- USDC approval handling

**useInsurance.ts**
- Coverage data fetching
- Premium tracking
- Claims interface

**useVault.ts**
- Deposit/withdraw functionality
- Share balance tracking
- Allowance management

## Security Considerations

⚠️ **This is experimental software for testnet use only**

- Contracts are NOT audited
- Use only test tokens
- Report security issues privately
- Do not use on mainnet

## Testing Guide

### Manual Testing Checklist

1. **Vault Operations**
   - [ ] Connect wallet to Base Sepolia
   - [ ] Mint test tokens
   - [ ] Approve and deposit stETH
   - [ ] Verify share balance updates
   - [ ] Withdraw shares successfully

2. **Borrowing**
   - [ ] Register LP position
   - [ ] Borrow USDC against collateral
   - [ ] Monitor health factor changes
   - [ ] Repay loan with interest
   - [ ] Verify automatic refresh

3. **Insurance**
   - [ ] Check coverage display
   - [ ] Verify live data indicator
   - [ ] Monitor pool balance

## Troubleshooting

### Common Issues

**"0 credits available" despite having collateral:**
- Ensure LP position is registered on-chain
- Check that collateral value is calculated correctly
- Verify LendingModule ABI includes all functions

**Transaction failures:**
- Check wallet is on Base Sepolia network
- Ensure sufficient ETH for gas
- Verify token approvals

**Data not updating:**
- Frontend implements double refresh (immediate + 2s delay)
- Manual refresh available via refetch button
- Check RPC connection status

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/name`)
3. Write tests for new features
4. Ensure all tests pass
5. Submit pull request

## License

MIT License - see LICENSE file for details

## Contact

- GitHub: [@big14way](https://github.com/big14way)
- Project: [Bastion Protocol](https://github.com/big14way/Bastion)

---

Built for the Ethereum ecosystem