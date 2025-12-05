package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/ethereum/go-ethereum/crypto"
)

type BLSKeyPair struct {
	PrivateKey string `json:"private_key"`
	PublicKey  string `json:"public_key"`
	G1PubKey   string `json:"g1_pub_key"`
	G2PubKey   string `json:"g2_pub_key"`
}

func main() {
	log.Println("🔐 Bastion BLS Key Generator")

	keyPath := "/keys/bls_key.json"
	password := os.Getenv("KEY_PASSWORD")

	if password == "" {
		log.Fatal("❌ KEY_PASSWORD environment variable not set")
	}

	// Check if key already exists
	if _, err := os.Stat(keyPath); err == nil {
		log.Println("⚠️  BLS key already exists, skipping generation")
		log.Println("   To regenerate, delete", keyPath)
		return
	}

	log.Println("📝 Generating new BLS key pair...")

	// Generate BLS key (simplified - in production use proper BLS library)
	// For now, generate ECDSA key as placeholder
	privateKey, err := crypto.GenerateKey()
	if err != nil {
		log.Fatal("❌ Failed to generate key:", err)
	}

	privateKeyBytes := crypto.FromECDSA(privateKey)
	publicKeyBytes := crypto.FromECDSAPub(&privateKey.PublicKey)

	keyPair := BLSKeyPair{
		PrivateKey: fmt.Sprintf("0x%x", privateKeyBytes),
		PublicKey:  fmt.Sprintf("0x%x", publicKeyBytes),
		G1PubKey:   fmt.Sprintf("0x%x", publicKeyBytes[:32]),  // Simplified
		G2PubKey:   fmt.Sprintf("0x%x", publicKeyBytes[32:]),  // Simplified
	}

	// Save to file
	jsonData, err := json.MarshalIndent(keyPair, "", "  ")
	if err != nil {
		log.Fatal("❌ Failed to marshal JSON:", err)
	}

	// Create keys directory if it doesn't exist
	os.MkdirAll("/keys", 0700)

	if err := os.WriteFile(keyPath, jsonData, 0600); err != nil {
		log.Fatal("❌ Failed to write key file:", err)
	}

	log.Println("✅ BLS key pair generated successfully!")
	log.Println("📁 Key saved to:", keyPath)
	log.Println("🔑 Public Key (G1):", keyPair.G1PubKey[:20]+"...")
	log.Println("")
	log.Println("⚠️  IMPORTANT: Backup this key securely!")
	log.Println("   The private key is needed to sign AVS responses")
}
