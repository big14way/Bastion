# Bastion AVS Operator

Off-chain operator implementation for the Bastion AVS (Actively Validated Service) on EigenLayer.

## Overview

This TypeScript operator listens for task events from the Bastion AVS smart contracts and performs off-chain computation for three task types:

1. **DEPEG_CHECK**: Monitors assets for depeg events using Chainlink price feeds
2. **VOLATILITY_CALC**: Computes realized volatility from historical price data
3. **RATE_UPDATE**: Calculates optimal interest rates based on utilization

The operator signs all responses with ECDSA signatures and submits them back to the AVS smart contracts for aggregation and consensus.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Bastion AVS Operator                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────────────────┐      │
│  │   Operator   │◄────────│  Event Listener          │      │
│  │   (Main)     │         │  (NewTaskCreated)        │      │
│  └──────┬───────┘         └──────────────────────────┘      │
│         │                                                     │
│         ├──► Task Handler                                    │
│         │    ├─► DEPEG_CHECK (Chainlink Prices)             │
│         │    ├─► VOLATILITY_CALC (Historical Prices)        │
│         │    └─► RATE_UPDATE (Utilization Curve)            │
│         │                                                     │
│         └──► Signature Service (ECDSA)                       │
│              └─► Submit Response to AVS                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Node.js v18+ or TypeScript runtime
- Access to an Ethereum RPC endpoint (WebSocket required for event listening)
- Private key for an operator wallet registered with the Bastion AVS
- Sufficient stake in the BastionServiceManager contract

## Installation

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build
```

## Configuration

Create a `.env` file in the `operator/` directory with the following variables:

```bash
# Required: Ethereum RPC endpoint (must support WebSocket)
RPC_URL=wss://mainnet.infura.io/ws/v3/YOUR_PROJECT_ID

# Required: Operator private key (must be registered with AVS)
PRIVATE_KEY=0x...

# Required: Contract addresses
TASK_MANAGER_ADDRESS=0x...
SERVICE_MANAGER_ADDRESS=0x...

# Optional: Chainlink price feed addresses (defaults to mainnet)
CHAINLINK_ETH_USD=0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
CHAINLINK_STETH=0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8

# Optional: Logging configuration
LOG_LEVEL=info  # debug, info, warn, error
```

## Usage

### Development Mode

Run the operator in development mode with auto-recompilation:

```bash
npm run dev
```

### Production Mode

Build and run in production:

```bash
npm run build
npm start
```

### Docker Deployment

```bash
# Build Docker image
docker build -t bastion-avs-operator .

# Run container
docker run -d \
  --name bastion-operator \
  --env-file .env \
  bastion-avs-operator
```

## Task Types

### DEPEG_CHECK

Monitors assets for depeg events by comparing Chainlink price feeds.

**Input (taskData)**:
- `assetAddress` (address): Address of the asset to check
- `timestamp` (uint256): Task creation timestamp

**Output (responseData)**:
- `isDepegged` (bool): True if asset is depegged
- `currentPrice` (uint256): Current price ratio (18 decimals)
- `deviation` (uint256): Deviation from peg in basis points

**Algorithm**:
1. Fetch ETH/USD price from Chainlink
2. Fetch asset/USD price from Chainlink
3. Calculate asset/ETH ratio
4. Compare to 1:1 peg and compute deviation
5. Return depeg status if deviation > 5% (500 bps)

### VOLATILITY_CALC

Computes realized volatility from historical price movements.

**Input (taskData)**:
- `poolAddress` (address): Address of the pool
- `timeWindow` (uint256): Time window in seconds
- `timestamp` (uint256): Task creation timestamp

**Output (responseData)**:
- `volatility` (uint256): Realized volatility in basis points
- `timestamp` (uint256): Computation timestamp

**Algorithm**:
1. Fetch historical price data over the time window
2. Calculate log returns: ln(P_t / P_{t-1})
3. Compute standard deviation of returns
4. Annualize volatility: σ_annual = σ * sqrt(periods_per_year)
5. Convert to basis points and return

### RATE_UPDATE

Calculates optimal interest rate based on lending pool utilization.

**Input (taskData)**:
- `lendingModuleAddress` (address): Address of the lending module
- `utilization` (uint256): Current utilization in basis points
- `timestamp` (uint256): Task creation timestamp

**Output (responseData)**:
- `newRate` (uint256): Optimal interest rate in basis points
- `timestamp` (uint256): Computation timestamp

**Algorithm**:
Uses a kinked interest rate model (similar to Aave/Compound):

```
if utilization <= 80%:
  rate = 2% + (utilization * 4%) / 80%
