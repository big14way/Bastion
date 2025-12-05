// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {TestCollateralHook} from "../src/TestCollateralHook.sol";
import {LendingModule} from "../src/LendingModule.sol";

contract DeployTestCollateralHook is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Updated LendingModule address with funded pool
        address lendingModule = 0x6825B4E72947fE813c840af63105434283c7db2B;

        // Mock LP token address (using stETH as placeholder)
        address lpToken = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;

        vm.startBroadcast(deployerPrivateKey);

        console2.log("==========================================");
        console2.log("DEPLOYING TEST COLLATERAL HOOK");
        console2.log("==========================================");
        console2.log("Deployer:", deployer);
        console2.log("LendingModule:", lendingModule);
        console2.log("LP Token:", lpToken);

        // Deploy TestCollateralHook
        TestCollateralHook testHook = new TestCollateralHook(
            lendingModule,
            lpToken
        );

        console2.log("\n=== DEPLOYED CONTRACT ===");
        console2.log("TestCollateralHook:", address(testHook));

        // Now we need to authorize this hook in the LendingModule
        // Only the owner can do this
        LendingModule lm = LendingModule(lendingModule);

        console2.log("\n=== UPDATING LENDING MODULE ===");
        console2.log("Setting TestCollateralHook as authorized hook...");

        try lm.updateAuthorizedHook(address(testHook)) {
            console2.log("[SUCCESS] Hook authorized!");
        } catch {
            console2.log("[INFO] Could not update hook - only owner can do this");
            console2.log("Owner should call:");
            console2.log("  lendingModule.updateAuthorizedHook(", address(testHook), ")");
        }

        console2.log("\n==========================================");
        console2.log("DEPLOYMENT COMPLETE!");
        console2.log("==========================================");

        console2.log("\nAdd this to frontend/lib/contracts/addresses.ts:");
        console2.log("TestCollateralHook:", address(testHook));

        console2.log("\n=== NEXT STEPS ===");
        console2.log("1. Register test collateral for users:");
        console2.log("   testHook.registerTestCollateral(userAddress, lpAmount, collateralValue)");
        console2.log("2. Users can then borrow up to 70% of collateral value");
        console2.log("3. Check borrowing capacity with:");
        console2.log("   lendingModule.getMaxBorrow(userAddress)");

        vm.stopBroadcast();
    }
}