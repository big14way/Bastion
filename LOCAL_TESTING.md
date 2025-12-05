# Bastion Protocol - Local Testing Guide

This guide will help you set up and test the Bastion Protocol locally after pulling the latest changes.

## Prerequisites

1. **Install Foundry** (if not already installed):
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **Install Node.js** (v18 or later) for frontend testing

## Quick Start

### 1. Clone and Install Dependencies

```bash
# Clone the repository
git clone https://github.com/big14way/Bastion.git
cd Bastion

# Install Foundry dependencies
forge install

# Install frontend dependencies
cd frontend && npm install && cd ..
```

### 2. Set Up Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your values:
# - PRIVATE_KEY: Your deployer private key
# - BASE_SEPOLIA_RPC_URL: Your RPC endpoint
# - ETHERSCAN_API_KEY: For contract verification (optional)
```

### 3. Compile Contracts

```bash
# Compile all contracts
forge build

# Expected output: Compiler run successful!
```

### 4. Run Tests

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/BastionVault.t.sol -vvv

# Run tests with gas reporting
forge test --gas-report

# Run tests with coverage
forge coverage
```

## Test Structure

The test suite includes:

| Test File | Coverage |
|-----------|----------|
| `test/BastionVault.t.sol` | Vault deposits, withdrawals, fees, oracle pricing |
| `test/BastionHook.t.sol` | Dynamic fees, basket rebalancing |
| `test/LendingModule.t.sol` | Borrowing, repayment, liquidation, interest accrual |
| `test/InsuranceTranche.t.sol` | Premium collection, depeg detection, payouts |
| `test/BastionIntegration.t.sol` | Full protocol integration |

## Testing New Features

### Testing Ownable2Step (Two-Step Ownership)

```solidity
// In your test:
function testOwnershipTransfer() public {
    // Step 1: Current owner initiates transfer
    vault.transferOwnership(newOwner);

    // Verify pending owner is set
    assertEq(vault.pendingOwner(), newOwner);

    // Step 2: New owner accepts
    vm.prank(newOwner);
    vault.acceptOwnership();

    // Verify ownership transferred
    assertEq(vault.owner(), newOwner);
    assertEq(vault.pendingOwner(), address(0));
}
```

### Testing Oracle Pricing

```solidity
// Deploy and configure price oracle
ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(weth);
oracle.configurePriceFeed(stETH, stETHPriceFeed, 1 hours);

// Configure vault to use oracle
vault.setPriceOracle(address(oracle));
vault.setOraclePricing(true);

// Now totalAssets() uses oracle prices
uint256 total = vault.totalAssets();
```

### Testing Admin Pool Withdrawal

```solidity
function testAdminWithdrawFromPool() public {
    // Fund the pool
    lendingModule.fundPool(1000e18);

    // Withdraw (only available liquidity)
    lendingModule.withdrawFromPool(500e18);

    assertEq(lendingModule.totalLendingPool(), 500e18);
}
```

### Testing Basket Swapper

```solidity
// Deploy swapper
BasketSwapper swapper = new BasketSwapper(uniswapRouter);

// Configure routes
swapper.configureSwapRoute(USDC, stETH, uniswapRouter, 100); // 1% slippage

// Authorize vault to swap
swapper.setAuthorizedSwapper(address(vault), true);

// Execute swap
swapper.swap(USDC, stETH, 1000e6, 0, address(vault));
```

## Local Deployment (Anvil)

### Start Local Node

```bash
# Terminal 1: Start Anvil
anvil --fork-url $BASE_SEPOLIA_RPC_URL
```

### Deploy Contracts

```bash
# Terminal 2: Deploy
forge script script/DeployBastion.s.sol:DeployBastion \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    -vvvv
```

## Frontend Testing

### Start Development Server

```bash
cd frontend
npm run dev
```

### Connect to Local Node

1. Add Anvil network to MetaMask:
   - RPC URL: `http://127.0.0.1:8545`
   - Chain ID: `31337`

2. Import Anvil's default account:
   - Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

## Common Issues & Solutions

### Issue: `forge build` fails with missing dependencies

```bash
# Solution: Install all dependencies
forge install
git submodule update --init --recursive
```

### Issue: Tests fail with "Stack too deep"

```bash
# Solution: Use --via-ir flag
forge build --via-ir
forge test --via-ir
```

### Issue: RPC rate limiting

```bash
# Solution: Use a dedicated RPC provider or add delays
forge test --rpc-url $YOUR_RPC --delay 1
```

### Issue: Gas estimation fails

```bash
# Solution: Increase gas limit
forge test --gas-limit 30000000
```

## Verification Checklist

After pulling the latest changes, verify:

- [ ] `forge build` compiles successfully
- [ ] `forge test` passes all tests
- [ ] New features work as documented:
  - [ ] Ownable2Step: Two-step ownership transfer works
  - [ ] Oracle Pricing: `totalAssets()` uses oracle when enabled
  - [ ] Pool Withdrawal: Admin can withdraw available liquidity
  - [ ] Basket Swapper: DEX swaps execute correctly
- [ ] Frontend connects and displays correctly

## Contract Addresses (Base Sepolia)

```
BastionVault:      0xF5c0325F85b1d0606669956895c6876b15bc33b6
InsuranceTranche:  0xa6212BbC875009948cBf2429Dc23f962261Dd5Dc
LendingModule:     0x6825B4E72947fE813c840af63105434283c7db2B
VolatilityOracle:  0xD1c62D4208b10AcAaC2879323f486D1fa5756840
```

## Support

If you encounter issues:
1. Check the [GitHub Issues](https://github.com/big14way/Bastion/issues)
2. Review the test files for usage examples
3. Check `DEPOSIT_FLOW.txt` for detailed flow diagrams
