// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/**
 * @title VerifyContracts
 * @notice Script to verify all deployed contracts on block explorer
 * @dev Reads deployment addresses and generates verification commands
 */
contract VerifyContracts is Script {
    function run() external view {
        uint256 chainId = block.chainid;

        console2.log("=== Contract Verification Commands ===");
        console2.log("Chain ID:", chainId);
        console2.log("");

        // Load deployment addresses
        string memory deploymentPath = string.concat("deployments/", vm.toString(chainId), ".json");

        if (!vm.exists(deploymentPath)) {
            console2.log("ERROR: Deployment file not found:", deploymentPath);
            console2.log("Please run deployment script first");
            return;
        }

        string memory json = vm.readFile(deploymentPath);

        // Parse addresses
        address poolManager = vm.parseJsonAddress(json, ".poolManager");
        address bastionHook = vm.parseJsonAddress(json, ".bastionHook");
        address insuranceTranche = vm.parseJsonAddress(json, ".insuranceTranche");
        address lendingModule = vm.parseJsonAddress(json, ".lendingModule");
        address bastionVault = vm.parseJsonAddress(json, ".bastionVault");
        address volatilityOracle = vm.parseJsonAddress(json, ".volatilityOracle");
        address stETH = vm.parseJsonAddress(json, ".stETH");
        address cbETH = vm.parseJsonAddress(json, ".cbETH");
        address rETH = vm.parseJsonAddress(json, ".rETH");
        address USDe = vm.parseJsonAddress(json, ".USDe");
        address USDC = vm.parseJsonAddress(json, ".USDC");

        // Get explorer API key and URL based on chain
        (string memory explorerUrl, string memory apiKeyEnv) = getExplorerConfig(chainId);

        console2.log("Run these commands to verify contracts:\n");

        // Verify VolatilityOracle (no constructor args)
        printVerifyCommand(
            "VolatilityOracle",
            volatilityOracle,
            "src/VolatilityOracle.sol:VolatilityOracle",
            "",
            explorerUrl,
            apiKeyEnv
        );

        // Verify BastionHook
        string memory hookArgs = string.concat(
            " --constructor-args $(cast abi-encode 'constructor(address,address)' ",
            vm.toString(poolManager),
            " ",
            vm.toString(volatilityOracle),
            ")"
        );
        printVerifyCommand(
            "BastionHook",
            bastionHook,
            "src/BastionHook.sol:BastionHook",
            hookArgs,
            explorerUrl,
            apiKeyEnv
        );

        // Verify InsuranceTranche
        string memory insuranceArgs = string.concat(
            " --constructor-args $(cast abi-encode 'constructor(address)' ", vm.toString(bastionHook), ")"
        );
        printVerifyCommand(
            "InsuranceTranche",
            insuranceTranche,
            "src/InsuranceTranche.sol:InsuranceTranche",
            insuranceArgs,
            explorerUrl,
            apiKeyEnv
        );

        // Verify LendingModule (no constructor args)
        printVerifyCommand(
            "LendingModule",
            lendingModule,
            "src/LendingModule.sol:LendingModule",
            "",
            explorerUrl,
            apiKeyEnv
        );

        // Verify BastionVault
        string memory vaultArgs = string.concat(
            " --constructor-args $(cast abi-encode 'constructor(address[],string,string)' '[",
            vm.toString(stETH),
            ",",
            vm.toString(cbETH),
            ",",
            vm.toString(rETH),
            ",",
            vm.toString(USDe),
            "]' 'Bastion Vault' 'bstVault')"
        );
        printVerifyCommand(
            "BastionVault",
            bastionVault,
            "src/BastionVault.sol:BastionVault",
            vaultArgs,
            explorerUrl,
            apiKeyEnv
        );

        // Verify Mock Tokens
        verifyMockToken("stETH", stETH, "Staked ETH", "stETH", explorerUrl, apiKeyEnv);
        verifyMockToken("cbETH", cbETH, "Coinbase Staked ETH", "cbETH", explorerUrl, apiKeyEnv);
        verifyMockToken("rETH", rETH, "Rocket Pool ETH", "rETH", explorerUrl, apiKeyEnv);
        verifyMockToken("USDe", USDe, "Ethena USDe", "USDe", explorerUrl, apiKeyEnv);
        verifyMockToken("USDC", USDC, "USD Coin", "USDC", explorerUrl, apiKeyEnv);

        console2.log("\n=== Verification Complete ===");
        console2.log("Copy and run the commands above to verify all contracts");
    }

    function getExplorerConfig(uint256 chainId)
        internal
        pure
        returns (string memory url, string memory apiKeyEnv)
    {
        if (chainId == 84532) {
            // Base Sepolia
            return ("https://api-sepolia.basescan.org/api", "BASESCAN_API_KEY");
        } else if (chainId == 8453) {
            // Base Mainnet
            return ("https://api.basescan.org/api", "BASESCAN_API_KEY");
        } else if (chainId == 11155111) {
            // Sepolia
            return ("https://api-sepolia.etherscan.io/api", "ETHERSCAN_API_KEY");
        } else if (chainId == 1) {
            // Ethereum Mainnet
            return ("https://api.etherscan.io/api", "ETHERSCAN_API_KEY");
        } else {
            return ("", "EXPLORER_API_KEY");
        }
    }

    function printVerifyCommand(
        string memory name,
        address contractAddress,
        string memory contractPath,
        string memory constructorArgs,
        string memory explorerUrl,
        string memory apiKeyEnv
    ) internal pure {
        console2.log("# Verify", name);
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(contractAddress),
                " ",
                contractPath,
                constructorArgs,
                " --verifier-url ",
                explorerUrl,
                " --etherscan-api-key $",
                apiKeyEnv,
                " --watch"
            )
        );
        console2.log("");
    }

    function verifyMockToken(
        string memory symbol,
        address tokenAddress,
        string memory name,
        string memory tokenSymbol,
        string memory explorerUrl,
        string memory apiKeyEnv
    ) internal pure {
        string memory args = string.concat(
            " --constructor-args $(cast abi-encode 'constructor(string,string,uint8)' '",
            name,
            "' '",
            tokenSymbol,
            "' 18)"
        );

        printVerifyCommand(symbol, tokenAddress, "src/mocks/MockERC20.sol:MockERC20", args, explorerUrl, apiKeyEnv);
    }
}
