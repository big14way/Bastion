# Bastion Hook

**A Uniswap v4 hook with dynamic fees and auto-compounding basket rebalancing**

## Overview

BastionHook is a sophisticated Uniswap v4 hook that implements:
- **Volatility-based dynamic fees**: Adjusts swap fees based on market volatility (0.05%, 0.30%, 1.00%)
- **Multi-asset basket rebalancing**: Automatically maintains target weights for stETH, cbETH, rETH, and USDe
- **Auto-compounding**: Accumulates and reinvests rewards from rebasing tokens
- **5% deviation threshold**: Triggers rebalancing when asset weights deviate from targets

## Features

### Dynamic Fee System
- **Low volatility (< 10%)**: 0.05% fee
- **Medium volatility (10-14%)**: 0.30% fee
- **High volatility (≥ 14%)**: 1.00% fee

### Basket Management
- Supports four assets: stETH, cbETH, rETH, USDe
- Configurable target weights (in basis points)
- Automatic rebalancing when deviation exceeds 5%
- Donation tracking for rebasing tokens like stETH

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
├── BastionHook.sol              # Main hook implementation
├── interfaces/
│   └── IVolatilityOracle.sol    # Oracle interface
└── mocks/
    └── MockVolatilityOracle.sol # Testing oracle

test/
└── BastionHook.t.sol            # Comprehensive test suite
```

## Testing

The project includes a comprehensive test suite with 7 tests covering:
- Low, medium, and high volatility fee scenarios
- Fee updates when volatility changes
- Boundary condition testing
- Edge cases (zero and extreme volatility)

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test
forge test --match-test testLowVolatilityFee
```

## Configuration

### Setting Basket Weights

```solidity
BastionHook.BasketConfig memory config = BastionHook.BasketConfig({
    stETHWeight: 4000,  // 40%
    cbETHWeight: 3000,  // 30%
    rETHWeight: 2000,   // 20%
    USDeWeight: 1000    // 10%
});

bastionHook.setBasketConfig(poolId, config);
```

### Mapping Asset Types

```solidity
bastionHook.setAssetType(Currency.wrap(stETHAddress), BastionHook.AssetType.STETH);
bastionHook.setAssetType(Currency.wrap(cbETHAddress), BastionHook.AssetType.CBETH);
```

## Architecture

### Hook Permissions
- `beforeSwap`: Dynamic fee calculation based on volatility
- `afterSwap`: Basket state updates and rebalancing checks
- `afterDonate`: Rebasing token reward accumulation
- `afterAddLiquidity`: Liquidity tracking
- `afterRemoveLiquidity`: Liquidity tracking

### Events
- `RebalanceTriggered(poolId, maxDeviation)`: Emitted when rebalancing is needed
- `BasketRebalanced(poolId, timestamp)`: Emitted after rebalancing
- `DonationReceived(poolId, currency, amount0, amount1)`: Emitted on rebasing rewards

## Requirements

- Solidity ^0.8.26
- Foundry
- Uniswap v4 core contracts
- OpenZeppelin uniswap-hooks

## License

MIT

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Security

This is experimental software. Use at your own risk. Audit recommended before mainnet deployment.
