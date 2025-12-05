# Bastion AVS Operator Setup Guide

## Overview

This guide walks you through setting up and running a Bastion AVS operator node with:
- BLS key generation for signing AVS responses
- Chainlink price feed monitoring
- Automated task response service
- Monitoring and metrics

## Prerequisites

### Required Software
- Docker & Docker Compose (v2.0+)
- At least 4GB RAM and 20GB disk space
- Stable internet connection

### Required Accounts & Funds
1. **Operator Wallet**
   - Private key for operator transactions
   - Minimum 0.5 ETH on Base Sepolia for gas

2. **EigenLayer Stake**
   - Minimum 1 ETH staked in EigenLayer
   - Delegated to your operator

3. **RPC Access**
   - Base Sepolia RPC URL
   - Recommended: Alchemy or Infura for reliability

## Quick Start

### 1. Clone and Setup

```bash
cd operator
cp .env.example .env
```

### 2. Configure Environment

Edit `.env` with your settings:

```bash
# Network
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Operator Wallet
OPERATOR_ADDRESS=0xYourOperatorAddress
OPERATOR_PRIVATE_KEY=0xYourPrivateKey

# BLS Key Security
BLS_KEY_PASSWORD=your_secure_password_here

# Contract Addresses (from deployment)
SERVICE_MANAGER_ADDRESS=0x...
TASK_MANAGER_ADDRESS=0x...
AVS_DIRECTORY=0x...
REGISTRY_COORDINATOR=0x...

# Chainlink Price Feeds (Base Sepolia)
CHAINLINK_STETH_USD=0x...  # Get from Chainlink docs
CHAINLINK_ETH_USD=0x...

# Database
POSTGRES_PASSWORD=secure_db_password

# Optional: Grafana
GRAFANA_PASSWORD=admin
```

### 3. Generate BLS Keys

```bash
# Generate BLS keypair
docker-compose run --rm bls-keygen

# Verify key was created
ls -l keys/bls_key.json

# Backup the key securely!
cp keys/bls_key.json ~/bastion-bls-key-backup.json
```

**⚠️ IMPORTANT**: Back up `keys/bls_key.json` securely. You'll need it to sign AVS responses.

### 4. Fund Your Operator

```bash
# Check your operator balance
cast balance $OPERATOR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL

# Get Base Sepolia ETH from faucet
# Visit: https://www.alchemy.com/faucets/base-sepolia
```

You need:
- Minimum 0.5 ETH for gas
- Plus any staking requirements

### 5. Register with EigenLayer

#### Option A: Using Provided Script

```bash
# Set your operator details
export OPERATOR_METADATA_URI="https://your-domain.com/operator-metadata.json"

# Register operator
node scripts/register-operator.js
```

#### Option B: Manual Registration

```bash
# 1. Approve AVS Directory to spend your stake
cast send $DELEGATION_MANAGER \
  "delegateTo(address,tuple(bytes,uint256),bytes32)" \
  $OPERATOR_ADDRESS \
  "(0x,0)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $OPERATOR_PRIVATE_KEY

# 2. Register with AVS
cast send $REGISTRY_COORDINATOR \
  "registerOperator(bytes,string)" \
  $(cat keys/bls_key.json | jq -r '.g1_pub_key') \
  "" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $OPERATOR_PRIVATE_KEY

# 3. Opt-in to Bastion AVS
cast send $AVS_DIRECTORY \
  "registerOperatorToAVS(address,tuple(bytes,bytes32,uint256))" \
  $OPERATOR_ADDRESS \
  "($(cat keys/bls_key.json | jq -r '.g1_pub_key'),0x00,$(date +%s))" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $OPERATOR_PRIVATE_KEY
```

### 6. Start the Operator

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f operator-node

# Check status
docker-compose ps
```

### 7. Verify Operation

```bash
# Check operator health
curl http://localhost:8080/health

# Check metrics
curl http://localhost:9090/metrics

# View in Grafana
open http://localhost:3001
# Login: admin / (your GRAFANA_PASSWORD)
```

## Service Architecture

### Services Running

1. **postgres** (port 5432)
   - Stores operator state and price history

2. **redis** (port 6379)
   - Caching and pub/sub for real-time events

3. **bls-keygen** (one-time)
   - Generates BLS keypair for signing

4. **price-feed-listener** (background)
   - Monitors Chainlink price feeds
   - Detects depeg events
   - Publishes to Redis

5. **operator-node** (port 8080, 9090)
   - Main AVS operator service
   - Registers with EigenLayer
   - Responds to tasks

6. **task-responder** (background)
   - Listens for new tasks from TaskManager
   - Signs responses with BLS key
   - Submits on-chain

7. **prometheus** (port 9091)
   - Metrics collection

8. **grafana** (port 3001)
   - Metrics visualization

## Staking Test ETH

### Get Testnet Tokens

```bash
# 1. Get Base Sepolia ETH
# Visit: https://www.alchemy.com/faucets/base-sepolia

# 2. Bridge to get LST tokens (if needed)
# For testing, you can use mock tokens from deployment

# 3. Wrap ETH for staking
cast send $WETH \
  "deposit()" \
  --value 1ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $OPERATOR_PRIVATE_KEY
```

### Stake in EigenLayer

```bash
# 1. Approve Strategy Manager
cast send $WETH \
  "approve(address,uint256)" \
  $STRATEGY_MANAGER \
  1000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $OPERATOR_PRIVATE_KEY

