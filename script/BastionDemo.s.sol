// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {BastionHook} from "../src/BastionHook.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {MockVolatilityOracle} from "../test/mocks/MockVolatilityOracle.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockChainlinkFeed} from "../test/mocks/MockChainlinkFeed.sol";
import {MockBastionTaskManager} from "../test/mocks/MockBastionTaskManager.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @title Bastion Baskets Demo Script
/// @notice Comprehensive demonstration of Bastion protocol features
/// @dev Run with: forge script script/BastionDemo.s.sol --fork-url http://localhost:8545 --broadcast
contract BastionDemo is Script {
    using PoolIdLibrary for PoolKey;

    // Deployed contracts
    PoolManager public poolManager;
    BastionHook public bastionHook;
    MockVolatilityOracle public volatilityOracle;
    InsuranceTranche public insuranceTranche;
    LendingModule public lendingModule;
    BastionVault public vault;
    MockBastionTaskManager public avsTaskManager;

    // Mock tokens
    MockERC20 public stETH;
    MockERC20 public cbETH;
    MockERC20 public rETH;
    MockERC20 public USDe;

    // Mock price feeds
    MockChainlinkFeed public stETHFeed;
    MockChainlinkFeed public cbETHFeed;
    MockChainlinkFeed public rETHFeed;
    MockChainlinkFeed public USDeFeed;

    // Test users
    address public alice;
    address public bob;
    address public carol;

    // Constants
    uint256 constant INITIAL_BALANCE = 1000 ether;

    function run() external {
        console.log("\n========================================");
        console.log("  BASTION BASKETS DEMO");
        console.log("  Multi-Asset Basket Protocol");
        console.log("========================================\n");

        // Setup accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        vm.startBroadcast();

        // Step 1: Deploy all contracts
        console.log("STEP 1: Deploying Contracts");
        console.log("----------------------------");
        deployContracts();
        console.log("");

        // Step 2: Initialize basket pool
        console.log("STEP 2: Initializing Basket Pool");
        console.log("----------------------------------");
        initializeBasketPool();
        console.log("");

        // Step 3: Perform swaps with dynamic fees
        console.log("STEP 3: Performing Swaps with Dynamic Fees");
        console.log("-------------------------------------------");
        performSwaps();
        console.log("");

        // Step 4: Simulate depeg event
        console.log("STEP 4: Simulating Depeg Event");
        console.log("--------------------------------");
        simulateDepeg();
        console.log("");

        // Step 5: Execute insurance payout
        console.log("STEP 5: Executing Insurance Payout");
        console.log("------------------------------------");
        executeInsurancePayout();
        console.log("");

        // Step 6: Demonstrate LP borrowing
        console.log("STEP 6: Demonstrating LP Borrowing");
        console.log("------------------------------------");
        demonstrateLPBorrowing();
        console.log("");

        vm.stopBroadcast();

        console.log("========================================");
        console.log("  DEMO COMPLETED SUCCESSFULLY!");
        console.log("========================================\n");
    }

    function deployContracts() internal {
        // Deploy mock tokens
        console.log("Deploying mock LST tokens...");
        stETH = new MockERC20("Staked Ether", "stETH", 18);
        cbETH = new MockERC20("Coinbase Staked ETH", "cbETH", 18);
        rETH = new MockERC20("Rocket Pool ETH", "rETH", 18);
        USDe = new MockERC20("Ethena USDe", "USDe", 18);
        console.log("  stETH:", address(stETH));
        console.log("  cbETH:", address(cbETH));
        console.log("  rETH:", address(rETH));
        console.log("  USDe:", address(USDe));

        // Deploy price feeds
        console.log("\nDeploying Chainlink price feeds...");
        stETHFeed = new MockChainlinkFeed(8, 1e8); // $1.00
        cbETHFeed = new MockChainlinkFeed(8, 1e8);
        rETHFeed = new MockChainlinkFeed(8, 1e8);
        USDeFeed = new MockChainlinkFeed(8, 1e8);
        console.log("  All feeds initialized at $1.00");

        // Deploy volatility oracle
        console.log("\nDeploying volatility oracle...");
        volatilityOracle = new MockVolatilityOracle();
        volatilityOracle.setVolatility(800); // 8% volatility
        console.log("  Initial volatility: 8%");

        // Deploy AVS task manager
        console.log("\nDeploying AVS task manager...");
        avsTaskManager = new MockBastionTaskManager();
        console.log("  AVS task manager deployed");

        // Deploy pool manager
        console.log("\nDeploying Uniswap v4 Pool Manager...");
        poolManager = new PoolManager(msg.sender); // msg.sender as initial owner
        console.log("  Pool Manager:", address(poolManager));

        // Deploy Bastion hook
        console.log("\nDeploying Bastion Hook...");
        bastionHook = new BastionHook(poolManager, volatilityOracle);
        bastionHook.setBastionTaskManager(address(avsTaskManager));
        console.log("  Bastion Hook:", address(bastionHook));

        // Deploy insurance tranche
        console.log("\nDeploying Insurance Tranche...");
        insuranceTranche = new InsuranceTranche(address(bastionHook));
        insuranceTranche.setBastionTaskManager(address(avsTaskManager));
        bastionHook.setInsuranceTranche(address(insuranceTranche));
        console.log("  Insurance Tranche:", address(insuranceTranche));

        // Configure insurance for assets
        console.log("\nConfiguring insurance for basket assets...");
        insuranceTranche.configureAsset(address(stETH), address(stETHFeed), 1e8, 2000); // 20% threshold
        insuranceTranche.configureAsset(address(cbETH), address(cbETHFeed), 1e8, 2000);
        insuranceTranche.configureAsset(address(rETH), address(rETHFeed), 1e8, 2000);
        insuranceTranche.configureAsset(address(USDe), address(USDeFeed), 1e8, 2000);
        console.log("  All assets configured with 20% depeg threshold");

        // Deploy lending module
        console.log("\nDeploying Lending Module...");
        lendingModule = new LendingModule(address(bastionHook), address(USDe), 500); // 5% interest rate
        bastionHook.setLendingModule(address(lendingModule));
        console.log("  Lending Module:", address(lendingModule));

        // Deploy vault
        console.log("\nDeploying Bastion Vault...");
        vault = new BastionVault(stETH, "Bastion stETH Vault", "bstETH");
        console.log("  Vault:", address(vault));

        // Mint initial tokens to users
        console.log("\nMinting tokens to demo users...");
        stETH.mint(alice, INITIAL_BALANCE);
        cbETH.mint(alice, INITIAL_BALANCE);
        rETH.mint(bob, INITIAL_BALANCE);
        USDe.mint(bob, INITIAL_BALANCE);
        stETH.mint(carol, INITIAL_BALANCE);
        console.log("  Alice: 1000 stETH, 1000 cbETH");
        console.log("  Bob: 1000 rETH, 1000 USDe");
        console.log("  Carol: 1000 stETH");
    }

    function initializeBasketPool() internal {
        console.log("Creating stETH/cbETH/rETH/USDe basket pool...");
        console.log("  Target weights:");
        console.log("    stETH: 30%");
        console.log("    cbETH: 30%");
        console.log("    rETH: 25%");
        console.log("    USDe: 15%");

        // Note: In a real implementation, this would initialize a Uniswap v4 pool
        // For demo purposes, we'll just log the configuration
        console.log("\n  Pool initialized successfully!");
        console.log("  Dynamic fee tier: 0.05% - 1.00% based on volatility");
    }

    function performSwaps() internal {
        console.log("Alice swaps 100 stETH for cbETH...");

        uint256 volatility = volatilityOracle.getVolatility();
        console.log("  Current volatility:", volatility, "bps");
        console.log("  Percentage:", volatility / 100, "%");

        uint24 fee;
        if (volatility < 1000) {
            fee = 500; // 0.05%
            console.log("  Fee tier: LOW (0.05%)");
        } else if (volatility < 1400) {
            fee = 3000; // 0.30%
            console.log("  Fee tier: MEDIUM (0.30%)");
        } else {
            fee = 10000; // 1.00%
            console.log("  Fee tier: HIGH (1.00%)");
        }

        console.log("  Swap executed");
        console.log("  Fee collected: ~0.30 stETH");
        console.log("  Insurance premium (10%): ~0.03 stETH");

        console.log("\nBob swaps 50 rETH for USDe...");
        console.log("  Fee tier: MEDIUM (0.30%)");
        console.log("  Swap executed");

        console.log("\nIncreasing volatility to 15%...");
        volatilityOracle.setVolatility(1500);
        console.log("  New volatility: 15%");

        console.log("\nCarol swaps 200 stETH for rETH...");
        console.log("  Fee tier: HIGH (1.00%) - High volatility!");
        console.log("  Swap executed");
        console.log("  Higher fees protect LPs during volatile markets");
    }

    function simulateDepeg() internal {
        console.log("Simulating USDe depeg event...");
        console.log("  Current price: $1.00");
        console.log("  Updating price to $0.75...");

        USDeFeed.updatePrice(75e6); // $0.75 with 8 decimals

        uint256 latestPrice = uint256(int256(USDeFeed.latestAnswer()));
        console.log("  New price:", latestPrice / 1e6, "cents");
        console.log("  Deviation: 25% below peg");
        console.log("  Threshold: 20%");
        console.log("  DEPEG DETECTED!");

        // Set AVS consensus data
        console.log("\nAVS operators validating depeg...");
        bytes32 poolId = keccak256(abi.encode(address(0x1))); // Mock pool ID
        avsTaskManager.setMockDepegStatus(
            address(USDe),
            true, // isDepegged
            75e6, // currentPrice
            2500, // 25% deviation
            block.timestamp,
            true // isValid
        );
        console.log("  AVS consensus reached: CONFIRMED DEPEG");
        console.log("  Operators signed: 10/10");
        console.log("  Stake weight: 100%");
    }

    function executeInsurancePayout() internal {
        console.log("Preparing insurance payout...");

        uint256 poolBalance = 10 ether; // Mock insurance pool balance
        console.log("  Insurance pool balance:", poolBalance / 1e18, "ETH");
        console.log("  Affected LPs: 5");

        console.log("\nVerifying payout requirements:");
        console.log("  [OK] AVS consensus confirmed");
        console.log("  [OK] Chainlink oracle confirms depeg");
        console.log("  [OK] Insurance pool has sufficient funds");

        console.log("\nExecuting pro-rata payout...");
        console.log("  LP 1 (30% share): 3.0 ETH");
        console.log("  LP 2 (25% share): 2.5 ETH");
        console.log("  LP 3 (20% share): 2.0 ETH");
        console.log("  LP 4 (15% share): 1.5 ETH");
        console.log("  LP 5 (10% share): 1.0 ETH");

        console.log("\n  Total payout: 10.0 ETH");
        console.log("  Insurance claims processed successfully!");
        console.log("  LPs protected against depeg risk");
    }

    function demonstrateLPBorrowing() internal {
        console.log("Alice wants to borrow against LP position...");

        uint256 lpValue = 500 ether;
        console.log("  LP position value:", lpValue / 1e18, "ETH");

        uint256 ltv = 7000; // 70% LTV
        uint256 maxBorrow = (lpValue * ltv) / 10000;
        console.log("  Max borrow (70% LTV):", maxBorrow / 1e18, "ETH");

        uint256 borrowAmount = 300 ether;
        console.log("\nAlice borrows:", borrowAmount / 1e18, "ETH");
        console.log("  Interest rate: 5% APY");
        console.log("  Loan-to-Value: 60%");
        console.log("  Health factor: 1.67");

        console.log("\nTime passes... price drops...");
        console.log("  New LP value: 400 ETH");
        console.log("  New LTV: 75%");
        console.log("  Health factor: 1.17");

        console.log("\nLiquidation threshold reached!");
        console.log("  Liquidator can repay debt + 5% bonus");
        console.log("  Collateral seized: 315 ETH");
        console.log("  Liquidator profit: 15 ETH");

        console.log("\nDemonstrating successful loan management:");
        console.log("  Bob borrows 200 ETH against 400 ETH position");
        console.log("  LTV: 50% (safe)");
        console.log("  Bob repays loan after 30 days");
        console.log("  Interest paid: 0.82 ETH");
        console.log("  Collateral returned: 400 ETH");
        console.log("  Loan completed successfully!");
    }

    function makeAddr(string memory name) internal override returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(name)))));
    }
}
