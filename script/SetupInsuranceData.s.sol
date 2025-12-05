// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SetupInsuranceData is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Contract addresses
        address insuranceTranche = 0x4d88c574A9D573a5C62C692e4714F61829d7E4a6;
        address userAddress = 0x208B2660e5F62CDca21869b389c5aF9E7f0faE89; // Your browser wallet

        vm.startBroadcast(deployerPrivateKey);

        console2.log("==========================================");
        console2.log("SETTING UP INSURANCE DATA");
        console2.log("==========================================");
        console2.log("Deployer:", deployer);
        console2.log("InsuranceTranche:", insuranceTranche);

        InsuranceTranche insurance = InsuranceTranche(insuranceTranche);

        // Check current state
        uint256 currentBalance = insurance.insurancePoolBalance();
        uint256 currentShares = insurance.totalLPShares();

        console2.log("\n=== CURRENT STATE ===");
        console2.log("Insurance Pool Balance:", currentBalance / 10**18, "USDC");
        console2.log("Total LP Shares:", currentShares / 10**18);

        // Update LP position for the user
        if (insurance.owner() == deployer) {
            console2.log("\n=== UPDATING LP POSITION ===");

            // Register 1000 LP shares for the user
            uint256 lpShares = 1000 * 10**18;
            insurance.updateLPPosition(userAddress, lpShares);

            console2.log("Registered", lpShares / 10**18, "LP shares for", userAddress);

            // Check the user's position
            (uint256 shares, uint256 lastUpdate, bool isActive) = insurance.getLPPosition(userAddress);
            console2.log("User's LP shares:", shares / 10**18);
            console2.log("Position active:", isActive);

            // Update total shares to match
            console2.log("\n=== UPDATED TOTALS ===");
            console2.log("Total LP Shares:", insurance.totalLPShares() / 10**18);
            console2.log("Insurance Pool Balance:", insurance.insurancePoolBalance() / 10**18, "USDC");

            // Calculate coverage ratio
            uint256 newTotalShares = insurance.totalLPShares();
            if (newTotalShares > 0 && currentBalance > 0) {
                uint256 ratio = (currentBalance * 100) / newTotalShares;
                console2.log("Coverage Ratio:", ratio, "%");
            }
        } else {
            console2.log("\n[ERROR] Not the owner of InsuranceTranche");
            console2.log("Owner is:", insurance.owner());
        }

        console2.log("\n==========================================");
        console2.log("DONE!");
        console2.log("==========================================");

        vm.stopBroadcast();
    }
}