# BLS Signature Aggregation Upgrade Path

## Current Implementation: ECDSA Signatures

The Bastion AVS currently uses **ECDSA signatures** for operator task responses. This is a proven, secure approach that:
- ✅ Provides cryptographic verification of operator responses
- ✅ Works with standard Ethereum wallets and tooling
- ✅ Has no complex dependency requirements
- ✅ Is battle-tested across many production systems

### How ECDSA Works in Bastion AVS

1. Operator computes task response off-chain
2. Operator signs response with ECDSA: `sign(keccak256(abi.encodePacked(taskIndex, responseData)))`
3. Operator submits response + signature to `BastionTaskManager.respondToTask()`
4. Smart contract verifies signature using `ecrecover`
5. Aggregation happens on-chain through quorum mechanism (stake-weighted voting)

## Future Upgrade: BLS Signature Aggregation

**BLS (Boneh-Lynn-Shacham) signatures** offer significant advantages for production AVS deployments:

### Benefits of BLS

1. **Native Aggregation**: Multiple BLS signatures can be combined into a single signature
2. **Gas Efficiency**: One aggregated signature verification vs. N individual verifications
3. **Reduced Storage**: Store one signature instead of N operator signatures
4. **EigenLayer Native**: Full middleware support with `BLSSignatureChecker`

### Why Not Implemented Now?

**Dependency Complexity**: EigenLayer's BLS middleware has several requirements:
- Solidity 0.8.27+ (our project uses 0.8.26 for Uniswap v4 compatibility)
- `RegistryCoordinator` contract for operator management
- `StakeRegistry` contract for stake tracking
- `BLSApkRegistry` contract for BLS public key registration
- Specific OpenZeppelin versions that conflict with existing dependencies

**Architectural Changes Required**:
- Aggregator service to collect and combine BLS signatures off-chain
- BLS key generation and management for operators
- Integration with EigenLayer's registry contracts

## Upgrade Path

### Phase 1: Preparation (Current)

- [x] ECDSA-based task response system
- [x] Operator registration and stake management
- [x] Quorum-based consensus mechanism
- [x] Three task types: DEPEG_CHECK, VOLATILITY_CALC, RATE_UPDATE
- [x] Off-chain operator implementation in TypeScript

### Phase 2: BLS Infrastructure Setup

1. **Upgrade Solidity Version**
   ```toml
   # foundry.toml
   solc_version = "0.8.27"
   ```

2. **Install BLS Dependencies**
   ```bash
   forge install Layr-Labs/eigenlayer-middleware@latest
   ```

3. **Deploy EigenLayer Registry Contracts**
   - Deploy `SlashingRegistryCoordinator`
   - Deploy `StakeRegistry`
   - Deploy `BLSApkRegistry`
   - Link contracts together

### Phase 3: Smart Contract Migration

1. **Update BastionTaskManager to inherit BLSSignatureChecker**
   ```solidity
   import {BLSSignatureChecker} from "eigenlayer-middleware/BLSSignatureChecker.sol";
   import {IBLSSignatureChecker} from "eigenlayer-middleware/interfaces/IBLSSignatureChecker.sol";
   import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";

   contract BastionTaskManager is BLSSignatureChecker, OwnableUpgradeable, PausableUpgradeable {
       using BN254 for BN254.G1Point;

       constructor(ISlashingRegistryCoordinator _registryCoordinator)
           BLSSignatureChecker(_registryCoordinator)
       {
           _disableInitializers();
       }
   }
   ```

2. **Update respondToTask to use BLS verification**
   ```solidity
   function respondToTask(
       Task calldata task,
       TaskResponse calldata taskResponse,
       NonSignerStakesAndSignature memory nonSignerStakesAndSignature
   ) external {
       // Compute message hash
       bytes32 messageHash = keccak256(abi.encode(taskResponse));

       // Verify BLS aggregated signature
       QuorumStakeTotals memory quorumStakeTotals = checkSignatures(
           messageHash,
           task.quorumNumbers,
           task.taskCreatedBlock,
           nonSignerStakesAndSignature
       );

       // Verify quorum thresholds
       _verifyQuorumThresholds(quorumStakeTotals, task);

       // Store response
       taskResponses[task.taskIndex] = taskResponse;
       emit TaskResponded(task.taskIndex, taskResponse, quorumStakeTotals);
   }
   ```

