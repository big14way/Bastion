// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";

contract DeployInsurance is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // For now, we'll use the deployer as the authorized hook
        address authorizedHook = deployer;

        vm.startBroadcast(deployerPrivateKey);

        console2.log("==========================================");
        console2.log("DEPLOYING INSURANCE TRANCHE");
        console2.log("==========================================");
        console2.log("Deployer:", deployer);
        console2.log("Authorized Hook:", authorizedHook);

        // Deploy InsuranceTranche
        InsuranceTranche insurance = new InsuranceTranche(authorizedHook);

        console2.log("\n=== DEPLOYED CONTRACTS ===");
        console2.log("InsuranceTranche:", address(insurance));

        // Initialize with test data
        console2.log("\n=== INITIALIZING TEST DATA ===");

        // Register LP position for the user
        address userAddress = 0x208B2660e5F62CDca21869b389c5aF9E7f0faE89;
        uint256 lpShares = 1000 * 10**18; // 1000 LP shares

        insurance.updateLPPosition(userAddress, lpShares);
        console2.log("Registered", lpShares / 10**18, "LP shares for", userAddress);

        // Check the position
        (uint256 shares, , bool isActive) = insurance.getLPPosition(userAddress);
        console2.log("User's LP shares:", shares / 10**18);
        console2.log("Position active:", isActive);
        console2.log("Total LP Shares:", insurance.totalLPShares() / 10**18);

        console2.log("\n==========================================");
        console2.log("DEPLOYMENT COMPLETE!");
        console2.log("==========================================");
        console2.log("\nAdd this to your .env and frontend/lib/contracts/addresses.ts:");
        console2.log("InsuranceTranche:", address(insurance));

        vm.stopBroadcast();
    }
}