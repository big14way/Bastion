// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/BastionHook.sol";
import "../src/InsuranceTranche.sol";
import "../src/interfaces/IVolatilityOracle.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/**
 * @title DeployHookSimple
 * @notice Simplified hook deployment for testnet (without extensive address mining)
 * @dev For production, proper CREATE2 address mining is required
 */
contract DeployHookSimple is Script {
    // Known addresses on Base Sepolia
    address constant INSURANCE_TRANCHE = 0x2139FDE811D0aF95b5b030A4583aAFa572d0bfBF;
    address constant BASTION_VAULT = 0xF5c0325F85b1d0606669956895c6876b15bc33b6;
    address constant VOLATILITY_ORACLE = 0xD1c62D4208b10AcAaC2879323f486D1fa5756840;

    // Uniswap v4 PoolManager address (if available on Base Sepolia)
    // Note: Uniswap v4 may not be deployed on Base Sepolia yet
    address constant POOL_MANAGER = address(0); // UPDATE THIS

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== BastionHook Simple Deployment ===");
        console.log("Deployer:", deployer);
        console.log("\nWARNING: This is a simplified deployment without CREATE2 mining");
        console.log("For production use, proper address mining is required");

        // Check if PoolManager is set
        if (POOL_MANAGER == address(0)) {
            console.log("\n[ERROR] PoolManager address not set");
            console.log("Uniswap v4 may not be deployed on Base Sepolia yet");
            console.log("\nAlternative: Deploy a mock pool manager for testing");
            revert("PoolManager address required");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BastionHook
        console.log("\n=== Deploying BastionHook ===");
        BastionHook hook = new BastionHook(
            IPoolManager(POOL_MANAGER),
            IVolatilityOracle(VOLATILITY_ORACLE)
        );

        console.log("BastionHook deployed at:", address(hook));

        // Authorize hook in InsuranceTranche
        console.log("\n=== Authorizing Hook ===");
        InsuranceTranche insurance = InsuranceTranche(INSURANCE_TRANCHE);
        insurance.setAuthorizedHook(address(hook));
        console.log("Hook authorized in InsuranceTranche");

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("\nContract Addresses:");
        console.log("  BastionHook:", address(hook));
        console.log("  InsuranceTranche:", INSURANCE_TRANCHE);
        console.log("  BastionVault:", BASTION_VAULT);
        console.log("  PoolManager:", POOL_MANAGER);

        console.log("\n=== Next Steps ===");
        console.log("1. Update frontend/lib/contracts/addresses.ts:");
        console.log("   BastionHook:", address(hook));
        console.log("\n2. Initialize a Uniswap v4 pool with this hook");
        console.log("\n3. Execute swaps to generate fees for insurance");

        console.log("\n=== Hook Permissions ===");
        Hooks.Permissions memory perms = hook.getHookPermissions();
        console.log("  afterAddLiquidity:", perms.afterAddLiquidity);
        console.log("  afterRemoveLiquidity:", perms.afterRemoveLiquidity);
        console.log("  beforeSwap:", perms.beforeSwap);
        console.log("  afterSwap:", perms.afterSwap);
        console.log("  afterDonate:", perms.afterDonate);
    }
}
