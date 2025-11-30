// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {BastionServiceManager} from "../src/avs/BastionServiceManager.sol";
import {BastionTaskManager} from "../src/avs/BastionTaskManager.sol";

/**
 * @title DeployAVS
 * @notice Deployment script for Bastion AVS contracts
 * @dev Deploys ServiceManager and TaskManager for EigenLayer integration
 */
contract DeployAVS is Script {
    // Deployment addresses
    address public serviceManager;
    address public taskManager;

    // Required addresses (from previous deployment or environment)
    address public insuranceTranche;
    address public avsDirectory;
    address public registryCoordinator;
    address public stakeRegistry;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying Bastion AVS...");
        console2.log("Deployer:", deployer);
        console2.log("Network:", block.chainid);

        // Load deployment addresses
        loadDeploymentAddresses();

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy BastionServiceManager first
        serviceManager = deployServiceManager();
        console2.log("BastionServiceManager:", serviceManager);

        // Step 2: Deploy BastionTaskManager with ServiceManager reference
        BastionTaskManager tm = new BastionTaskManager();
        taskManager = address(tm);

        // Initialize TaskManager with ServiceManager
        tm.initialize(
            serviceManager,
            7200,  // taskTimeoutBlocks: ~1 day on Base (~12s blocks)
            6700,  // minimumQuorumPercentage: 67%
            msg.sender  // owner
        );
        console2.log("BastionTaskManager:", taskManager);

        // Step 3: Link contracts
        linkContracts();

        vm.stopBroadcast();

        // Step 4: Save AVS deployment addresses
        saveAVSDeployment();

        console2.log("\n=== AVS Deployment Complete ===");
        console2.log("ServiceManager:", serviceManager);
        console2.log("TaskManager:", taskManager);
        console2.log("\nNext steps:");
        console2.log("1. Register operators with EigenLayer");
        console2.log("2. Update InsuranceTranche with TaskManager address");
        console2.log("3. Start off-chain operator service");
    }

    function loadDeploymentAddresses() internal {
        // Load from deployment file
        string memory deploymentPath = string.concat(
            "deployments/",
            vm.toString(block.chainid),
            ".json"
        );

        if (vm.exists(deploymentPath)) {
            string memory json = vm.readFile(deploymentPath);
            insuranceTranche = vm.parseJsonAddress(json, ".insuranceTranche");
            console2.log("Loaded InsuranceTranche:", insuranceTranche);
        } else {
            // Fallback to environment variables
            insuranceTranche = vm.envAddress("INSURANCE_TRANCHE");
        }

        // Load EigenLayer addresses (testnet or mainnet)
        if (block.chainid == 84532) {
            // Base Sepolia - use mock addresses or deploy mocks
            console2.log("Base Sepolia detected - using mock AVS infrastructure");
            avsDirectory = deployMockAVSDirectory();
            registryCoordinator = deployMockRegistryCoordinator();
            stakeRegistry = deployMockStakeRegistry();
        } else {
            // Load from environment
            avsDirectory = vm.envAddress("AVS_DIRECTORY");
            registryCoordinator = vm.envAddress("REGISTRY_COORDINATOR");
            stakeRegistry = vm.envAddress("STAKE_REGISTRY");
        }
    }

    function deployServiceManager() internal returns (address) {
        // Deploy upgradeable contract
        BastionServiceManager sm = new BastionServiceManager();

        // Initialize with minimal stake of 1 ETH
        sm.initialize(avsDirectory, 1 ether, msg.sender);

        return address(sm);
    }

    function deployMockAVSDirectory() internal returns (address) {
        // Deploy minimal mock for testing
        console2.log("Deploying mock AVS Directory");
        // In production, use actual EigenLayer contracts
        return address(new MockAVSDirectory());
    }

    function deployMockRegistryCoordinator() internal returns (address) {
        console2.log("Deploying mock Registry Coordinator");
        return address(new MockRegistryCoordinator());
    }

    function deployMockStakeRegistry() internal returns (address) {
        console2.log("Deploying mock Stake Registry");
        return address(new MockStakeRegistry());
    }

    function linkContracts() internal {
        console2.log("\nLinking contracts...");

        // Set TaskManager in ServiceManager
        BastionServiceManager(serviceManager).setTaskManager(taskManager);
        console2.log("TaskManager set in ServiceManager");

        // ServiceManager is already set in TaskManager during initialization
        console2.log("ServiceManager already set in TaskManager via initialize()");

        // Note: InsuranceTranche integration happens at the protocol layer,
        // not in the AVS contracts directly
    }

    function saveAVSDeployment() internal {
        string memory json = "avs";

        vm.serializeAddress(json, "serviceManager", serviceManager);
        vm.serializeAddress(json, "taskManager", taskManager);
        vm.serializeAddress(json, "avsDirectory", avsDirectory);
        vm.serializeAddress(json, "registryCoordinator", registryCoordinator);
        vm.serializeAddress(json, "stakeRegistry", stakeRegistry);

        string memory finalJson = vm.serializeUint(json, "chainId", block.chainid);

        string memory outputPath = string.concat(
            "deployments/avs-",
            vm.toString(block.chainid),
            ".json"
        );

        vm.writeJson(finalJson, outputPath);
        console2.log("\nAVS deployment saved to:", outputPath);
    }
}

// Mock contracts for testing (minimal implementations)
contract MockAVSDirectory {
    function registerOperatorToAVS(address, bytes memory) external {}
    function deregisterOperatorFromAVS(address) external {}
}

contract MockRegistryCoordinator {
    function registerOperator(bytes memory, string memory, address) external {}
}

contract MockStakeRegistry {
    function getOperatorStake(address) external pure returns (uint256) {
        return 100000 ether; // Mock stake
    }
}
