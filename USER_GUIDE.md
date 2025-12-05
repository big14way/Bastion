# 📚 Bastion Protocol User Guide

Complete guide for testing and using Bastion Protocol on Base Sepolia testnet.

## 🎯 Table of Contents

1. [Frontend Testing](#frontend-testing)
2. [EigenLayer AVS Verification](#eigenlayer-avs-verification)
3. [Uniswap V4 Hooks Testing](#uniswap-v4-hooks-testing)
4. [Common Issues & Solutions](#common-issues--solutions)

---

## 🌐 Frontend Testing

### Initial Setup

1. **Start the Application**
   ```bash
   cd frontend
   npm install
   npm run dev
   ```
   Open http://localhost:3000 in your browser.

2. **Connect Your Wallet**
   - Click "Connect Wallet" button
   - Choose MetaMask or WalletConnect
   - Switch to Base Sepolia network (Chain ID: 84532)
   - Approve connection

3. **Get Test ETH**
   - Visit [Alchemy Base Sepolia Faucet](https://www.alchemy.com/faucets/base-sepolia)
   - Enter your wallet address
   - Receive 0.1 ETH for gas fees

### Testing Deposit Flow

#### Step 1: Get Test Tokens
When you connect your wallet with zero balance, the app shows a yellow banner with your specific mint command:

```bash
cd "/Users/user/gwill/web3/ bastion"
source .env
RECIPIENT=0xYourWalletAddress forge script script/MintToUser.s.sol:MintToUser \
  --rpc-url https://sepolia.base.org --broadcast
```

This mints 100 stETH tokens to your wallet.

#### Step 2: Make a Deposit
1. Navigate to the **Vault** page
2. You should see:
   - Available balance: 100 stETH
   - Current vault TVL: ~10 stETH (from previous deposits)
3. Enter deposit amount (e.g., 10)
4. Click "Deposit"
5. **What happens behind the scenes:**
   - First transaction: Approve vault to spend tokens
   - Second transaction: Deposit tokens to vault
   - The UI handles this automatically!
6. Verify:
   - Your balance decreases by deposit amount
   - You receive vault shares (bstETH)
   - Vault TVL increases

#### Step 3: Test Withdrawal
1. Switch to "Withdraw" tab
2. You'll see your share balance
3. Enter shares to redeem (e.g., 5)
4. Click "Withdraw"
5. Verify:
   - Shares are burned
   - Tokens return to your wallet
   - Vault TVL decreases

### Testing Other Features

#### Insurance Page
1. Navigate to **Insurance** tab
2. View:
   - Coverage status
   - Premium rates
   - Claims history
3. **Demo Mode** (for visualization):
   - Click "Enable Demo Mode" on dashboard
   - Watch simulated depeg event
   - See insurance payout process

#### Borrow Page
1. Navigate to **Borrow** tab
2. View borrowing capabilities (requires LP tokens)
3. Check health factor and LTV ratios

---

## 🔐 EigenLayer AVS Verification

### Understanding the Integration

Bastion uses EigenLayer AVS for:
- Decentralized price oracle validation
- Depeg event verification
- Consensus on insurance payouts

### Verification Steps

#### 1. Check Service Manager
```bash
# Verify deployment
cast call 0xD1c62D4208b10AcAaC2879323f486D1fa5756840 \
  "owner()" \
  --rpc-url https://sepolia.base.org
```

#### 2. Check Task Manager
```bash
# Get latest task number
cast call 0x6997d539bC80f514e7B015545E22f3Db5672a5f8 \
  "getLatestTaskNum()" \
  --rpc-url https://sepolia.base.org
```

#### 3. Verify Operator Registration
```bash
# Check if operator is registered
cast call 0xD1c62D4208b10AcAaC2879323f486D1fa5756840 \
  "isOperatorRegistered(address)" \
  <operator_address> \
  --rpc-url https://sepolia.base.org
```

### How to Know It's Working

✅ **EigenLayer is working if:**
- Service Manager returns valid owner address
- Task Manager shows task count > 0
- Operators are registered (returns true)
- Demo mode shows 4 operators validating depeg events

---

## 🪝 Uniswap V4 Hooks Testing

### Understanding Hook Integration

Bastion's hook provides:
- Dynamic fees based on volatility (0.05% - 1.00%)
- Automated liquidity management
- Insurance premium collection

### Verification Steps

#### 1. Deploy Hook (if not deployed)
```bash
forge script script/DeployBastion.s.sol:DeployBastion \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

The script will:
- Mine a valid hook address
- Deploy with correct flags
- Initialize with pool manager

#### 2. Verify Hook State
```bash
# Check hook configuration
cast call <hook_address> \
  "getHookPermissions()" \
  --rpc-url https://sepolia.base.org
```

Expected permissions:
- `beforeSwap`: true
- `afterSwap`: true
- `beforeAddLiquidity`: true
- `afterAddLiquidity`: true

#### 3. Test Hook Functionality
```bash
# Run test deposit that triggers hooks
forge script script/TestDeposit.s.sol:TestDeposit \
  --rpc-url https://sepolia.base.org \
  --broadcast -vvv
```

### How to Know Hooks Are Working

✅ **Hooks are working if:**
- Dynamic fees adjust with volatility
- Insurance premiums accumulate on swaps
- Liquidity operations trigger hook callbacks
- Test deposits show fee deductions

---

## 🔧 Common Issues & Solutions

### Issue 1: "Asset address not loaded"
**Solution:** Wait a few seconds for the vault to load asset address, or refresh page.

### Issue 2: Transaction shows success but balance doesn't update
**Cause:** Wrong network or RPC issue
**Solution:**
1. Ensure wallet is on Base Sepolia
2. Check transaction on [BaseScan](https://sepolia.basescan.org)
3. Refresh page to refetch data

### Issue 3: Can't see deposit/withdraw buttons
**Solution:** Connect wallet first - buttons only appear when wallet is connected.

### Issue 4: "Insufficient balance" despite having tokens
**Cause:** Tokens on wrong network
**Solution:**
1. Switch to Base Sepolia in wallet
2. Run mint script with correct RPC URL
3. Verify token balance with:
   ```bash
   cast call 0x60D36283c134bF0f73B67626B47445455e1FbA9e \
     "balanceOf(address)" <your_address> \
     --rpc-url https://sepolia.base.org | cast --from-wei
   ```

### Issue 5: Approval transaction fails
**Cause:** Gas estimation issue
**Solution:** Manually increase gas limit in MetaMask

---

## 📊 Monitoring Your Transactions

### Using BaseScan
1. Go to https://sepolia.basescan.org
2. Enter your transaction hash
3. View:
   - Transaction status
   - Gas used
   - Event logs
   - State changes

### Using Cast CLI
```bash
# Get transaction receipt
cast receipt <tx_hash> --rpc-url https://sepolia.base.org

# Decode transaction data
cast tx <tx_hash> --rpc-url https://sepolia.base.org
```

### Console Logs
The app logs extensive information to browser console:
1. Open Developer Tools (F12)
2. Go to Console tab
3. Look for:
   - "Vault state:" - current vault data
   - "Transaction submitted:" - tx hashes
   - "Deposit attempt:" - deposit details

---

## 🎮 Demo Mode Features

Demo mode simulates the full insurance flow:

1. **Activate:** Click "Enable Demo Mode" on dashboard
2. **Watch:**
   - stETH depegs to $750 (25% drop)
   - 4 AVS operators validate the depeg
   - Insurance triggers automatically
   - Payouts distributed to affected LPs
3. **Learn:** See how the protocol protects users

---

## 📝 Testing Checklist

Use this checklist to verify everything works:

### Basic Functionality
- [ ] Frontend loads at http://localhost:3000
- [ ] Wallet connects successfully
- [ ] Network switches to Base Sepolia
- [ ] Wallet address displays in UI

### Token Operations
- [ ] Mint script executes successfully
- [ ] Token balance shows in UI
- [ ] Deposit transaction completes
- [ ] Vault shares received
- [ ] Withdrawal returns tokens

### Data Verification
- [ ] Vault TVL updates in real-time
- [ ] Share price calculates correctly
- [ ] User position displays accurately
- [ ] Transaction history shows on BaseScan

### Advanced Features
- [ ] Demo mode activates
- [ ] Insurance visualization works
- [ ] AVS operators shown in demo
- [ ] Depeg simulation runs correctly

---

## 🆘 Getting Help

### Resources
- [README.md](./README.md) - Project overview
- [TESTING_GUIDE.md](./TESTING_GUIDE.md) - Contract testing
- [Frontend README](./frontend/README.md) - Frontend details

### Debug Commands
```bash
# Check your token balance
cast call 0x60D36283c134bF0f73B67626B47445455e1FbA9e \
  "balanceOf(address)" <your_address> \
  --rpc-url https://sepolia.base.org | cast --from-wei

# Check your vault shares
cast call 0xF5c0325F85b1d0606669956895c6876b15bc33b6 \
  "balanceOf(address)" <your_address> \
  --rpc-url https://sepolia.base.org | cast --from-wei

# Check vault total assets
cast call 0xF5c0325F85b1d0606669956895c6876b15bc33b6 \
  "totalAssets()" \
  --rpc-url https://sepolia.base.org | cast --from-wei
```

---

## 🎯 Summary

You now know how to:
1. ✅ Test the frontend with real transactions
2. ✅ Verify EigenLayer AVS is working
3. ✅ Confirm Uniswap V4 hooks are active
4. ✅ Debug common issues
5. ✅ Monitor your transactions

The protocol is **LIVE on Base Sepolia** - all interactions are real blockchain transactions!