// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {TestCollateralHook} from "../src/TestCollateralHook.sol";
import {LendingModule} from "../src/LendingModule.sol";

contract SetupTestBorrowing is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // Contract addresses
        address testHook = 0x992ABFf498562b5eFE035218D0274eA13D451BAe;
        address lendingModule = 0x6825B4E72947fE813c840af63105434283c7db2B;

        vm.startBroadcast(deployerPrivateKey);

        console2.log("==========================================");
        console2.log("SETTING UP TEST BORROWING");
        console2.log("==========================================");
        console2.log("User:", user);
        console2.log("TestCollateralHook:", testHook);
        console2.log("LendingModule:", lendingModule);

        // First, update the authorized hook in LendingModule
        LendingModule lm = LendingModule(lendingModule);

        console2.log("\n=== UPDATING AUTHORIZED HOOK ===");
        try lm.updateAuthorizedHook(testHook) {
            console2.log("[SUCCESS] Hook authorized!");
        } catch {
            console2.log("[INFO] Cannot update hook - only owner can do this");
            console2.log("[INFO] Continuing with test collateral registration...");
        }

        // Register test collateral for the user
        TestCollateralHook hook = TestCollateralHook(testHook);

        // Simulate $10,000 worth of LP tokens
        uint256 lpAmount = 1000 * 10**18; // 1000 LP tokens
        uint256 collateralValue = 10000 * 10**18; // $10,000 USD value

        console2.log("\n=== REGISTERING TEST COLLATERAL ===");
        console2.log("LP Amount:", lpAmount / 10**18, "tokens");
        console2.log("Collateral Value: $", collateralValue / 10**18);

        try hook.registerTestCollateral(user, lpAmount, collateralValue) {
            console2.log("[SUCCESS] Collateral registered!");

            // Check the user's borrowing capacity
            uint256 maxBorrow = lm.getMaxBorrow(user);
            console2.log("\n=== YOUR BORROWING CAPACITY ===");
            console2.log("Maximum you can borrow: $", maxBorrow / 10**18);
            console2.log("This is 70% of your collateral value (LTV ratio)");

            // Check health factor
            uint256 healthFactor = lm.getHealthFactor(user);
            console2.log("\n=== HEALTH METRICS ===");
            if (healthFactor == type(uint256).max) {
                console2.log("Health Factor: INFINITE (no debt)");
            } else {
                console2.log("Health Factor:", healthFactor / 100);
            }

            // Check pool liquidity
            uint256 totalPool = lm.totalLendingPool();
            uint256 totalBorrowed = lm.totalBorrowed();
            uint256 available = totalPool - totalBorrowed;

            console2.log("\n=== LENDING POOL STATUS ===");
            console2.log("Total Pool: $", totalPool / 10**18);
            console2.log("Total Borrowed: $", totalBorrowed / 10**18);
            console2.log("Available Liquidity: $", available / 10**18);

            if (available > 0 && maxBorrow > 0) {
                console2.log("\n[SUCCESS] You can now borrow up to $", maxBorrow / 10**18, "USDC!");
                console2.log("Use the frontend Borrow page to borrow funds");
            }

        } catch Error(string memory reason) {
            console2.log("[ERROR]", reason);
        } catch {
            console2.log("[ERROR] Failed to register collateral");
            console2.log("This might be because:");
            console2.log("1. User already has registered collateral");
            console2.log("2. The hook is not authorized");
            console2.log("3. The caller is not the owner of TestCollateralHook");
        }

        console2.log("\n==========================================");
        console2.log("SETUP COMPLETE!");
        console2.log("==========================================");

        vm.stopBroadcast();
    }
}