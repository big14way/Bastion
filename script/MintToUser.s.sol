// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract MintToUser is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Token address from deployment
        address stETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;

        // Get recipient address from command line argument or use default
        address recipient = vm.envOr("RECIPIENT", address(0));

        // If no recipient specified, ask user to provide it
        if (recipient == address(0)) {
            console2.log("Please specify the recipient wallet address:");
            console2.log("Example: RECIPIENT=0xYourWalletAddress forge script script/MintToUser.s.sol:MintToUser --rpc-url https://sepolia.base.org --broadcast");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Mint 100 stETH tokens to recipient
        MockERC20(stETH).mint(recipient, 100 * 10**18);

        console2.log("Minted 100 stETH to:", recipient);

        // Check balance
        uint256 balance = MockERC20(stETH).balanceOf(recipient);
        console2.log("New balance:", balance / 10**18, "stETH");

        vm.stopBroadcast();
    }
}