3. **Update Data Structures**
   ```solidity
   struct TaskResponse {
       uint32 referenceTaskIndex;
       bytes responseData;
       uint32 taskResponseBlock;
       // No individual signatures - aggregated BLS signature provided separately
   }
   ```

### Phase 4: Off-Chain Operator Migration

1. **Install BLS Libraries**
   ```bash
   npm install @noble/bls12-381
   # or
   npm install blst  # C++ bindings for performance
   ```

2. **Implement BLS Key Generation**
   ```typescript
   import * as bls from '@noble/bls12-381';

   // Generate BLS keypair (BN254 curve)
   const privateKey = bls.utils.randomPrivateKey();
   const publicKey = bls.getPublicKey(privateKey);

   // Register public key with BLSApkRegistry
   await blsApkRegistry.registerBLSPublicKey(publicKey, signature);
   ```

3. **Update Signature Service to Use BLS**
   ```typescript
   import * as bls from '@noble/bls12-381';

   class BLSSignatureService {
       private privateKey: Uint8Array;

       async signTaskResponse(taskIndex: number, responseData: string): Promise<BN254.G1Point> {
           const messageHash = ethers.solidityPackedKeccak256(
               ['uint32', 'bytes'],
               [taskIndex, responseData]
           );

           // Sign with BLS
           const signature = await bls.sign(messageHash, this.privateKey);

           return {
               X: signature[0],
               Y: signature[1]
           };
       }
   }
   ```

4. **Create Aggregator Service**
   ```typescript
   class BLSAggregator {
       private operatorSignatures: Map<string, BN254.G1Point> = new Map();

       async collectSignatures(taskIndex: number): Promise<void> {
           // Listen for operator signatures via RPC or P2P
           // This runs off-chain to aggregate before submission
       }

       async aggregateSignatures(): Promise<BN254.G1Point> {
           const signatures = Array.from(this.operatorSignatures.values());

           // Aggregate BLS signatures
           const aggregated = bls.aggregateSignatures(signatures);

           return {
               X: aggregated[0],
               Y: aggregated[1]
           };
       }

       async submitAggregatedResponse(
           task: Task,
           responseData: bytes,
           aggregatedSignature: BN254.G1Point,
           nonSignerInfo: NonSignerStakesAndSignature
       ): Promise<void> {
           await taskManager.respondToTask(
               task,
               { referenceTaskIndex, responseData, taskResponseBlock },
               nonSignerInfo
           );
       }
   }
   ```

### Phase 5: Testing and Deployment

1. **Unit Tests**
   - Test BLS signature generation and verification
   - Test signature aggregation logic
   - Test quorum threshold calculations

2. **Integration Tests**
   - Full task lifecycle with multiple operators
   - BLS aggregation with varying operator sets
   - Edge cases (non-signers, insufficient quorum, etc.)

3. **Testnet Deployment**
   - Deploy to Holesky or Sepolia
   - Register test operators with BLS keys
   - Run full E2E tests with real operators

4. **Mainnet Migration**
   - Gradual rollout with operator coordination
   - Parallel running of ECDSA and BLS systems
   - Cutover once BLS system is proven stable

## Architecture Comparison

### Current ECDSA Architecture

```
┌─────────────────────────────────────────────────────┐
│ Operator 1                                           │
│  └─> Compute Response                               │
│  └─> Sign with ECDSA                                │
│  └─> Submit to TaskManager ──────────┐              │
└───────────────────────────────────────┼──────────────┘
                                        │
┌─────────────────────────────────────┼────────────────┐
│ Operator 2                          │                │
│  └─> Compute Response               │                │
│  └─> Sign with ECDSA                │                │
│  └─> Submit to TaskManager ─────────┤                │
└─────────────────────────────────────┼────────────────┘
                                      │
                                      ▼
                        ┌──────────────────────────┐
                        │   BastionTaskManager     │
                        │  - Verify each ECDSA sig │
                        │  - Count stake on-chain  │
                        │  - Check quorum          │
                        └──────────────────────────┘
```

