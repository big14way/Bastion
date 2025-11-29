# Bastion Protocol

**A comprehensive DeFi infrastructure suite built on Uniswap v4 with dynamic fees, basket management, and depeg insurance**

## Overview

Bastion Protocol is a sophisticated DeFi platform that combines three core components:

1. **BastionHook** - Uniswap v4 hook with volatility-based dynamic fees and basket rebalancing
2. **BastionVault** - ERC-4626 tokenized vault wrapper for multi-asset baskets
3. **InsuranceTranche** - Chainlink-powered depeg protection for basket assets

## Core Features

### 1. Dynamic Fee System (BastionHook)
- **Volatility-based fee adjustment**: Automatically adjusts swap fees based on market conditions
  - Low volatility (< 10%): 0.05% fee
  - Medium volatility (10-14%): 0.30% fee
  - High volatility (≥ 14%): 1.00% fee
- **Oracle integration**: Uses IVolatilityOracle for real-time volatility data

### 2. Basket Management
- **Multi-asset support**: stETH, cbETH, rETH, USDe
- **Configurable weights**: Target allocations in basis points (10000 = 100%)
- **Auto-rebalancing**: 5% deviation threshold triggers rebalancing
- **Rebasing token support**: Donation tracking for tokens like stETH

### 3. ERC-4626 Vault (BastionVault)
- **Standard compliance**: Full ERC-4626 tokenized vault implementation
- **Deposit/withdrawal**: With configurable fees (max 10%)
- **Basket tracking**: Monitors underlying multi-asset basket value
- **Pro-rata shares**: Issues vault tokens proportional to deposits
- **Max 10 assets**: Supports up to 10 different basket assets

### 4. Depeg Insurance (InsuranceTranche)
- **Chainlink price feeds**: Real-time asset price monitoring
- **20% depeg threshold**: Configurable per-asset deviation limits
- **Premium collection**: Portion of swap fees fund insurance pool
- **Pro-rata payouts**: Distributes insurance pool to affected LPs
- **Stale price protection**: 2-hour maximum price age validation
- **Emergency controls**: Pause mechanism and emergency withdrawal

## Installation

```bash
# Clone the repository
git clone https://github.com/big14way/Bastion.git
cd Bastion

# Install dependencies
forge install

# Run tests
forge test
```

## Project Structure

```
src/
├── BastionHook.sol              # Uniswap v4 hook with dynamic fees
├── BastionVault.sol             # ERC-4626 tokenized vault
├── InsuranceTranche.sol         # Chainlink-powered depeg insurance
├── interfaces/
│   └── IVolatilityOracle.sol    # Volatility oracle interface
└── mocks/
    └── MockVolatilityOracle.sol # Mock oracle for testing

test/
├── BastionHook.t.sol            # Hook tests (7 tests)
├── BastionVault.t.sol           # Vault tests (20 tests)
└── InsuranceTranche.t.sol       # Insurance tests (23 tests)
```

## Testing

The project includes a comprehensive test suite with **58 total tests**:

### BastionHook Tests (7 tests)
- Low, medium, and high volatility fee scenarios
- Fee updates when volatility changes
- Boundary condition testing
- Edge cases (zero and extreme volatility)

### BastionVault Tests (20 tests)
- Basic deposit/withdraw functionality
- Fee calculation and distribution
- Basket asset management
- Multi-user scenarios
- Preview and conversion functions
- Edge cases and validation

### InsuranceTranche Tests (23 tests)
- Premium collection from swap fees
- Depeg detection with Chainlink oracles
- Payout execution to affected LPs
- LP position management
- Stale price detection
- Emergency pause and withdrawal
- Asset configuration and activation

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test
forge test --match-test testLowVolatilityFee
```

## Configuration Examples

### 1. Configure BastionHook Basket Weights

```solidity
// Set target basket allocation
BastionHook.BasketConfig memory config = BastionHook.BasketConfig({
    stETHWeight: 4000,  // 40%
    cbETHWeight: 3000,  // 30%
    rETHWeight: 2000,   // 20%
    USDeWeight: 1000    // 10%
});

bastionHook.setBasketConfig(poolId, config);

