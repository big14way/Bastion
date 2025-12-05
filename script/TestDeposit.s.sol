// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDeposit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Contract addresses
        address stETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;
        address vault = 0xF5c0325F85b1d0606669956895c6876b15bc33b6;

        vm.startBroadcast(deployerPrivateKey);

        address depositor = vm.addr(deployerPrivateKey);
        console2.log("Depositor address:", depositor);

        // Check initial balances
        uint256 tokenBalance = MockERC20(stETH).balanceOf(depositor);
        console2.log("stETH balance:", tokenBalance / 10**18);

        if (tokenBalance == 0) {
            console2.log("No stETH balance! Minting 100 stETH...");
            MockERC20(stETH).mint(depositor, 100 * 10**18);
            tokenBalance = MockERC20(stETH).balanceOf(depositor);
            console2.log("New stETH balance:", tokenBalance / 10**18);
        }

        // Check current allowance
        uint256 currentAllowance = IERC20(stETH).allowance(depositor, vault);
        console2.log("Current allowance:", currentAllowance / 10**18);

        // Deposit amount
        uint256 depositAmount = 10 * 10**18; // 10 stETH

        // Approve if needed
        if (currentAllowance < depositAmount) {
            console2.log("Approving vault to spend", depositAmount / 10**18, "stETH...");
            IERC20(stETH).approve(vault, depositAmount);
            console2.log("Approval complete!");
        }

        // Check vault state before
        uint256 vaultAssetsBefore = BastionVault(vault).totalAssets();
        uint256 sharesBefore = BastionVault(vault).balanceOf(depositor);
        console2.log("\n=== Before Deposit ===");
        console2.log("Vault total assets:", vaultAssetsBefore / 10**18);
        console2.log("User shares:", sharesBefore / 10**18);

        // Make deposit
        console2.log("\n=== Making Deposit ===");
        console2.log("Depositing", depositAmount / 10**18, "stETH...");
        uint256 shares = BastionVault(vault).deposit(depositAmount, depositor);
        console2.log("Received", shares / 10**18, "shares!");

        // Check vault state after
        uint256 vaultAssetsAfter = BastionVault(vault).totalAssets();
        uint256 sharesAfter = BastionVault(vault).balanceOf(depositor);
        uint256 tokenBalanceAfter = MockERC20(stETH).balanceOf(depositor);

        console2.log("\n=== After Deposit ===");
        console2.log("Vault total assets:", vaultAssetsAfter / 10**18);
        console2.log("User shares:", sharesAfter / 10**18);
        console2.log("User stETH balance:", tokenBalanceAfter / 10**18);

        // Verify deposit worked
        require(vaultAssetsAfter > vaultAssetsBefore, "Vault assets should increase");
        require(sharesAfter > sharesBefore, "User shares should increase");

        console2.log("\n[SUCCESS] Deposit successful!");

        vm.stopBroadcast();
    }
}