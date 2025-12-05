// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {LendingModule} from "../src/LendingModule.sol";

contract RegisterCollateralForUser is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // IMPORTANT: Change this to YOUR wallet address that you're using in the browser
        address userToRegister = 0x208B2660e5F62CDca21869b389c5aF9E7f0faE89; // <-- UPDATE THIS WITH YOUR BROWSER WALLET ADDRESS

        // Contract addresses
        address lendingModule = 0x6825B4E72947fE813c840af63105434283c7db2B;
        address lpToken = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;

        vm.startBroadcast(deployerPrivateKey);

        console2.log("==========================================");
        console2.log("REGISTERING COLLATERAL FOR USER");
        console2.log("==========================================");
        console2.log("Deployer (owner):", deployer);
        console2.log("User to register:", userToRegister);
        console2.log("LendingModule:", lendingModule);

        LendingModule lm = LendingModule(lendingModule);

        // Check if user already has a position
        (
            uint256 existingLpAmount,
            uint256 existingCollateralValue,
            uint256 existingBorrowedAmount,
            ,
            ,
            ,
            bool isActive
        ) = lm.positions(userToRegister);

        if (isActive) {
            console2.log("\n[INFO] User already has an active position:");
            console2.log("LP Tokens:", existingLpAmount / 10**18);
            console2.log("Collateral Value: $", existingCollateralValue / 10**18);
            console2.log("Borrowed Amount: $", existingBorrowedAmount / 10**18);

            uint256 maxBorrow = lm.getMaxBorrow(userToRegister);
            console2.log("Available to borrow: $", maxBorrow / 10**18);
        } else {
            console2.log("\n[INFO] No existing position found for user");

            // Register collateral
            uint256 lpAmount = 1000 * 10**18; // 1000 LP tokens
            uint256 collateralValue = 10000 * 10**18; // $10,000 USD

            console2.log("\n=== REGISTERING COLLATERAL ===");
            console2.log("LP Amount:", lpAmount / 10**18, "tokens");
            console2.log("Collateral Value: $", collateralValue / 10**18);

            // Since deployer is the authorized hook, we can register for any user
            lm.registerCollateral(userToRegister, lpToken, lpAmount, collateralValue);
            console2.log("[SUCCESS] Collateral registered!");

            // Check new borrowing capacity
            uint256 maxBorrow = lm.getMaxBorrow(userToRegister);
            console2.log("\n=== BORROWING CAPACITY ===");
            console2.log("User can now borrow up to: $", maxBorrow / 10**18, "USDC");
        }

        // Check pool liquidity
        uint256 totalPool = lm.totalLendingPool();
        uint256 totalBorrowed = lm.totalBorrowed();
        uint256 available = totalPool - totalBorrowed;

        console2.log("\n=== LENDING POOL STATUS ===");
        console2.log("Total Pool: $", totalPool / 10**18);
        console2.log("Total Borrowed: $", totalBorrowed / 10**18);
        console2.log("Available Liquidity: $", available / 10**18);

        console2.log("\n==========================================");
        console2.log("DONE! User can now borrow from the frontend");
        console2.log("==========================================");

        vm.stopBroadcast();
    }
}