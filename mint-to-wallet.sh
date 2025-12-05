#!/bin/bash

# Script to mint stETH tokens to a specific wallet address

echo "==========================================
🪙 MINT stETH TOKENS TO YOUR WALLET
==========================================

This script will mint 100 stETH tokens to your wallet address.

Please enter your wallet address (the one connected in the app):"

read -r WALLET_ADDRESS

# Validate address format
if [[ ! "$WALLET_ADDRESS" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "❌ Invalid wallet address format. Please provide a valid Ethereum address."
    exit 1
fi

echo "
Minting 100 stETH to: $WALLET_ADDRESS
Network: Base Sepolia
Token: 0x60D36283c134bF0f73B67626B47445455e1FbA9e
"

# Source the .env file for private key
source .env

# Run the mint script
RECIPIENT=$WALLET_ADDRESS forge script script/MintToUser.s.sol:MintToUser \
    --rpc-url https://sepolia.base.org \
    --broadcast \
    -vv

echo "
✅ Done! Check your wallet balance in the app.
The UI should now show your available stETH balance.
"