else:
  rate = 2% + 4% + ((utilization - 80%) * 60%) / 20%
```

## Signature Scheme

The operator uses ECDSA signatures following the Ethereum standard:

1. Compute message hash: `keccak256(abi.encodePacked(taskIndex, responseData))`
2. Sign with Ethereum prefix: `"\x19Ethereum Signed Message:\n32" + messageHash`
3. Submit signature along with response data to `respondToTask()`

The smart contract verifies signatures using `ecrecover` to ensure only registered operators can submit responses.

## Monitoring

The operator logs all activities to:
- Console (colorized output)
- `combined.log` (all logs)
- `error.log` (errors only)

### Key Metrics to Monitor

- Task processing latency
- Signature verification success rate
- Transaction confirmation times
- WebSocket connection health
- Chainlink price feed freshness

### Example Logs

```
2024-11-29 20:30:15 [info]: Starting Bastion AVS Operator...
2024-11-29 20:30:16 [info]: Operator address: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb
2024-11-29 20:30:17 [info]: Operator registered with stake: 1000.0 ETH
2024-11-29 20:30:17 [info]: Operator is now listening for tasks...
2024-11-29 20:32:45 [info]: New task created: #42, type: 0
2024-11-29 20:32:45 [info]: Processing task #42, type: DEPEG_CHECK
2024-11-29 20:32:46 [info]: DEPEG_CHECK: Checking asset 0x...
2024-11-29 20:32:47 [info]: DEPEG_CHECK result: price=1000000000000000000, deviation=250bps, depegged=false
2024-11-29 20:32:48 [info]: Submitted task response transaction: 0xabc...
2024-11-29 20:32:50 [info]: Task response confirmed in block 18456789
2024-11-29 20:32:50 [info]: Successfully submitted response for task #42
```

## Security Considerations

### Private Key Management

- **NEVER** commit private keys to version control
- Use environment variables or secret management systems
- Rotate keys regularly
- Use hardware wallets or HSMs for production

### Operational Security

- Run operators in isolated environments
- Use minimal base images for Docker containers
- Implement rate limiting for RPC calls
- Monitor for abnormal behavior and slashing events

### Signature Security

- Verify message hashes before signing
- Log all signature operations for audit trails
- Implement signature replay protection
- Validate response data before submission

## Troubleshooting

### Operator not receiving tasks

1. Check WebSocket connection: `wscat -c $RPC_URL`
2. Verify operator is registered: Call `isOperatorRegistered(address)`
3. Check stake requirement: Call `getOperatorStake(address)`
4. Verify task manager contract address

### Signature verification failures

1. Ensure correct message hash construction
2. Verify wallet address matches registered operator
3. Check that response data encoding matches contract expectations
4. Review signature format (v, r, s components)

### Chainlink price feed errors

1. Verify price feed addresses for the correct network
2. Check price feed freshness (updatedAt timestamp)
3. Ensure sufficient RPC rate limits for multiple calls
4. Handle stale price data gracefully

## Development

### Project Structure

```
operator/
├── src/
│   ├── index.ts            # Entry point
│   ├── operator.ts         # Main operator class
│   ├── taskHandler.ts      # Task processing logic
│   ├── signatureService.ts # Signature generation
│   └── logger.ts           # Winston logger config
├── package.json
├── tsconfig.json
└── README.md
```

### Adding New Task Types

1. Add task type enum to `BastionTaskManager.sol`
2. Create handler method in `taskHandler.ts`
3. Add case in `operator.ts` switch statement
4. Update documentation

### Testing

```bash
# Run linter
npm run lint

# Unit tests (TODO: implement)
npm test
```

## References

- [EigenLayer AVS Documentation](https://docs.eigenlayer.xyz/eigenlayer/avs-guides/avs-developer-guide)
- [Incredible Squaring AVS Example](https://github.com/Layr-Labs/incredible-squaring-avs)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [Ethers.js Documentation](https://docs.ethers.org/)

## License

MIT
