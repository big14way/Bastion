// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

import {BastionHook} from "../src/BastionHook.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {VolatilityOracle} from "../src/VolatilityOracle.sol";
import {IVolatilityOracle} from "../src/interfaces/IVolatilityOracle.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {HookMiner} from "../test/utils/HookMiner.sol";

/**
 * @title DeployBastion
 * @notice Comprehensive deployment script for Bastion Protocol
 * @dev Deploys all contracts with proper address mining for hooks
 */
contract DeployBastion is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // Deployment addresses (to be saved)
    address public poolManager;
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

    // Hook configuration - must match BastionHook.getHookPermissions()
    uint160 public constant HOOK_FLAGS =
        uint160(
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_DONATE_FLAG
        );

    // Pool configuration
    uint24 public constant INITIAL_FEE = 3000; // 0.3%
    int24 public constant TICK_SPACING = 60;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying Bastion Protocol...");
        console2.log("Deployer:", deployer);
        console2.log("Network:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy PoolManager (or use existing)
        poolManager = deployPoolManager();
        console2.log("PoolManager:", poolManager);

        // Step 2: Deploy mock tokens
        deployMockTokens();

        // Step 3: Deploy VolatilityOracle
        volatilityOracle = address(new VolatilityOracle());
        console2.log("VolatilityOracle:", volatilityOracle);

        // Step 4: Mine and deploy BastionHook with correct address
        bastionHook = deployBastionHook(poolManager, volatilityOracle);
        console2.log("BastionHook:", bastionHook);

        // Step 5: Deploy InsuranceTranche
        insuranceTranche = address(new InsuranceTranche(bastionHook));
        console2.log("InsuranceTranche:", insuranceTranche);

        // Step 6: Initialize BastionHook with InsuranceTranche
        BastionHook(bastionHook).setInsuranceTranche(insuranceTranche);

        // Step 7: Deploy LendingModule
        // Constructor: (address _authorizedHook, address _stablecoin, uint256 _defaultInterestRate)
        lendingModule = address(new LendingModule(
            bastionHook,  // Authorized hook for collateral registration
            USDC,         // Stablecoin for borrowing
            500           // 5% APY default interest rate
        ));
        console2.log("LendingModule:", lendingModule);

        // Step 8: Deploy BastionVault
        // BastionVault accepts a single base asset (stETH as the primary deposit asset)
        bastionVault = address(new BastionVault(IERC20(stETH), "Bastion Vault", "bstVault"));
        console2.log("BastionVault:", bastionVault);

        // Step 9: Initialize pool with hook
        initializePool();

        vm.stopBroadcast();

        // Step 10: Save deployment addresses
        saveDeploymentAddresses();

        console2.log("\n=== Deployment Complete ===");
        console2.log("All contracts deployed successfully!");
        console2.log("\nNext steps:");
        console2.log("1. Verify contracts: forge verify-contract [address] [contract] --chain-id", block.chainid);
        console2.log("2. Update frontend addresses: frontend/lib/contracts/addresses.ts");
        console2.log("3. Deploy AVS contracts: forge script script/DeployAVS.s.sol");
    }

    function deployPoolManager() internal returns (address) {
        // Check if PoolManager already exists (e.g., on Base Sepolia)
        address existingPoolManager = vm.envOr("POOL_MANAGER", address(0));

        if (existingPoolManager != address(0)) {
            console2.log("Using existing PoolManager");
            return existingPoolManager;
        }

        // Deploy new PoolManager
        console2.log("Deploying new PoolManager");
        return address(new PoolManager(msg.sender)); // msg.sender as initial owner
    }

    function deployMockTokens() internal {
        console2.log("\nDeploying mock tokens...");

        stETH = address(new MockERC20("Staked ETH", "stETH", 18));
        console2.log("stETH:", stETH);

        cbETH = address(new MockERC20("Coinbase Staked ETH", "cbETH", 18));
        console2.log("cbETH:", cbETH);

        rETH = address(new MockERC20("Rocket Pool ETH", "rETH", 18));
        console2.log("rETH:", rETH);

        USDe = address(new MockERC20("Ethena USDe", "USDe", 18));
        console2.log("USDe:", USDe);

        USDC = address(new MockERC20("USD Coin", "USDC", 6));
        console2.log("USDC:", USDC);

        // Mint initial supply to deployer
        MockERC20(stETH).mint(msg.sender, 1000000 * 1e18);
        MockERC20(cbETH).mint(msg.sender, 1000000 * 1e18);
        MockERC20(rETH).mint(msg.sender, 1000000 * 1e18);
        MockERC20(USDe).mint(msg.sender, 1000000 * 1e18);
        MockERC20(USDC).mint(msg.sender, 1000000 * 1e6);
    }

    function deployBastionHook(address _poolManager, address _oracle) internal returns (address) {
        console2.log("\nMining hook address with correct flags...");

        // Mine for address with required hook flags
        bytes memory constructorArgs = abi.encode(_poolManager, _oracle);

        (address hookAddress, bytes32 salt) = HookMiner.find(
            msg.sender, // deployer (CREATE2 factory)
            HOOK_FLAGS,
            type(BastionHook).creationCode,
            constructorArgs
        );

        console2.log("Mined hook address:", hookAddress);
        console2.log("Salt:", uint256(salt));

        // Deploy hook using CREATE2 with mined salt
        BastionHook hook = new BastionHook{salt: salt}(
            IPoolManager(_poolManager),
            IVolatilityOracle(_oracle)
        );

        require(address(hook) == hookAddress, "Hook address mismatch");
        console2.log("Hook deployed successfully at mined address");

        return address(hook);
    }

    function initializePool() internal {
        console2.log("\nInitializing pool with hook...");

        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(stETH < USDC ? stETH : USDC),
            currency1: Currency.wrap(stETH < USDC ? USDC : stETH),
            fee: INITIAL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(bastionHook)
        });

        // Initialize pool at 1:1 price (sqrtPriceX96 for 1:1 = 2^96)
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96

        IPoolManager(poolManager).initialize(poolKey, sqrtPriceX96);

        console2.log("Pool initialized successfully");
        console2.log("Pool ID:");
        console2.logBytes32(PoolId.unwrap(poolKey.toId()));
    }

    function saveDeploymentAddresses() internal {
        string memory json = "deployment";

        vm.serializeAddress(json, "poolManager", poolManager);
        vm.serializeAddress(json, "bastionHook", bastionHook);
        vm.serializeAddress(json, "insuranceTranche", insuranceTranche);
        vm.serializeAddress(json, "lendingModule", lendingModule);
        vm.serializeAddress(json, "bastionVault", bastionVault);
        vm.serializeAddress(json, "volatilityOracle", volatilityOracle);
        vm.serializeAddress(json, "stETH", stETH);
        vm.serializeAddress(json, "cbETH", cbETH);
        vm.serializeAddress(json, "rETH", rETH);
        vm.serializeAddress(json, "USDe", USDe);
        vm.serializeAddress(json, "USDC", USDC);

        string memory finalJson = vm.serializeUint(json, "chainId", block.chainid);

        string memory outputPath = string.concat(
            "deployments/",
            vm.toString(block.chainid),
            ".json"
        );

        vm.writeJson(finalJson, outputPath);
        console2.log("\nDeployment addresses saved to:", outputPath);
    }
}
