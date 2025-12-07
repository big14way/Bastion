// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/InsuranceTranche.sol";
import "../src/mocks/MockERC20.sol";

/**
 * @title ExecuteDepegPayout Script
 * @notice Script to execute a depeg payout event for testing insurance claims
 * @dev This calls executePayout which relies on AVS consensus and Chainlink oracle
 *
 * IMPORTANT: This requires:
 * 1. BastionTaskManager to be set on InsuranceTranche
 * 2. AVS consensus to be established (or mock data)
 * 3. Chainlink oracle to show depeg
 * 4. Insurance pool to have USDC balance
 */
contract ExecuteDepegPayout is Script {
    // Deployed contract addresses on Base Sepolia
    address constant INSURANCE_TRANCHE = 0x54c7529b5bc98d0107570a808fb1cda397050cf1;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;
    address constant TASK_MANAGER = 0x6997d539bC80f514e7B015545E22f3Db5672a5f8;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Executing Depeg Payout Event ===");
        console.log("Deployer:", deployer);
        console.log("InsuranceTranche:", INSURANCE_TRANCHE);
        console.log("USDC (payout token):", USDC);
        console.log("stETH (depegged asset):", STETH);
        console.log("TaskManager:", TASK_MANAGER);

        vm.startBroadcast(deployerPrivateKey);

        InsuranceTranche insurance = InsuranceTranche(INSURANCE_TRANCHE);
        MockERC20 usdc = MockERC20(USDC);

        // 1. Check and set TaskManager if needed
        console.log("\n=== Step 1: Configure TaskManager ===");
        console.log("Setting TaskManager to:", TASK_MANAGER);
        try insurance.setBastionTaskManager(TASK_MANAGER) {
            console.log("TaskManager set successfully");
        } catch {
            console.log("TaskManager might already be set or not owner");
        }

        // 2. Ensure insurance pool has USDC balance
        uint256 poolBalance = insurance.insurancePoolBalance();
        console.log("\n=== Step 2: Check Insurance Pool ===");
        console.log("Insurance pool balance:", poolBalance / 1e18, "ETH equivalent");

        // Fund the insurance pool if needed
        if (poolBalance == 0) {
            console.log("WARNING: Insurance pool is empty!");
            console.log("You need to fund the pool first. Run:");
            console.log("  cast send", INSURANCE_TRANCHE);
            console.log("    'fundInsurancePool()' --value 1ether");
            console.log("    --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY");
            revert("Insurance pool is empty");
        }

        // 3. Ensure deployer has USDC for payout token transfer
        uint256 payoutNeeded = poolBalance; // Insurance pays out the pool balance
        uint256 deployerUSDC = usdc.balanceOf(deployer);

        console.log("\n=== Step 3: Ensure Payout Token (USDC) ===");
        console.log("Payout needed:", payoutNeeded / 1e18, "USDC (approximate)");
        console.log("Current USDC balance:", deployerUSDC / 1e6);

        // Mint enough USDC if needed (converting from 18 decimals to 6 decimals)
        uint256 usdcNeeded = (payoutNeeded / 1e18) * 1e6; // Convert to USDC decimals
        if (deployerUSDC < usdcNeeded) {
            console.log("Minting additional USDC...");
            usdc.mint(deployer, usdcNeeded - deployerUSDC + 100_000 * 1e6);
            console.log("Minted USDC successfully");
        }

        // 4. Approve InsuranceTranche to spend USDC
        console.log("\n=== Step 4: Approve USDC Spending ===");
        usdc.approve(INSURANCE_TRANCHE, type(uint256).max);
        console.log("Approved unlimited USDC spending");

        // 5. Execute the payout
        console.log("\n=== Step 5: Execute Depeg Payout ===");
        console.log("Attempting to execute payout for stETH...");
        console.log("\nNOTE: This will fail if:");
        console.log("  - AVS consensus not reached");
        console.log("  - Chainlink oracle doesn't show depeg (>20% deviation)");
        console.log("  - No LP shares registered");

        try insurance.executePayout(STETH) {
            console.log("\n=== SUCCESS ===");
            console.log("Depeg payout event created!");

            vm.stopBroadcast();

            // Read back payout history count to verify
            uint256 payoutCount = insurance.getPayoutHistoryCount();
            console.log("\nTotal payout events:", payoutCount);

            // Check deployer's LP position
            (uint256 shares, , bool isActive) = insurance.getLPPosition(deployer);
            console.log("\nYour LP Position:");
            console.log("  Shares:", shares / 1e18);
            console.log("  Active:", isActive);

            if (shares > 0 && isActive) {
                console.log("\n[SUCCESS] You can claim your share of the payout!");
                console.log("Visit: http://localhost:3002/insurance");
            } else {
                console.log("\n[WARNING] You don't have an active LP position");
                console.log("But other LPs can claim if they have positions");
            }
        } catch Error(string memory reason) {
            console.log("\n=== FAILED ===");
            console.log("Error:", reason);
            console.log("\nThis is expected if AVS consensus is not mocked.");
            console.log("The executePayout function requires:");
            console.log("  1. AVS TaskManager to report depeg");
            console.log("  2. Chainlink oracle to confirm depeg");
            console.log("\nFor testing, you may need to use a simpler approach.");
            vm.stopBroadcast();
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("\n=== FAILED (low level) ===");
            console.logBytes(lowLevelData);
            vm.stopBroadcast();
            revert("Low level error");
        }
    }
}
