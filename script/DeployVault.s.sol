// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployVault is Script {
    function run() external returns (address vault, address token) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock stETH token for testing
        MockERC20 stETH = new MockERC20("Staked Ether", "stETH", 18);
        console2.log("Mock stETH deployed at:", address(stETH));

        // Mint some tokens to the deployer for testing
        stETH.mint(msg.sender, 1000 * 10**18); // 1000 stETH
        console2.log("Minted 1000 stETH to deployer:", msg.sender);

        // Deploy BastionVault with stETH as the base asset
        BastionVault bastionVault = new BastionVault(
            IERC20(address(stETH)),
            "Bastion stETH Vault",
            "bstETH"
        );
        console2.log("BastionVault deployed at:", address(bastionVault));

        // Set reasonable fees (0.1% deposit, 0.1% withdrawal)
        bastionVault.setFees(10, 10); // 10 basis points = 0.1%
        console2.log("Fees set to 0.1% for deposits and withdrawals");

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("Network: Base Sepolia (Chain ID: 84532)");
        console2.log("stETH Token:", address(stETH));
        console2.log("BastionVault:", address(bastionVault));
        console2.log("\nUpdate frontend/lib/contracts/addresses.ts with these addresses!");

        return (address(bastionVault), address(stETH));
    }
}