// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BastionServiceManager} from "../src/avs/BastionServiceManager.sol";
import {BastionTaskManager} from "../src/avs/BastionTaskManager.sol";
import {MockChainlinkPriceFeed} from "../src/mocks/MockChainlinkPriceFeed.sol";

contract DeployAVSSimple is Script {
    address constant MOCK_AVS_DIRECTORY = 0x1111111111111111111111111111111111111111;

    function run() external {
        vm.startBroadcast();

        // Deploy Price Feeds
        MockChainlinkPriceFeed ethUsdFeed = new MockChainlinkPriceFeed(2000_00000000, 8);
        MockChainlinkPriceFeed stEthUsdFeed = new MockChainlinkPriceFeed(2000_00000000, 8);

        // Deploy ServiceManager (skip proxy for simplicity)
        BastionServiceManager serviceManager = new BastionServiceManager();

        // Deploy TaskManager (skip proxy for simplicity)
        BastionTaskManager taskManager = new BastionTaskManager();

        // Initialize (after deployment, initializers are disabled in constructor)
        // We can't actually initialize these because _disableInitializers() is called
        // So we'll deploy without initialization for testing

        vm.stopBroadcast();

        // Log addresses
        console.log("ServiceManager:", address(serviceManager));
        console.log("TaskManager:", address(taskManager));
        console.log("ETH/USD Feed:", address(ethUsdFeed));
        console.log("stETH/USD Feed:", address(stEthUsdFeed));
    }
}
