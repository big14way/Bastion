#!/bin/bash

set -e

echo "🛡️  Bastion AVS Operator Setup"
echo "================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env with your configuration before proceeding"
    echo "   Required: OPERATOR_ADDRESS, OPERATOR_PRIVATE_KEY, contract addresses"
    exit 1
fi

# Load environment
source .env

# Validate required variables
REQUIRED_VARS=(
    "OPERATOR_ADDRESS"
    "OPERATOR_PRIVATE_KEY"
    "BASE_SEPOLIA_RPC_URL"
    "BLS_KEY_PASSWORD"
)

echo "🔍 Validating configuration..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ] || [ "${!var}" == "0xYourOperatorAddress" ] || [ "${!var}" == "0xYourPrivateKeyHere" ]; then
        echo "❌ Error: $var not set in .env"
        exit 1
    fi
done

echo "✅ Configuration validated"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose found"
echo ""

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p keys logs monitoring/dashboards

# Generate BLS key if not exists
if [ ! -f keys/bls_key.json ]; then
    echo "🔐 Generating BLS keypair..."
    docker-compose run --rm bls-keygen

    if [ -f keys/bls_key.json ]; then
        echo "✅ BLS key generated"
        echo "⚠️  IMPORTANT: Backup keys/bls_key.json securely!"
    else
        echo "❌ Failed to generate BLS key"
        exit 1
    fi
else
    echo "✅ BLS key already exists"
fi

echo ""

# Check operator balance
echo "💰 Checking operator balance..."
BALANCE=$(cast balance $OPERATOR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL 2>/dev/null || echo "0")
echo "   Balance: $BALANCE wei"

if [ "$BALANCE" == "0" ]; then
    echo "⚠️  Warning: Operator has zero balance"
    echo "   Get testnet ETH from: https://www.alchemy.com/faucets/base-sepolia"
fi

echo ""

# Pull Docker images
echo "🐳 Pulling Docker images..."
docker-compose pull

# Build services
echo "🔨 Building services..."
docker-compose build

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Ensure operator has at least 0.5 ETH for gas"
echo "2. Register operator with EigenLayer (see OPERATOR_SETUP.md)"
echo "3. Start services: docker-compose up -d"
echo "4. Check status: docker-compose ps"
echo "5. View logs: docker-compose logs -f operator-node"
echo ""
echo "For detailed instructions, see: OPERATOR_SETUP.md"
