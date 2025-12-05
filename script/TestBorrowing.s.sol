// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {LendingModule} from "../src/LendingModule.sol";

contract TestBorrowing is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Contract address
        address lendingModule = 0x6997d539bC80f514e7B015545E22f3Db5672a5f8;

        vm.startBroadcast(deployerPrivateKey);

        address user = vm.addr(deployerPrivateKey);
        console2.log("\n==========================================");
        console2.log("BASTION BORROWING STATUS CHECK");
        console2.log("==========================================\n");
        console2.log("Your Address:", user);

        // Check your position
        (
            uint256 lpTokenAmount,
            uint256 collateralValue,
            uint256 borrowedAmount,
            uint256 interestRate,
            ,
            uint256 accruedInterest,
            bool isActive
        ) = LendingModule(lendingModule).positions(user);

        console2.log("\n=== YOUR POSITION ===");
        if (!isActive) {
            console2.log("[X] No active position found");
            console2.log("\nTO START BORROWING:");
            console2.log("1. Add liquidity to Uniswap V4 pools (when integrated)");
            console2.log("2. Your LP tokens will be automatically registered as collateral");
            console2.log("3. You can then borrow up to 70% of your collateral value");
            console2.log("\nCURRENT STATUS:");
            console2.log("- Uniswap V4 integration: Not yet deployed");
            console2.log("- Alternative: Deploy a test hook that can register collateral");
        } else {
            console2.log("[SUCCESS] Active position found!");
            console2.log("LP Tokens:", lpTokenAmount / 10**18);
            console2.log("Collateral Value: $", collateralValue / 10**18);
            console2.log("Current Borrowed: $", borrowedAmount / 10**18);
            console2.log("Accrued Interest: $", accruedInterest / 10**18);
            console2.log("Interest Rate:", interestRate / 100, "%");

            // Calculate borrowing capacity
            uint256 maxBorrow = LendingModule(lendingModule).getMaxBorrow(user);
            console2.log("\n=== BORROWING CAPACITY ===");
            console2.log("Maximum you can borrow: $", maxBorrow / 10**18);

            if (maxBorrow > 0) {
                console2.log("[SUCCESS] You have borrowing capacity!");
                console2.log("You can borrow up to $", maxBorrow / 10**18, "USDC");
            } else {
                console2.log("[X] No borrowing capacity available");
                console2.log("You've already borrowed the maximum amount");
            }

            // Check health factor
            uint256 healthFactor = LendingModule(lendingModule).getHealthFactor(user);
            console2.log("\n=== RISK METRICS ===");
            console2.log("Health Factor:", healthFactor / 100);
            if (healthFactor < 150) {
                console2.log("[!] WARNING: Low health factor - risk of liquidation");
            } else {
                console2.log("[SUCCESS] Healthy position");
            }
        }

        // Check lending pool liquidity
        uint256 totalPool = LendingModule(lendingModule).totalLendingPool();
        uint256 totalBorrowed = LendingModule(lendingModule).totalBorrowed();
        uint256 availableLiquidity = totalPool - totalBorrowed;

        console2.log("\n=== LENDING POOL STATUS ===");
        console2.log("Total Pool Size: $", totalPool / 10**18);
        console2.log("Total Borrowed: $", totalBorrowed / 10**18);
        console2.log("Available Liquidity: $", availableLiquidity / 10**18);

        if (availableLiquidity == 0) {
            console2.log("[X] No liquidity available in pool");
            console2.log("The lending pool needs to be funded with USDC");
        }

        console2.log("\n==========================================");

        vm.stopBroadcast();
    }
}