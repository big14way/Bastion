// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/InsuranceTranche.sol";
import "../src/mocks/MockERC20.sol";

/**
 * @title RedeployInsurance Script
 * @notice Redeploys InsuranceTranche with test functions and sets up configuration
 */
contract RedeployInsurance is Script {
    // Known addresses
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;
    address constant TASK_MANAGER = 0x6997d539bC80f514e7B015545E22f3Db5672a5f8;
    address constant CHAINLINK_STETH = 0x73fd79706e56809ead9b5C8C1B825d41E829cC34;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Redeploying InsuranceTranche with Test Functions ===");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new InsuranceTranche
        console.log("\n=== Step 1: Deploy InsuranceTranche ===");
        // Use deployer as authorized hook for now (can be changed later)
        InsuranceTranche insurance = new InsuranceTranche(deployer);
        console.log("InsuranceTranche deployed at:", address(insurance));

        // 2. Configure TaskManager
        console.log("\n=== Step 2: Configure TaskManager ===");
        insurance.setBastionTaskManager(TASK_MANAGER);
        console.log("TaskManager set to:", TASK_MANAGER);

        // 3. Set USDC as payout token
        console.log("\n=== Step 3: Set Payout Token ===");
        insurance.setPayoutToken(USDC);
        console.log("Payout token set to USDC:", USDC);

        // 4. Configure stETH for monitoring
        console.log("\n=== Step 4: Configure Asset Monitoring ===");
        insurance.configureAsset(
            STETH,
            CHAINLINK_STETH,
            2000,  // 20% depeg threshold (basis points)
            3600   // 1 hour max price age
        );
        console.log("Configured stETH monitoring (20% threshold)");

        // 5. Register deployer's LP position
        console.log("\n=== Step 5: Register LP Position ===");
        uint256 lpShares = 1000 * 1e18; // 1,000 shares
        insurance.updateLPPosition(deployer, lpShares);
        console.log("Registered LP position:", lpShares / 1e18, "shares");

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("\nNew Contract Address:");
        console.log("  InsuranceTranche:", address(insurance));
        console.log("\nConfiguration:");
        console.log("  Payout Token: USDC");
        console.log("  Monitored Asset: stETH");
        console.log("  Depeg Threshold: 20%");
        console.log("  Your LP Shares:", lpShares / 1e18);
        console.log("\nUpdate frontend/lib/contracts/addresses.ts with:");
        console.log("  InsuranceTranche:", address(insurance));
        console.log("\nNext Steps:");
        console.log("1. Update the contract address in addresses.ts");
        console.log("2. Run: forge script script/TestInsurancePayout.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast");
        console.log("3. Visit http://localhost:3002/insurance to claim");
    }
}