### Future BLS Architecture

```
┌────────────────────────────────────────────────────┐
│ Operator 1                                          │
│  └─> Compute Response                              │
│  └─> Sign with BLS                                 │
│  └─> Send to Aggregator ──────────┐                │
└────────────────────────────────────┼────────────────┘
                                     │
┌────────────────────────────────────┼────────────────┐
│ Operator 2                         │                │
│  └─> Compute Response              │                │
│  └─> Sign with BLS                 │                │
│  └─> Send to Aggregator ───────────┤                │
└────────────────────────────────────┼────────────────┘
                                     │
                                     ▼
                  ┌──────────────────────────────────┐
                  │      BLS Aggregator (Off-chain)  │
                  │  - Collect operator signatures   │
                  │  - Aggregate into single BLS sig │
                  │  - Build NonSignerInfo           │
                  └───────────┬──────────────────────┘
                              │
                              ▼
                  ┌──────────────────────────────────┐
                  │     BastionTaskManager           │
                  │  - Verify ONE aggregated BLS sig │
                  │  - Check stake via registries    │
                  │  - Verify quorum threshold       │
                  └──────────────────────────────────┘
```

## Gas Cost Comparison

### ECDSA (Current)

- **Per Operator**: ~6,000 gas for `ecrecover` + storage
- **10 Operators**: ~60,000 gas
- **100 Operators**: ~600,000 gas

### BLS (Future)

- **Fixed Cost**: ~350,000 gas for BLS pairing check (regardless of operator count)
- **10 Operators**: ~350,000 gas
- **100 Operators**: ~350,000 gas

**Breakeven Point**: ~58 operators. Beyond this, BLS is more gas-efficient.

## References

- [EigenLayer BLS Signature Checker](https://github.com/Layr-Labs/eigenlayer-middleware/blob/main/src/BLSSignatureChecker.sol)
- [EigenDA BLS Implementation](https://github.com/Layr-Labs/eigenda/blob/master/contracts/src/core/EigenDAServiceManager.sol)
- [Incredible Squaring AVS](https://github.com/Layr-Labs/incredible-squaring-avs)
- [BLS12-381 Specification](https://github.com/paulmillr/noble-bls12-381)
- [EigenLayer AVS Developer Guide](https://docs.eigenlayer.xyz/eigenlayer/avs-guides/avs-developer-guide)

## Timeline Recommendation

**Phase 1 (Current)**: Launch with ECDSA signatures
- ✅ Immediate deployment
- ✅ Proven technology
- ✅ No dependency issues

**Phase 2 (3-6 months)**: Plan BLS Migration
- Monitor EigenLayer middleware stability
- Wait for Solidity/OpenZeppelin compatibility fixes
- Build aggregator infrastructure

**Phase 3 (6-12 months)**: Implement BLS
- Upgrade smart contracts
- Migrate operators to BLS keys
- Deploy aggregator service

**Phase 4 (12+ months)**: Full BLS Production
- All operators using BLS
- ECDSA system deprecated
- Maximum gas efficiency achieved

## Conclusion

The current ECDSA implementation provides a **production-ready AVS** that can be deployed immediately. The upgrade to BLS signatures is a **future optimization** that will improve gas efficiency at scale, but is not required for initial launch or operation.

This phased approach allows Bastion to:
1. ✅ Launch quickly with proven technology
2. ✅ Validate AVS design and operator incentives
3. ✅ Upgrade to BLS when the ecosystem matures
4. ✅ Benefit from EigenLayer's evolving best practices

The ECDSA system is **not a compromise** - it's a pragmatic choice that many successful AVSs use in production today.