// Map currencies to asset types
bastionHook.setAssetType(Currency.wrap(stETHAddress), BastionHook.AssetType.STETH);
bastionHook.setAssetType(Currency.wrap(cbETHAddress), BastionHook.AssetType.CBETH);
```

### 2. Configure BastionVault

```solidity
// Deploy vault with base asset (e.g., USDC)
BastionVault vault = new BastionVault(
    IERC20(usdcAddress),
    "Bastion Vault USDC",
    "bvUSDC"
);

// Add basket assets with weights
vault.addBasketAsset(stETHAddress, 4000);  // 40%
vault.addBasketAsset(cbETHAddress, 3000);  // 30%
vault.addBasketAsset(rETHAddress, 2000);   // 20%
vault.addBasketAsset(usdeAddress, 1000);   // 10%

// Set fees (100 = 1%)
vault.setFees(50, 100);  // 0.5% deposit, 1% withdrawal
```

### 3. Configure InsuranceTranche

```solidity
// Deploy insurance with authorized hook
InsuranceTranche insurance = new InsuranceTranche(hookAddress);

// Configure asset with Chainlink price feed
insurance.configureAsset(
    stETHAddress,              // Asset token
    stETHPriceFeedAddress,     // Chainlink price feed
    1e8,                       // Target price (in feed decimals)
    2000                       // 20% depeg threshold
);

// Hook collects premiums
insurance.collectPremiumWithToken(usdcAddress, premiumAmount);

// Register LP positions
insurance.updateLPPosition(lpAddress, sharesAmount);
```

## Architecture

### Component Integration Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Uniswap v4 Pool                          │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │           BastionHook (Hook Contract)              │     │
│  │                                                    │     │
│  │  • beforeSwap: Dynamic fee calculation            │     │
│  │  • afterSwap: Basket rebalancing                  │     │
│  │  • afterDonate: Rebasing token rewards            │     │
│  │  • Collects premiums → InsuranceTranche           │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                          ↓
          ┌───────────────┴────────────────┐
          ↓                                ↓
┌──────────────────────┐      ┌───────────────────────────┐
│   BastionVault       │      │  InsuranceTranche         │
│   (ERC-4626)         │      │  (Depeg Protection)       │
│                      │      │                           │
│  • Deposit/Withdraw  │      │  • Premium Collection     │
│  • Basket Tracking   │      │  • Chainlink Oracles      │
│  • Share Issuance    │      │  • Payout Distribution    │
└──────────────────────┘      └───────────────────────────┘
```

### Hook Permissions (BastionHook)
- `beforeSwap`: Dynamic fee calculation based on volatility
- `afterSwap`: Basket state updates and rebalancing checks
- `afterDonate`: Rebasing token reward accumulation
- `afterAddLiquidity`: Liquidity tracking
- `afterRemoveLiquidity`: Liquidity tracking

### Key Events

**BastionHook**
- `RebalanceTriggered(poolId, maxDeviation)`: Rebalancing needed
- `BasketRebalanced(poolId, timestamp)`: Rebalancing completed
- `DonationReceived(poolId, currency, amount0, amount1)`: Rebasing rewards

**BastionVault**
- `Deposit(caller, owner, assets, shares)`: Vault deposit
- `Withdraw(caller, receiver, owner, assets, shares)`: Vault withdrawal
- `AssetAdded(token, weight)`: Basket asset added
- `FeesUpdated(depositFee, withdrawalFee)`: Fee configuration

**InsuranceTranche**
- `PremiumCollected(from, amount, newBalance)`: Premium received
- `DepegDetected(asset, price, targetPrice, deviation)`: Depeg event
- `PayoutExecuted(asset, totalPayout, affectedLPs, price, deviation)`: Insurance payout
- `LPPositionUpdated(lp, oldShares, newShares)`: LP position change

## Dependencies

- **Solidity**: ^0.8.26
- **Foundry**: Latest version
- **Uniswap v4**: Core contracts and periphery
- **OpenZeppelin**: Contracts and uniswap-hooks
- **Chainlink**: Brownie contracts for price feeds

Install all dependencies:
```bash
forge install
```

## License

MIT

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Security

This is experimental software. Use at your own risk. Audit recommended before mainnet deployment.
