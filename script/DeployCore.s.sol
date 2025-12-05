// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {BastionHook} from "../src/BastionHook.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {VolatilityOracle} from "../src/VolatilityOracle.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IVolatilityOracle} from "../src/interfaces/IVolatilityOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployCore
 * @notice Simplified deployment script for core Bastion contracts
 */
contract DeployCore is Script {
    // Deployed addresses
    address public bastionHook;
    address public insuranceTranche;
    address public lendingModule;
    address public bastionVault;
    address public volatilityOracle;

    // Mock tokens
    address public stETH;
    address public cbETH;
    address public rETH;
    address public USDe;
    address public USDC;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== Bastion Core Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Network:", block.chainid);
        console2.log("Balance:", deployer.balance / 1e18, "ETH");
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy VolatilityOracle
        console2.log("Deploying VolatilityOracle...");
        VolatilityOracle oracle = new VolatilityOracle();
        volatilityOracle = address(oracle);
        console2.log("  VolatilityOracle:", volatilityOracle);

        // Deploy mock tokens
        console2.log("\nDeploying Mock Tokens...");
        stETH = address(new MockERC20("Liquid staked Ether 2.0", "stETH", 18));
        console2.log("  stETH:", stETH);

        cbETH = address(new MockERC20("Coinbase Wrapped Staked ETH", "cbETH", 18));
        console2.log("  cbETH:", cbETH);

        rETH = address(new MockERC20("Rocket Pool ETH", "rETH", 18));
        console2.log("  rETH:", rETH);

        USDe = address(new MockERC20("Ethena USDe", "USDe", 18));
        console2.log("  USDe:", USDe);

        USDC = address(new MockERC20("USD Coin", "USDC", 6));
        console2.log("  USDC:", USDC);

        // Mint tokens to deployer
        MockERC20(stETH).mint(deployer, 1000000 * 1e18);
        MockERC20(cbETH).mint(deployer, 1000000 * 1e18);
        MockERC20(rETH).mint(deployer, 1000000 * 1e18);
        MockERC20(USDe).mint(deployer, 1000000 * 1e18);
        MockERC20(USDC).mint(deployer, 1000000 * 1e6);
        console2.log("  Minted 1M tokens to deployer");

        // Deploy BastionHook (without hook mining for now)
        console2.log("\nDeploying BastionHook...");
        // Note: This won't have correct hook address, but works for testing
        bastionHook = address(0x1234567890123456789012345678901234567890); // Placeholder
        console2.log("  BastionHook: (Placeholder -requires hook mining)");
        console2.log("  Use HookMiner to deploy with correct address");

        // Deploy InsuranceTranche
        console2.log("\nDeploying InsuranceTranche...");
        InsuranceTranche insurance = new InsuranceTranche(bastionHook);
        insuranceTranche = address(insurance);
        console2.log("  InsuranceTranche:", insuranceTranche);

        // Deploy LendingModule
        console2.log("\nDeploying LendingModule...");
        LendingModule lending = new LendingModule();
        lendingModule = address(lending);
        console2.log("  LendingModule:", lendingModule);

        // Deploy BastionVault
        console2.log("\nDeploying BastionVault...");
        // BastionVault expects a single IERC20 base asset (stETH) as per ERC-4626
        BastionVault vault = new BastionVault(
            IERC20(stETH),
            "Bastion Vault",
            "bstVault"
        );
        bastionVault = address(vault);
        console2.log("  BastionVault:", bastionVault);

        vm.stopBroadcast();

        // Save addresses
        console2.log("\n=== Deployment Complete ===\n");
        saveDeploymentAddresses();

        console2.log("Next steps:");
        console2.log("1. Update frontend: frontend/lib/contracts/addresses.ts");
        console2.log("2. Deploy BastionHook with correct address using HookMiner");
        console2.log("3. Update InsuranceTranche with real BastionHook address");
    }

    function saveDeploymentAddresses() internal {
        string memory json = "deployment";

        vm.serializeAddress(json, "volatilityOracle", volatilityOracle);
        vm.serializeAddress(json, "insuranceTranche", insuranceTranche);
        vm.serializeAddress(json, "lendingModule", lendingModule);
        vm.serializeAddress(json, "bastionVault", bastionVault);
        vm.serializeAddress(json, "stETH", stETH);
        vm.serializeAddress(json, "cbETH", cbETH);
        vm.serializeAddress(json, "rETH", rETH);
        vm.serializeAddress(json, "USDe", USDe);
        vm.serializeAddress(json, "USDC", USDC);

        string memory finalJson = vm.serializeUint(json, "chainId", block.chainid);

        string memory outputPath = string.concat("deployments/", vm.toString(block.chainid), ".json");

        vm.writeJson(finalJson, outputPath);
        console2.log("\nDeployment addresses saved to:", outputPath);
    }
}