# 2. Deposit into strategy
cast send $STRATEGY_MANAGER \
  "depositIntoStrategy(address,address,uint256)" \
  $WETH_STRATEGY \
  $WETH \
  1000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $OPERATOR_PRIVATE_KEY

# 3. Verify stake
cast call $STRATEGY_MANAGER \
  "stakerStrategyShares(address,address)(uint256)" \
  $OPERATOR_ADDRESS \
  $WETH_STRATEGY \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Monitoring

### Check Operator Status

```bash
# Operator registration status
cast call $REGISTRY_COORDINATOR \
  "getOperatorStatus(address)(uint8)" \
  $OPERATOR_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Operator stake
cast call $SERVICE_MANAGER \
  "operatorStakes(address)(uint256)" \
  $OPERATOR_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f operator-node
docker-compose logs -f price-feed-listener
docker-compose logs -f task-responder

# Last 100 lines
docker-compose logs --tail=100 operator-node
```

### Metrics Dashboard

Open Grafana at http://localhost:3001

**Default Dashboards:**
- Operator Performance
- Task Response Times
- Price Feed Updates
- Depeg Detection Events

## Task Response Flow

1. **Task Created**
   - TaskManager emits `NewTask` event
   - Operator node detects via event listener

2. **Price Check**
   - Fetch latest prices from Redis cache
   - Calculate depeg percentage

3. **Response Generation**
   - Create response based on task type
   - Sign with BLS private key

4. **Submission**
   - Submit signed response to TaskManager
   - Wait for confirmation

5. **Verification**
   - TaskManager aggregates responses
   - Checks quorum threshold
   - Executes task completion

## Troubleshooting

### Operator Not Registered

```bash
# Check registration status
cast call $REGISTRY_COORDINATOR \
  "getOperatorStatus(address)(uint8)" \
  $OPERATOR_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Re-register if needed
node scripts/register-operator.js
```

### No Tasks Received

```bash
# Check task manager events
cast logs \
  --address $TASK_MANAGER \
  --from-block latest \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Manually create test task (if you're the owner)
cast send $TASK_MANAGER \
  "createTask(uint8,bytes)" \
  0 \
  0x \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Price Feed Not Updating

```bash
# Check price feed logs
docker-compose logs price-feed-listener

# Verify Chainlink feeds are correct
cast call $CHAINLINK_STETH_USD \
  "latestRoundData()(uint80,int256,uint256,uint256,uint80)" \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Check Redis
docker-compose exec redis redis-cli GET "price:stETH/USD"
```

### Database Issues

```bash
# Check Postgres status
docker-compose exec postgres pg_isready

# Connect to database
docker-compose exec postgres psql -U operator -d bastion_operator

# View tables
\dt

# View price history
SELECT * FROM price_history ORDER BY timestamp DESC LIMIT 10;
```

## Security Best Practices

### Key Management

1. **BLS Private Key**
   - Never commit to git
   - Store backup in secure location
   - Use strong password

2. **Operator Private Key**
   - Use hardware wallet if possible
   - Never share or expose
   - Rotate if compromised

3. **Passwords**
   - Use strong, unique passwords
   - Store in password manager
   - Rotate regularly

### Network Security

1. **Firewall Rules**
   ```bash
   # Only expose necessary ports
   # 8080: API (if needed externally)
   # 9090, 9091, 3001: Metrics (localhost only)
   ```

2. **HTTPS/TLS**
   - Use reverse proxy for external access
   - Enable TLS for all external endpoints

### Monitoring

1. **Set Up Alerts**
   - Low balance warnings
   - Failed task responses
   - Depeg detection

2. **Regular Checks**
   - Daily: Check logs for errors
   - Weekly: Verify stake amount
   - Monthly: Review performance metrics

## Maintenance

### Update Operator

```bash
# Pull latest code
git pull origin main

# Rebuild services
docker-compose build

# Restart with zero downtime
docker-compose up -d --no-deps --build operator-node
```

### Backup Database

```bash
# Backup PostgreSQL
docker-compose exec postgres pg_dump -U operator bastion_operator > backup.sql

# Restore
docker-compose exec -T postgres psql -U operator bastion_operator < backup.sql
```

### Clean Up

```bash
# Stop all services
docker-compose down

# Remove volumes (⚠️ deletes all data)
docker-compose down -v

# Remove old images
docker image prune -a
```

## Support

### Getting Help

1. **Check Logs First**
   ```bash
   docker-compose logs --tail=200 operator-node
   ```

2. **GitHub Issues**
   - Report bugs: https://github.com/big14way/Bastion/issues
   - Feature requests welcome

3. **Documentation**
   - [README.md](../README.md)
   - [AVS_IMPLEMENTATION_SUMMARY.md](../AVS_IMPLEMENTATION_SUMMARY.md)

### Useful Commands

```bash
# Restart single service
docker-compose restart operator-node

# View resource usage
docker stats

# Clean build
docker-compose build --no-cache

# Shell into container
docker-compose exec operator-node sh
```

---

## Quick Reference

| Service | Port | Purpose |
|---------|------|---------|
| operator-node | 8080 | API server |
| operator-node | 9090 | Metrics |
| postgres | 5432 | Database |
| redis | 6379 | Cache/PubSub |
| prometheus | 9091 | Metrics |
| grafana | 3001 | Dashboard |

**Minimum Requirements:**
- 0.5 ETH for gas
- 1 ETH staked in EigenLayer
- BLS keypair generated
- Registered with AVS

**Status Check:**
```bash
curl http://localhost:8080/health && echo "✅ Operator running"
```

Good luck running your Bastion AVS operator! 🛡️
