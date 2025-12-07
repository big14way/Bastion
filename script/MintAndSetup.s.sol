// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MintAndSetup
 * @notice Simple script to mint test tokens to your wallet
 */
contract MintAndSetup is Script {
    // Mock token addresses (already deployed)
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("\n=== Minting Test Tokens ===");
        console2.log("Recipient:", deployer);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Mint 100,000 of each token
        uint256 amountSTETH = 100_000 * 1e18;
        uint256 amountUSDC = 100_000 * 1e6;

        MockERC20(STETH).mint(deployer, amountSTETH);
        console2.log("Minted 100,000 stETH to", deployer);

        MockERC20(USDC).mint(deployer, amountUSDC);
        console2.log("Minted 100,000 USDC to", deployer);

        vm.stopBroadcast();

        console2.log("\n=== Mint Complete! ===");
        console2.log("stETH balance:", IERC20(STETH).balanceOf(deployer) / 1e18, "tokens");
        console2.log("USDC balance:", IERC20(USDC).balanceOf(deployer) / 1e6, "tokens");
        console2.log("\nYou can now test the protocol at http://localhost:3002");
    }
}
