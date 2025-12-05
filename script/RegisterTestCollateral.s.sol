// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract RegisterTestCollateral is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Contract addresses
        address lendingModule = 0x6997d539bC80f514e7B015545E22f3Db5672a5f8;
        address authorizedHook = 0xD1c62D4208b10AcAaC2879323f486D1fa5756840; // Using VolatilityOracle as mock hook
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base Sepolia

        vm.startBroadcast(deployerPrivateKey);

        address user = vm.addr(deployerPrivateKey);
        console2.log("Registering collateral for:", user);

        // First, we need to set the authorized hook (only owner can do this)
        // For testing, we'll use the deployer as the "hook"

        // Simulate LP position value of $1000
        uint256 lpAmount = 100 * 10**18; // 100 LP tokens
        uint256 collateralValue = 1000 * 10**18; // $1000 value

        console2.log("Simulating LP position:");
        console2.log("- LP Tokens:", lpAmount / 10**18);
        console2.log("- Collateral Value: $", collateralValue / 10**18);

        // The LendingModule expects the BastionHook to register collateral
        // Since we're the owner, we can temporarily set ourselves as the hook
        // Then register the collateral

        // Note: In production, this would be done automatically when you add liquidity
        console2.log("\n[INFO] In production, this happens automatically when you add liquidity to Uniswap V4 pools");
        console2.log("[INFO] The BastionHook registers your LP position as collateral");

        // Check current position
        (uint256 currentLpAmount,,,,,, bool isActive) = LendingModule(lendingModule).positions(user);

        if (isActive) {
            console2.log("\n[INFO] You already have an active position with", currentLpAmount / 10**18, "LP tokens");
        } else {
            console2.log("\n[ERROR] Cannot register collateral directly - must be done through BastionHook");
            console2.log("[INFO] To test borrowing, you would need to:");
            console2.log("  1. Add liquidity through Uniswap V4 (when integrated)");
            console2.log("  2. The BastionHook automatically registers your LP tokens");
            console2.log("  3. Then you can borrow up to 70% of your collateral value");
        }

        // Fund the lending pool if needed (for testing)
        uint256 poolBalance = LendingModule(lendingModule).totalLendingPool();
        if (poolBalance < 10000 * 10**18) {
            console2.log("\n[INFO] Lending pool has low liquidity:", poolBalance / 10**18, "USDC");
            console2.log("[INFO] Pool owners can fund it using the fundPool function");
        }

        vm.stopBroadcast();
    }
}