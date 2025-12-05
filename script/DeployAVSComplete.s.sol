// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BastionServiceManager} from "../src/avs/BastionServiceManager.sol";
import {BastionTaskManager} from "../src/avs/BastionTaskManager.sol";
import {MockChainlinkPriceFeed} from "../src/mocks/MockChainlinkPriceFeed.sol";

/// @title DeployAVSComplete
/// @notice Deploys Bastion AVS contracts and mock Chainlink price feeds to Base Sepolia
contract DeployAVSComplete is Script {
    // Placeholder addresses for testnet (we don't need real EigenLayer on Base Sepolia)
    address constant MOCK_AVS_DIRECTORY = address(0x1111111111111111111111111111111111111111);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Bastion AVS Deployment to Base Sepolia ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // -----------------------------------------------
        // 1. Deploy Mock Chainlink Price Feeds
        // -----------------------------------------------
        console.log("\n1. Deploying Mock Chainlink Price Feeds...");

        // ETH/USD at $2000, 8 decimals
        MockChainlinkPriceFeed ethUsdFeed = new MockChainlinkPriceFeed(2000_00000000, 8);
        console.log("ETH/USD Feed:", address(ethUsdFeed));

        // stETH/USD at $2000 (same as ETH initially, no depeg)
        MockChainlinkPriceFeed stEthUsdFeed = new MockChainlinkPriceFeed(2000_00000000, 8);
        console.log("stETH/USD Feed:", address(stEthUsdFeed));

        // -----------------------------------------------
        // 2. Deploy BastionServiceManager
        // -----------------------------------------------
        console.log("\n2. Deploying BastionServiceManager...");

        BastionServiceManager serviceManagerImpl = new BastionServiceManager();
        console.log("ServiceManager Implementation:", address(serviceManagerImpl));

        // Deploy proxy
        BastionServiceManager serviceManager = BastionServiceManager(
            address(
                new TransparentProxy(
                    address(serviceManagerImpl),
                    deployer,
                    abi.encodeWithSelector(
                        BastionServiceManager.initialize.selector,
                        MOCK_AVS_DIRECTORY, // avsDirectory
                        1 ether, // minimumStake
                        deployer // owner
                    )
                )
            )
        );

        console.log("ServiceManager Proxy:", address(serviceManager));
        console.log("Minimum Stake:", serviceManager.minimumStake() / 1e18, "ETH");

        // -----------------------------------------------
        // 3. Deploy BastionTaskManager
        // -----------------------------------------------
        console.log("\n3. Deploying BastionTaskManager...");

        BastionTaskManager taskManagerImpl = new BastionTaskManager();
        console.log("TaskManager Implementation:", address(taskManagerImpl));

        // Deploy proxy
        BastionTaskManager taskManager = BastionTaskManager(
            address(
                new TransparentProxy(
                    address(taskManagerImpl),
                    deployer,
                    abi.encodeWithSelector(
                        BastionTaskManager.initialize.selector,
                        address(serviceManager), // serviceManager
                        100, // taskTimeoutBlocks (100 blocks ~= 3 minutes on Base)
                        5000, // minimumQuorumPercentage (50%)
                        deployer // owner
                    )
                )
            )
        );

        console.log("TaskManager Proxy:", address(taskManager));
        console.log("Task Timeout:", taskManager.taskTimeoutBlocks(), "blocks");
        console.log("Min Quorum:", taskManager.minimumQuorumPercentage() / 100, "%");

        // -----------------------------------------------
        // 4. Link Contracts
        // -----------------------------------------------
        console.log("\n4. Linking contracts...");

        serviceManager.setTaskManager(address(taskManager));
        console.log("ServiceManager.taskManager set to:", serviceManager.taskManager());

        // -----------------------------------------------
        // 5. Summary
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

        console.log("\n=== Next Steps ===");
        console.log("1. Update operator/.env with these addresses:");
        console.log("   SERVICE_MANAGER_ADDRESS=", address(serviceManager));
        console.log("   TASK_MANAGER_ADDRESS=", address(taskManager));
        console.log("   CHAINLINK_ETH_USD=", address(ethUsdFeed));
        console.log("   CHAINLINK_STETH_USD=", address(stEthUsdFeed));
        console.log("\n2. Update frontend/lib/contracts/addresses.ts");
        console.log("\n3. Run operator registration:");
        console.log("   cd operator/scripts && npm run register");

        vm.stopBroadcast();
    }
}

/// @title TransparentProxy
/// @notice Minimal transparent proxy for upgradeable contracts
contract TransparentProxy {
    address public immutable implementation;
    address public immutable admin;

    constructor(address _implementation, address _admin, bytes memory _data) {
        implementation = _implementation;
        admin = _admin;

        if (_data.length > 0) {
            (bool success,) = _implementation.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
