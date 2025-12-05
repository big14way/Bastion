// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract MintTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Token address from deployment
        address stETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;

        // Get recipient address from environment or use a default
        address recipient = vm.envOr("RECIPIENT", msg.sender);

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