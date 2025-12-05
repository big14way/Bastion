// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract DeployLendingModule is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Use the BastionHook address as authorized hook (will be deployed later)
        // For now, we'll use the deployer as a temporary authorized hook for testing
        address authorizedHook = deployer; // In production, this should be the BastionHook address

        // USDC address on Base Sepolia (mock for testing)
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        vm.startBroadcast(deployerPrivateKey);

        console2.log("==========================================");
        console2.log("DEPLOYING LENDING MODULE");
        console2.log("==========================================");
        console2.log("Deployer:", deployer);

        // Check if USDC exists, if not deploy mock
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(usdc)
        }

        if (codeSize == 0) {
            console2.log("Deploying Mock USDC...");
            MockERC20 mockUSDC = new MockERC20("USD Coin", "USDC", 18);
            usdc = address(mockUSDC);
            console2.log("Mock USDC deployed at:", usdc);

            // Mint some USDC to the deployer for funding the pool
            mockUSDC.mint(deployer, 100000 * 10**18); // 100,000 USDC
            console2.log("Minted 100,000 USDC to deployer");
        }

        // Deploy LendingModule
        uint256 defaultInterestRate = 500; // 5% APY in basis points
        LendingModule lendingModule = new LendingModule(
            authorizedHook,
            usdc,
            defaultInterestRate
        );

        console2.log("\n=== DEPLOYED CONTRACTS ===");
        console2.log("LendingModule:", address(lendingModule));
        console2.log("USDC:", usdc);
        console2.log("Authorized Hook:", authorizedHook);
        console2.log("Default Interest Rate:", defaultInterestRate / 100, "%");

        // Fund the lending pool with initial liquidity
        console2.log("\n=== FUNDING LENDING POOL ===");
        uint256 fundAmount = 10000 * 10**18; // 10,000 USDC

        // Approve LendingModule to spend USDC
        MockERC20(usdc).approve(address(lendingModule), fundAmount);
        console2.log("Approved", fundAmount / 10**18, "USDC");

        // Fund the pool
        lendingModule.fundPool(fundAmount);
        console2.log("Funded pool with", fundAmount / 10**18, "USDC");

        // Verify pool state
        uint256 totalPool = lendingModule.totalLendingPool();
        console2.log("Total pool liquidity:", totalPool / 10**18, "USDC");

        console2.log("\n==========================================");
        console2.log("DEPLOYMENT COMPLETE!");
        console2.log("==========================================");

        // Save deployment addresses
        console2.log("\nAdd these to frontend/lib/contracts/addresses.ts:");
        console2.log("LendingModule:", address(lendingModule));
        console2.log("USDC:", usdc);

        vm.stopBroadcast();
    }
}