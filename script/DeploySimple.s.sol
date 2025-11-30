// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {VolatilityOracle} from "../src/VolatilityOracle.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title DeploySimple
 * @notice Simple deployment script for Bastion Protocol core contracts
 * @dev Deploys without hook integration for testing
 */
contract DeploySimple is Script {
    function run() external {
        vm.startBroadcast();

        console2.log("\n=== Deploying Bastion Protocol (Simple) ===");
        console2.log("Deployer:", msg.sender);
        console2.log("Network:", block.chainid);

        // 1. Deploy mock tokens
        console2.log("\nDeploying mock tokens...");
        MockERC20 stETH = new MockERC20("Lido Staked ETH", "stETH", 18);
        MockERC20 cbETH = new MockERC20("Coinbase Wrapped Staked ETH", "cbETH", 18);
        MockERC20 rETH = new MockERC20("Rocket Pool ETH", "rETH", 18);
        MockERC20 USDe = new MockERC20("Ethena USDe", "USDe", 18);
        console2.log("  stETH:", address(stETH));
        console2.log("  cbETH:", address(cbETH));
        console2.log("  rETH:", address(rETH));
        console2.log("  USDe:", address(USDe));

        // 2. Deploy VolatilityOracle
        console2.log("\nDeploying VolatilityOracle...");
        VolatilityOracle oracle = new VolatilityOracle();
        console2.log("  VolatilityOracle:", address(oracle));

        // 3. Deploy InsuranceTranche
        console2.log("\nDeploying InsuranceTranche...");
        InsuranceTranche insurance = new InsuranceTranche(msg.sender); // Use deployer as authorized hook
        console2.log("  InsuranceTranche:", address(insurance));

        // 4. Deploy LendingModule
        console2.log("\nDeploying LendingModule...");
        LendingModule lending = new LendingModule(msg.sender, address(USDe), 500); // 5% interest
        console2.log("  LendingModule:", address(lending));

        // 5. Deploy BastionVault
        console2.log("\nDeploying BastionVault...");
        BastionVault vault = new BastionVault(stETH, "Bastion stETH Vault", "bstETH");
        console2.log("  BastionVault:", address(vault));

        vm.stopBroadcast();

        // 6. Save deployment addresses
        saveDeployment(
            address(oracle),
            address(insurance),
            address(lending),
            address(vault),
            address(stETH),
            address(cbETH),
            address(rETH),
            address(USDe)
        );

        console2.log("\n=== Deployment Complete ===");
        console2.log("\nNext steps:");
        console2.log("1. Update frontend/lib/contracts/addresses.ts with these addresses");
        console2.log("2. Deploy AVS contracts with script/DeployAVS.s.sol");
        console2.log("3. Get testnet ETH from Base Sepolia faucet");
    }

    function saveDeployment(
        address volatilityOracle,
        address insuranceTranche,
        address lendingModule,
        address bastionVault,
        address stETH,
        address cbETH,
        address rETH,
        address USDe
    ) internal {
        string memory json = "deployment";

        vm.serializeAddress(json, "volatilityOracle", volatilityOracle);
        vm.serializeAddress(json, "insuranceTranche", insuranceTranche);
        vm.serializeAddress(json, "lendingModule", lendingModule);
        vm.serializeAddress(json, "bastionVault", bastionVault);
        vm.serializeAddress(json, "stETH", stETH);
        vm.serializeAddress(json, "cbETH", cbETH);
        vm.serializeAddress(json, "rETH", rETH);
        string memory finalJson = vm.serializeAddress(json, "USDe", USDe);

        string memory deploymentPath = string.concat(
            "deployments/", vm.toString(block.chainid), ".json"
        );

        vm.writeJson(finalJson, deploymentPath);
        console2.log("\nDeployment addresses saved to:", deploymentPath);
    }
}
