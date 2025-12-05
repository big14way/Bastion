// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BastionServiceManager} from "../src/avs/BastionServiceManager.sol";
import {BastionTaskManager} from "../src/avs/BastionTaskManager.sol";
import {MockChainlinkPriceFeed} from "../src/mocks/MockChainlinkPriceFeed.sol";

/// @title DeployAVSWithProxy
/// @notice Deploys Bastion AVS contracts with proper upgradeable proxy pattern to Base Sepolia
contract DeployAVSWithProxy is Script {
    // Mock AVS Directory for Base Sepolia (no real EigenLayer deployment there)
    address constant MOCK_AVS_DIRECTORY = address(0x1111111111111111111111111111111111111111);

    function run() external {
        address deployer = msg.sender;

        console.log("=== Bastion AVS Deployment with Proxy Pattern ===");
        console.log("Deployer:", deployer);

        vm.startBroadcast();

        // -----------------------------------------------
        // 1. Deploy Mock Chainlink Price Feeds
        // -----------------------------------------------
        console.log("\n1. Deploying Mock Chainlink Price Feeds...");

        // ETH/USD at $2000, 8 decimals
        MockChainlinkPriceFeed ethUsdFeed = new MockChainlinkPriceFeed(2000_00000000, 8);
        console.log("ETH/USD Feed:", address(ethUsdFeed));

        // stETH/USD at $2000 (same as ETH, no depeg)
        MockChainlinkPriceFeed stEthUsdFeed = new MockChainlinkPriceFeed(2000_00000000, 8);
        console.log("stETH/USD Feed:", address(stEthUsdFeed));

        // -----------------------------------------------
        // 2. Deploy BastionServiceManager Implementation + Proxy
        // -----------------------------------------------
        console.log("\n2. Deploying BastionServiceManager...");

        // Deploy implementation
        BastionServiceManager serviceManagerImpl = new BastionServiceManager();
        console.log("ServiceManager Implementation:", address(serviceManagerImpl));

        // Prepare initialization data
        bytes memory serviceManagerInitData = abi.encodeWithSelector(
            BastionServiceManager.initialize.selector,
            MOCK_AVS_DIRECTORY, // avsDirectory
            1 ether, // minimumStake (1 ETH for testnet)
            deployer // owner
        );

        // Deploy proxy
        ERC1967Proxy serviceManagerProxy =
            new ERC1967Proxy(address(serviceManagerImpl), serviceManagerInitData);

        BastionServiceManager serviceManager = BastionServiceManager(address(serviceManagerProxy));
        console.log("ServiceManager Proxy:", address(serviceManager));

        // -----------------------------------------------
        // 3. Deploy BastionTaskManager Implementation + Proxy
        // -----------------------------------------------
        console.log("\n3. Deploying BastionTaskManager...");

        // Deploy implementation
        BastionTaskManager taskManagerImpl = new BastionTaskManager();
        console.log("TaskManager Implementation:", address(taskManagerImpl));

        // Prepare initialization data
        bytes memory taskManagerInitData = abi.encodeWithSelector(
            BastionTaskManager.initialize.selector,
            address(serviceManager), // serviceManager
            100, // taskTimeoutBlocks (100 blocks ~= 3 minutes on Base)
            5000, // minimumQuorumPercentage (50%)
            deployer // owner
        );

        // Deploy proxy
        ERC1967Proxy taskManagerProxy = new ERC1967Proxy(address(taskManagerImpl), taskManagerInitData);

        BastionTaskManager taskManager = BastionTaskManager(address(taskManagerProxy));
        console.log("TaskManager Proxy:", address(taskManager));

        // -----------------------------------------------
        // 4. Link Contracts
        // -----------------------------------------------
        console.log("\n4. Linking contracts...");

        serviceManager.setTaskManager(address(taskManager));
        console.log("ServiceManager.taskManager set to:", address(taskManager));

        // -----------------------------------------------
        // 5. Verify Deployment
        // -----------------------------------------------
        console.log("\n5. Verifying deployment...");

        require(serviceManager.taskManager() == address(taskManager), "TaskManager not linked");
        require(serviceManager.avsDirectory() == MOCK_AVS_DIRECTORY, "AVS Directory mismatch");
        require(serviceManager.minimumStake() == 1 ether, "Minimum stake mismatch");
        require(address(taskManager.serviceManager()) == address(serviceManager), "ServiceManager not linked");

        console.log("All verifications passed!");

        vm.stopBroadcast();

        // -----------------------------------------------
        // 6. Summary
        // -----------------------------------------------
        console.log("\n=== Deployment Complete ===");
        console.log("\nAVS Contracts:");
        console.log("  ServiceManager:", address(serviceManager));
        console.log("  TaskManager:", address(taskManager));
        console.log("\nMock Price Feeds:");
        console.log("  ETH/USD:", address(ethUsdFeed));
        console.log("  stETH/USD:", address(stEthUsdFeed));
        console.log("\nConfiguration:");
        console.log("  AVS Directory:", MOCK_AVS_DIRECTORY);
        console.log("  Owner:", deployer);
        console.log("  Minimum Stake: 1 ETH");

        console.log("\n=== Next Steps ===");
        console.log("1. Update operator/.env with:");
        console.log("   SERVICE_MANAGER_ADDRESS=", address(serviceManager));
        console.log("   TASK_MANAGER_ADDRESS=", address(taskManager));
        console.log("   CHAINLINK_ETH_USD=", address(ethUsdFeed));
        console.log("   CHAINLINK_STETH_USD=", address(stEthUsdFeed));
        console.log("\n2. Update frontend/lib/contracts/addresses.ts");
        console.log("\n3. Run operator registration");
    }
}
