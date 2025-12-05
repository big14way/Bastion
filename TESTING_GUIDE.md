# 🧪 Bastion Protocol - Comprehensive Testing Guide

Complete guide for testing smart contracts, EigenLayer AVS integration, and Uniswap V4 hooks.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Smart Contract Testing](#smart-contract-testing)
3. [EigenLayer AVS Testing](#eigenlayer-avs-testing)
4. [Uniswap V4 Hooks Testing](#uniswap-v4-hooks-testing)
5. [Integration Testing](#integration-testing)
6. [On-Chain Verification](#on-chain-verification)

---

## 🔧 Prerequisites

### Required Tools
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version  # Should show 0.2.0 or higher
cast --version   # Should show 0.2.0 or higher
```

### Environment Setup
```bash
# Create .env file
cat > .env << EOF
PRIVATE_KEY=your_private_key_here
RPC_URL=https://sepolia.base.org
ETHERSCAN_API_KEY=your_api_key
EOF

# Source environment
source .env
```

---

## 🔬 Smart Contract Testing

### Unit Tests

Run the complete test suite:

```bash
# Run all tests with verbosity
forge test -vvv

# Run specific contract tests
forge test --match-contract BastionVaultTest -vvv
forge test --match-contract InsuranceTrancheTest -vvv
forge test --match-contract LendingModuleTest -vvv

# Run with gas reporting
forge test --gas-report

# Generate coverage report
forge coverage --report lcov
```

### Expected Test Results

✅ **All tests should pass:**
```
[PASS] testDeposit() (gas: 123456)
[PASS] testWithdraw() (gas: 98765)
[PASS] testInsurancePayout() (gas: 156789)
[PASS] testVolatilityCalculation() (gas: 45678)
```

### Fuzz Testing

Test edge cases with fuzzing:

```bash
# Run fuzz tests (10,000 runs)
forge test --match-test testFuzz -vvv

# Increase fuzz runs for thorough testing
FOUNDRY_FUZZ_RUNS=50000 forge test --match-test testFuzz
```

### Invariant Testing

```bash
# Run invariant tests
forge test --match-test testInvariant -vvv
```

Key invariants to verify:
- Total assets = Sum of all deposits - withdrawals
- Shares supply = Sum of all user shares
- Insurance fund >= Minimum threshold

---

## 🔐 EigenLayer AVS Testing

### 1. Deploy AVS Contracts

```bash
# Deploy Service Manager and Task Manager
forge script script/DeployAVS.s.sol:DeployAVS \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify
```

### 2. Verify AVS Deployment

```bash
# Check Service Manager
cast call 0xD1c62D4208b10AcAaC2879323f486D1fa5756840 \
  "owner()" \
  --rpc-url https://sepolia.base.org

# Check Task Manager
cast call 0x6997d539bC80f514e7B015545E22f3Db5672a5f8 \
  "getLatestTaskNum()" \
  --rpc-url https://sepolia.base.org

# Expected output: 0 (no tasks yet)
```

### 3. Register Operator

```bash
# Register as AVS operator
forge script script/RegisterOperator.s.sol:RegisterOperator \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

### 4. Create and Validate Tasks

```bash
# Create a depeg verification task
cast send 0x6997d539bC80f514e7B015545E22f3Db5672a5f8 \
  "createDepegTask(address,uint256)" \
  0x60D36283c134bF0f73B67626B47445455e1FbA9e \
  750000000000000000 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY

# Check task was created
cast call 0x6997d539bC80f514e7B015545E22f3Db5672a5f8 \
  "getLatestTaskNum()" \
  --rpc-url https://sepolia.base.org
# Expected: 1
```

### 5. Submit Task Response

```bash
# Operator submits validation
cast send 0x6997d539bC80f514e7B015545E22f3Db5672a5f8 \
  "respondToTask(uint32,bool)" \
  1 \
  true \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

### ✅ AVS is Working If:
- Service Manager has valid owner
- Task Manager increments task numbers
- Operators can register successfully
- Tasks can be created and responded to
- Multiple operators reach consensus

---

## 🪝 Uniswap V4 Hooks Testing

### 1. Deploy Hook with Address Mining

```bash
# Deploy Bastion Hook (mines valid address)
forge script script/DeployBastion.s.sol:DeployBastion \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify
```

The script automatically:
- Mines a valid hook address (starts with 0x00)
- Deploys with correct permission flags
- Initializes with pool manager

### 2. Verify Hook Permissions

```bash
# Get hook address from deployment
HOOK_ADDRESS=<deployed_hook_address>

# Check permissions
cast call $HOOK_ADDRESS \
  "getHookPermissions()" \
  --rpc-url https://sepolia.base.org
```

Expected permissions bitmap:
```
beforeInitialize: false
afterInitialize: false
beforeSwap: true       ✅
afterSwap: true        ✅
beforeAddLiquidity: true  ✅
afterAddLiquidity: true   ✅
beforeRemoveLiquidity: true ✅
afterRemoveLiquidity: true  ✅
```

### 3. Test Hook with Pool Operations

```bash
# Initialize pool with hook
forge script script/InitializePool.s.sol:InitializePool \
  --rpc-url https://sepolia.base.org \
  --broadcast

# Add liquidity (triggers hook)
forge script script/AddLiquidity.s.sol:AddLiquidity \
  --rpc-url https://sepolia.base.org \
  --broadcast

# Perform swap (triggers dynamic fee)
forge script script/TestSwap.s.sol:TestSwap \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

### 4. Verify Dynamic Fees

```bash
# Check current fee (should vary with volatility)
cast call $HOOK_ADDRESS \
  "getCurrentFee()" \
  --rpc-url https://sepolia.base.org

# Trigger high volatility
cast send 0xD1c62D4208b10AcAaC2879323f486D1fa5756840 \
  "updateVolatility(uint256)" \
  1000 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY

# Check fee increased
cast call $HOOK_ADDRESS \
  "getCurrentFee()" \
  --rpc-url https://sepolia.base.org
```

### ✅ Hooks are Working If:
- Hook address starts with 0x00
- Permissions match expected flags
- Dynamic fees adjust with volatility (500-10000 = 0.05%-1.00%)
- Insurance premiums accumulate on swaps
- Events emit on hook callbacks

---

## 🔄 Integration Testing

### End-to-End Test Script

Run the complete integration test:

```bash
# Run full integration test
forge script script/IntegrationTest.s.sol:IntegrationTest \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  -vvvv
```

This script:
1. Mints test tokens
2. Deposits to vault
3. Triggers hook operations
4. Simulates depeg event
5. Validates AVS consensus
6. Processes insurance payout
7. Withdraws funds

### Manual Integration Test

```bash
# Step 1: Mint tokens
RECIPIENT=<your_address> forge script script/MintToUser.s.sol:MintToUser \
  --rpc-url https://sepolia.base.org --broadcast

# Step 2: Approve and deposit
forge script script/TestDeposit.s.sol:TestDeposit \
  --rpc-url https://sepolia.base.org --broadcast

# Step 3: Trigger depeg simulation
forge script script/SimulateDepeg.s.sol:SimulateDepeg \
  --rpc-url https://sepolia.base.org --broadcast

# Step 4: Verify insurance payout
cast call 0x4d88c574A9D573a5C62C692e4714F61829d7E4a6 \
  "getClaimableAmount(address)" <your_address> \
  --rpc-url https://sepolia.base.org
```

---

## 📊 On-Chain Verification

### Current Deployment Status (Base Sepolia)

```bash
# Vault Stats
echo "=== VAULT STATUS ==="
cast call 0xF5c0325F85b1d0606669956895c6876b15bc33b6 \
  "totalAssets()" --rpc-url https://sepolia.base.org | cast --from-wei

cast call 0xF5c0325F85b1d0606669956895c6876b15bc33b6 \
  "totalSupply()" --rpc-url https://sepolia.base.org | cast --from-wei

# Insurance Tranche
echo "=== INSURANCE STATUS ==="
cast call 0x4d88c574A9D573a5C62C692e4714F61829d7E4a6 \
  "totalPremiums()" --rpc-url https://sepolia.base.org | cast --from-wei

# Volatility Oracle
echo "=== VOLATILITY ==="
cast call 0xD1c62D4208b10AcAaC2879323f486D1fa5756840 \
  "getVolatility()" --rpc-url https://sepolia.base.org
```

### Monitor Events

```bash
# Watch for deposit events
cast logs --address 0xF5c0325F85b1d0606669956895c6876b15bc33b6 \
  --from-block latest \
  --rpc-url https://sepolia.base.org

# Watch for insurance events
cast logs --address 0x4d88c574A9D573a5C62C692e4714F61829d7E4a6 \
  --from-block latest \
  --rpc-url https://sepolia.base.org
```

---

## 🎯 Testing Checklist

### Phase 1: Contract Tests ✅
- [ ] All unit tests pass
- [ ] Fuzz tests complete 10,000+ runs
- [ ] Invariant tests hold
- [ ] Gas optimization verified

### Phase 2: AVS Integration 🔐
- [ ] Service Manager deployed
- [ ] Task Manager deployed
- [ ] Operators registered
- [ ] Tasks created and validated
- [ ] Consensus achieved

### Phase 3: Hook Testing 🪝
- [ ] Hook address mined correctly
- [ ] Permissions set properly
- [ ] Dynamic fees working
- [ ] Insurance premiums collecting
- [ ] Events emitting

### Phase 4: Integration ✨
- [ ] End-to-end script runs
- [ ] Deposits work
- [ ] Withdrawals process
- [ ] Insurance triggers on depeg
- [ ] AVS validates events

---

## 🐛 Troubleshooting

### Common Issues

**"Hook address invalid"**
- Solution: Ensure address starts with 0x00, run address mining script

**"AVS operator not registered"**
- Solution: Run RegisterOperator script first

**"Insufficient allowance"**
- Solution: Approve tokens before deposit

**"Gas estimation failed"**
- Solution: Increase gas limit manually or check contract state

### Debug Commands

```bash
# Check transaction
cast tx <tx_hash> --rpc-url https://sepolia.base.org

# Decode revert reason
cast call --trace <failing_tx> --rpc-url https://sepolia.base.org

# Check contract storage
cast storage <contract_address> <slot> --rpc-url https://sepolia.base.org
```

---

## 📚 Additional Resources

- [User Guide](./USER_GUIDE.md) - Frontend testing guide
- [README](./README.md) - Project overview
- [Deployment Guide](./DEPLOYMENT_GUIDE.md) - Deployment instructions

---

## ✅ Success Criteria

Your implementation is working correctly if:

1. **Vault**: Deposits and withdrawals process correctly
2. **Insurance**: Premiums collect and payouts trigger on depeg
3. **AVS**: Multiple operators validate events
4. **Hooks**: Dynamic fees adjust with volatility
5. **Integration**: All components interact seamlessly

🎉 **Congratulations!** If all tests pass, Bastion Protocol is fully operational!