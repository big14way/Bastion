# Bastion AVS Operator

Complete operator infrastructure for the Bastion AVS (Actively Validated Service) on EigenLayer.

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your settings

# 2. Run setup script
./scripts/setup.sh

# 3. Register as operator
cd scripts && npm install && npm run register

# 4. Start operator infrastructure
docker-compose up -d

# 5. View logs
docker-compose logs -f operator-node

# 6. Check status
curl http://localhost:8080/status
```

## Overview

This operator infrastructure performs off-chain computation for four task types:

1. **Price Verification**: Verifies asset prices from Chainlink feeds
2. **Depeg Detection**: Monitors assets for depeg events using price feeds
3. **Volatility Calculation**: Computes realized volatility from historical price data
4. **Risk Assessment**: Evaluates risk based on price, volatility, and depeg status

The operator uses BLS signatures for cryptographic security and submits responses to AVS smart contracts for aggregation and consensus.

## Architecture

The operator infrastructure consists of 8 Docker services:

### Core Services

1. **operator-node** (Port 8080, 9090)
   - Main AVS operator service
   - Listens for tasks from TaskManager contract
   - Submits signed responses on-chain
   - Exposes REST API and Prometheus metrics

2. **task-responder** (Port 9092)
   - Processes tasks and generates responses
   - Handles 4 task types: price verification, depeg detection, volatility calculation, risk assessment
   - Signs responses with BLS keys
   - Publishes responses via Redis

3. **price-feed-listener** (Port 9091)
   - Monitors Chainlink price feeds (stETH/USD, ETH/USD)
   - Detects depeg events (>20% threshold)
   - Stores price history in PostgreSQL
   - Publishes alerts via Redis

4. **bls-keygen**
   - One-time BLS keypair generation
   - Saves keys to `/keys/bls_key.json`
   - Exits after completion

### Infrastructure Services

5. **postgres** (Port 5432) - Operator state and task tracking
6. **redis** (Port 6379) - Real-time pub/sub messaging
7. **prometheus** (Port 9090) - Metrics collection
8. **grafana** (Port 3000) - Metrics visualization

## Prerequisites

- Docker and Docker Compose
- Base Sepolia RPC endpoint
- Operator private key
- Test ETH for gas (at least 0.1 ETH)
- Deployed AVS contract addresses

## Configuration

Create a `.env` file in the `operator/` directory:

```bash
# Operator Identity
OPERATOR_PRIVATE_KEY=0x...
BLS_KEY_PATH=/keys/bls_key.json

# Network
BASE_SEPOLIA_RPC=https://sepolia.base.org

# Contracts
TASK_MANAGER_ADDRESS=0x...
SERVICE_MANAGER_ADDRESS=0x...
DELEGATION_MANAGER_ADDRESS=0x...
REGISTRY_COORDINATOR_ADDRESS=0x...
AVS_DIRECTORY_ADDRESS=0x...

# Chainlink Feeds
STETH_USD_FEED=0x...
ETH_USD_FEED=0x...

# Database
POSTGRES_USER=bastion
POSTGRES_PASSWORD=bastion
POSTGRES_DB=bastion_operator
```

## Usage

### Starting the Infrastructure

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### Stopping the Infrastructure

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: deletes data)
docker-compose down -v
```

### API Access

```bash
# Health check
curl http://localhost:8080/health

# Operator status
curl http://localhost:8080/status

# Pending tasks
curl http://localhost:8080/tasks/pending

# Prometheus metrics
curl http://localhost:8080/metrics

# Grafana dashboard
open http://localhost:3000
```

## Task Types

The operator handles 4 types of tasks:

- **Type 0: Price Verification** - Verifies asset prices from Chainlink feeds
- **Type 1: Depeg Detection** - Monitors for stablecoin/LSD depegs (>20% threshold)
- **Type 2: Volatility Calculation** - Calculates realized volatility from price history
- **Type 3: Risk Assessment** - Evaluates risk based on price, volatility, and depeg status

See [OPERATOR_SETUP.md](OPERATOR_SETUP.md) for detailed task specifications.

## Registration

### 1. Fund Operator Wallet

Get test ETH from Base Sepolia faucet (at least 0.1 ETH):
https://www.coinbase.com/faucets/base-ethereum-goerli-faucet

### 2. Run Registration Script

```bash
cd scripts
npm install
npm run register
```

The script will:
- Register with EigenLayer DelegationManager
- Register with AVS RegistryCoordinator
- Register with AVS Directory
- Verify registration status

### 3. Start Operator

```bash
docker-compose up -d
```

## Monitoring

### Grafana Dashboards

Access at http://localhost:3000 (admin/admin)

### Prometheus Metrics

Key metrics:
- `bastion_tasks_received_total` - Total tasks received
- `bastion_tasks_processed_total{status}` - Tasks processed
- `bastion_operator_balance_eth` - Operator balance
- `bastion_responses_generated_total{task_type}` - Responses by type
- `bastion_depeg_events_total` - Depeg events detected

### Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f operator-node

# Filter for errors
docker-compose logs -f | grep "ERROR"
```

## Troubleshooting

### BLS Keys Not Generated
```bash
docker-compose logs bls-keygen
docker-compose run bls-keygen
```

### Database Connection Errors
```bash
docker-compose ps postgres
docker-compose logs postgres
docker-compose exec postgres pg_isready -U bastion
```

### Tasks Not Being Processed
```bash
docker-compose logs operator-node | grep "Listening for"
curl http://localhost:8080/tasks/pending
```

### Low Balance Warning
```bash
curl http://localhost:8080/status | jq .operator
# Fund operator address from Base Sepolia faucet
```

## Database Management

### Access PostgreSQL
```bash
docker-compose exec postgres psql -U bastion -d bastion_operator
```

### Backup Database
```bash
docker-compose exec postgres pg_dump -U bastion bastion_operator > backup.sql
```

### Restore Database
```bash
cat backup.sql | docker-compose exec -T postgres psql -U bastion bastion_operator
```

## Security

- Private keys stored in `.env` (gitignored)
- BLS keys in Docker volume (not in image)
- PostgreSQL and Redis not exposed publicly
- Services run in isolated Docker network
- Use different keys for testnet and mainnet

## Resources

- [EigenLayer Documentation](https://docs.eigenlayer.xyz)
- [AVS Developer Guide](https://docs.eigenlayer.xyz/eigenlayer/avs-guides/avs-developer-guide)
- [Bastion Protocol](../README.md)
- [Detailed Setup Guide](OPERATOR_SETUP.md)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)

For detailed setup instructions and task specifications, see [OPERATOR_SETUP.md](OPERATOR_SETUP.md).
