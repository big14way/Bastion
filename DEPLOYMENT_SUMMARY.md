# Bastion Protocol - Deployment Summary

## Deployment Status

✅ **Successfully deployed to Base Sepolia** (Chain ID: 84532)

## Deployed Contracts

| Contract | Address | Status |
|----------|---------|--------|
| **Mock Tokens** | | |
| stETH | `0xAC6C322B0BB6019cB012Cdf0C1B49d4672792d17` | ✅ Deployed |
| cbETH | `0xB39887974582d55BE705843A4A2A4b071C348729` | ✅ Deployed |
| rETH | `0x73fd79706e56809ead9b5C8C1B825d41E829cC34` | ✅ Deployed |
| USDe | `0x21A1f4E8D59f042673c16Ef826A85f5B162f77FE` | ✅ Deployed |
| **Core Contracts** | | |
| VolatilityOracle | `0xD1c62D4208b10AcAaC2879323f486D1fa5756840` | ✅ Deployed |
| InsuranceTranche | `0x4d88c574A9D573a5C62C692e4714F61829d7E4a6` | ✅ Deployed |
| LendingModule | `0x6997d539bC80f514e7B015545E22f3Db5672a5f8` | ✅ Deployed |
| BastionVault | `0x9244bb06F995BBB94fFCAdC366f9444fB77ee253` | ✅ Deployed |

## Deployment Details

- **Network**: Base Sepolia Testnet
- **Chain ID**: 84532
- **Deployer Address**: `0x208B2660e5F62CDca21869b389c5aF9E7f0faE89`
- **RPC URL**: https://sepolia.base.org
- **Block Explorer**: https://sepolia.basescan.org/

## Contract Configuration

### VolatilityOracle
- Default volatility: 500 basis points (5%)
- Admin: Deployer address

### InsuranceTranche
- Authorized hook: Deployer address
- Depeg threshold: 20% (2000 basis points)
- Coverage ratio: 85%

### LendingModule
- Authorized hook: Deployer address
- Stablecoin: USDe (`0x21A1f4E8D59f042673c16Ef826A85f5B162f77FE`)
- Default interest rate: 500 basis points (5%)
- Max LTV: 70%
- Liquidation threshold: 75%

### BastionVault
- Underlying asset: stETH
- Name: "Bastion stETH Vault"
- Symbol: "bstETH"
- Standard: ERC-4626

## Verification

To verify contracts on Basescan:

```bash
# VolatilityOracle
forge verify-contract 0xD1c62D4208b10AcAaC2879323f486D1fa5756840 \
  src/VolatilityOracle.sol:VolatilityOracle \
  --chain base-sepolia

# InsuranceTranche
forge verify-contract 0x4d88c574A9D573a5C62C692e4714F61829d7E4a6 \
  src/InsuranceTranche.sol:InsuranceTranche \
  --chain base-sepolia \
  --constructor-args $(cast abi-encode "constructor(address)" "0x208B2660e5F62CDca21869b389c5aF9E7f0faE89")

# LendingModule
forge verify-contract 0x6997d539bC80f514e7B015545E22f3Db5672a5f8 \
  src/LendingModule.sol:LendingModule \
  --chain base-sepolia \
  --constructor-args $(cast abi-encode "constructor(address,address,uint256)" "0x208B2660e5F62CDca21869b389c5aF9E7f0faE89" "0x21A1f4E8D59f042673c16Ef826A85f5B162f77FE" 500)

# BastionVault
forge verify-contract 0x9244bb06F995BBB94fFCAdC366f9444fB77ee253 \
  src/BastionVault.sol:BastionVault \
  --chain base-sepolia \
  --constructor-args $(cast abi-encode "constructor(address,string,string)" "0xAC6C322B0BB6019cB012Cdf0C1B49d4672792d17" "Bastion stETH Vault" "bstETH")
```

## Next Steps

### 1. Get Testnet ETH

You'll need Base Sepolia ETH to interact with the contracts:
- Visit https://www.alchemy.com/faucets/base-sepolia
- Or use https://faucet.quicknode.com/base/sepolia

### 2. Test Token Minting

Since these are mock ERC20 tokens, you can mint test tokens:

```solidity
// Connect to Base Sepolia and call mint() on any token
stETH.mint(yourAddress, 1000 ether);
```

### 3. Frontend Setup

The frontend has been updated with deployed addresses. To run it:

```bash
cd frontend
npm run dev
```

Open http://localhost:3000

### 4. WalletConnect Setup (Optional)

For full functionality, get a WalletConnect Project ID:
1. Go to https://cloud.walletconnect.com/
2. Create a new project
3. Copy your Project ID
4. Add to `frontend/.env.local`:
   ```
   NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id_here
   ```

### 5. Deploy AVS Contracts (Optional)

To deploy the EigenLayer AVS contracts:

```bash
forge script script/DeployAVS.s.sol \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

## View on Block Explorer

- [stETH](https://sepolia.basescan.org/address/0xAC6C322B0BB6019cB012Cdf0C1B49d4672792d17)
- [VolatilityOracle](https://sepolia.basescan.org/address/0xD1c62D4208b10AcAaC2879323f486D1fa5756840)
- [InsuranceTranche](https://sepolia.basescan.org/address/0x4d88c574A9D573a5C62C692e4714F61829d7E4a6)
- [LendingModule](https://sepolia.basescan.org/address/0x6997d539bC80f514e7B015545E22f3Db5672a5f8)
- [BastionVault](https://sepolia.basescan.org/address/0x9244bb06F995BBB94fFCAdC366f9444fB77ee253)

## Testing the Protocol

### 1. Deposit into Vault

```typescript
// Approve stETH
await stETH.approve(bastionVault, amount);

// Deposit
await bastionVault.deposit(amount, yourAddress);
```

### 2. Borrow Against LP Position

```typescript
// Register collateral (as authorized hook)
await lendingModule.registerCollateral(lpToken, amount);

// Borrow USDe
await lendingModule.borrow(borrowAmount);
```

### 3. Check Insurance Coverage

```typescript
// View coverage ratio
const ratio = await insuranceTranche.coverageRatio();

// Check premium pool
const pool = await insuranceTranche.premiumPool();
```

## Troubleshooting

### Issue: Transactions failing

**Solution**: Ensure you have enough Base Sepolia ETH. Get more from the faucet.

### Issue: Contract not verified

**Solution**: Run the verification commands above with your BASESCAN_API_KEY in `.env`

### Issue: Frontend not connecting

**Solution**:
1. Check you're on Base Sepolia network (Chain ID: 84532)
2. Add the network to your wallet:
   - Network Name: Base Sepolia
   - RPC URL: https://sepolia.base.org
   - Chain ID: 84532
   - Currency: ETH
   - Explorer: https://sepolia.basescan.org/

## Support

For issues or questions:
- Create an issue on GitHub
- Check the [README.md](README.md) for more information
- Review the [QUICK_START.md](QUICK_START.md) guide

---

**Deployment completed successfully!** 🎉
