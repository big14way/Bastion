// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {LendingModule} from "../src/LendingModule.sol";

contract EnableTestBorrowing is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);

        // New LendingModule with funded pool
        address lendingModule = 0x6825B4E72947fE813c840af63105434283c7db2B;
        address lpToken = 0x60D36283c134bF0f73B67626B47445455e1FbA9e; // Mock stETH as LP token

        vm.startBroadcast(deployerPrivateKey);

        console2.log("==========================================");
        console2.log("ENABLING TEST BORROWING");
        console2.log("==========================================");
        console2.log("User:", user);
        console2.log("LendingModule:", lendingModule);

        LendingModule lm = LendingModule(lendingModule);

        // Since we are the owner who deployed the contract, we can update the hook to ourselves
        // This allows us to register collateral directly for testing
        console2.log("\n=== SETTING UP AUTHORIZATION ===");
        console2.log("Current authorized hook:", lm.authorizedHook());
        console2.log("Current owner:", lm.owner());

        if (lm.owner() == user) {
            console2.log("[SUCCESS] You are the owner!");

            // Check if we're already the authorized hook
            if (lm.authorizedHook() == user) {
                console2.log("[SUCCESS] You are already the authorized hook!");
            }

            // Now register collateral for ourselves
            uint256 lpAmount = 1000 * 10**18; // 1000 LP tokens
            uint256 collateralValue = 10000 * 10**18; // $10,000 USD

            console2.log("\n=== REGISTERING COLLATERAL ===");
            console2.log("LP Amount:", lpAmount / 10**18, "tokens");
            console2.log("Collateral Value: $", collateralValue / 10**18);

            lm.registerCollateral(user, lpToken, lpAmount, collateralValue);
            console2.log("[SUCCESS] Collateral registered!");

            // Check borrowing capacity
            uint256 maxBorrow = lm.getMaxBorrow(user);
            console2.log("\n=== YOUR BORROWING CAPACITY ===");
            console2.log("Maximum you can borrow: $", maxBorrow / 10**18, "USDC");
            console2.log("This is 70% of your $", collateralValue / 10**18, "collateral");

            // Check pool liquidity
            uint256 totalPool = lm.totalLendingPool();
            uint256 totalBorrowed = lm.totalBorrowed();
            uint256 available = totalPool - totalBorrowed;

            console2.log("\n=== LENDING POOL STATUS ===");
            console2.log("Total Pool: $", totalPool / 10**18);
            console2.log("Total Borrowed: $", totalBorrowed / 10**18);
            console2.log("Available Liquidity: $", available / 10**18);

            if (available > 0 && maxBorrow > 0) {
                uint256 borrowAmount = maxBorrow > available ? available : maxBorrow;
                console2.log("\n[SUCCESS] You can now borrow up to $", borrowAmount / 10**18, "USDC!");
                console2.log("Go to the frontend Borrow page to borrow funds");
            }

        } else {
            console2.log("[ERROR] You are not the owner of the LendingModule");
            console2.log("Owner is:", lm.owner());
            console2.log("Cannot proceed with test setup");
        }

        console2.log("\n==========================================");
        console2.log("SETUP COMPLETE!");
        console2.log("==========================================");

        vm.stopBroadcast();
    }
}