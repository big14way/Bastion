// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {LendingModule} from "../src/LendingModule.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SetupProtocol
 * @notice Complete protocol setup script:
 * 1. Mints test tokens to your wallet
 * 2. Configures InsuranceTranche (payout token, assets)
 * 3. Funds the lending pool
 * 4. Sets up basket assets in vault
 */
contract SetupProtocol is Script {
    // Deployed contract addresses (Base Sepolia)
    address constant INSURANCE_TRANCHE = 0x5739C58361D03b18bD810B9b1CDf273e37986709;
    address constant LENDING_MODULE = 0x56503851063bE95F8997e503995Af05Fd5864e91;
    address constant BASTION_VAULT = 0xBcaaa01CAD57fC48cB05e592F088D73B82e36311;

    // Mock token addresses
    address constant STETH = 0x5cd393e88E5d81ce27D6FF7B12c75D098Ca1C433;
    address constant CBETH = 0x7F039F2c8cE3177ea96B361c438c7d7C752eAEdF;
    address constant RETH = 0x9d566fce6F978252FE72E43C4dcF490dd920120D;
    address constant USDE = 0x3957211173570F321cbFe3cc2A0f8cD92Fd5002B;
    address constant USDC = 0x0c864a8B369e22E1bcC3B0cFc74a6B37D8777c20;

    // Chainlink mock price feeds
    address constant CHAINLINK_STETH = 0x73fd79706e56809ead9b5C8C1B825d41E829cC34;
    address constant CHAINLINK_ETH = 0xB39887974582d55BE705843A4A2A4b071C348729;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("\n=== Bastion Protocol Setup ===");
        console2.log("Deployer:", deployer);
        console2.log("Network:", block.chainid);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Mint test tokens to deployer
        console2.log("Step 1: Minting test tokens to your wallet...");
        mintTestTokens(deployer);

        // Step 2: Configure InsuranceTranche
        console2.log("\nStep 2: Configuring InsuranceTranche...");
        setupInsurance();

        // Step 3: Fund the lending pool
        console2.log("\nStep 3: Funding the lending pool...");
        fundLendingPool(deployer);

        // Step 4: Setup vault basket assets
        console2.log("\nStep 4: Configuring BastionVault basket...");
        setupVault();

        // Step 5: Approve tokens for protocol use
        console2.log("\nStep 5: Approving tokens for protocol...");
        approveTokens(deployer);

        vm.stopBroadcast();

        console2.log("\n=== Setup Complete! ===\n");
        printSummary(deployer);
    }

    function mintTestTokens(address recipient) internal {
        // Mint 100,000 of each token
        uint256 amountLargeDecimals = 100_000 * 1e18; // For 18 decimal tokens
        uint256 amountSmallDecimals = 100_000 * 1e6;  // For 6 decimal tokens (USDC)

        MockERC20(STETH).mint(recipient, amountLargeDecimals);
        console2.log("  Minted 100,000 stETH");

        MockERC20(CBETH).mint(recipient, amountLargeDecimals);
        console2.log("  Minted 100,000 cbETH");

        MockERC20(RETH).mint(recipient, amountLargeDecimals);
        console2.log("  Minted 100,000 rETH");

        MockERC20(USDE).mint(recipient, amountLargeDecimals);
        console2.log("  Minted 100,000 USDe");

        MockERC20(USDC).mint(recipient, amountSmallDecimals);
        console2.log("  Minted 100,000 USDC");
    }

    function setupInsurance() internal {
        InsuranceTranche insurance = InsuranceTranche(INSURANCE_TRANCHE);

        // Set USDC as payout token
        insurance.setPayoutToken(USDC);
        console2.log("  Set USDC as payout token");

        // Configure stETH for monitoring
        insurance.configureAsset(
            STETH,
            CHAINLINK_STETH,  // Price feed
            2000,              // 20% depeg threshold (in basis points)
            3600               // 1 hour max price age
        );
        console2.log("  Configured stETH monitoring (20% depeg threshold)");

        // Configure cbETH for monitoring
        insurance.configureAsset(
            CBETH,
            CHAINLINK_ETH,    // Using ETH price feed for cbETH
            2000,              // 20% depeg threshold
            3600               // 1 hour max price age
        );
        console2.log("  Configured cbETH monitoring (20% depeg threshold)");

        // Configure rETH for monitoring
        insurance.configureAsset(
            RETH,
            CHAINLINK_ETH,    // Using ETH price feed for rETH
            2000,              // 20% depeg threshold
            3600               // 1 hour max price age
        );
        console2.log("  Configured rETH monitoring (20% depeg threshold)");
    }

    function fundLendingPool(address funder) internal {
        LendingModule lending = LendingModule(LENDING_MODULE);

        // Fund pool with 50,000 USDC
        uint256 fundAmount = 50_000 * 1e6;

        // Approve and fund
        IERC20(USDC).approve(LENDING_MODULE, fundAmount);
        lending.fundPool(fundAmount);

        console2.log("  Funded lending pool with 50,000 USDC");
        console2.log("  Total pool liquidity:", lending.totalLendingPool() / 1e6, "USDC");
    }

    function setupVault() internal {
        BastionVault vault = BastionVault(BASTION_VAULT);

        // Add basket assets with weights
        // stETH: 40%
        vault.addBasketAsset(STETH, 4000);
        console2.log("  Added stETH to basket (40% weight)");

        // cbETH: 30%
        vault.addBasketAsset(CBETH, 3000);
        console2.log("  Added cbETH to basket (30% weight)");

        // rETH: 30%
        vault.addBasketAsset(RETH, 3000);
        console2.log("  Added rETH to basket (30% weight)");

        console2.log("  Total basket weight: 100%");
    }

    function approveTokens(address owner) internal {
        uint256 maxApproval = type(uint256).max;

        // Approve InsuranceTranche
        IERC20(STETH).approve(INSURANCE_TRANCHE, maxApproval);
        IERC20(CBETH).approve(INSURANCE_TRANCHE, maxApproval);
        IERC20(RETH).approve(INSURANCE_TRANCHE, maxApproval);
        IERC20(USDC).approve(INSURANCE_TRANCHE, maxApproval);

        // Approve LendingModule
        IERC20(STETH).approve(LENDING_MODULE, maxApproval);
        IERC20(USDC).approve(LENDING_MODULE, maxApproval);

        // Approve BastionVault
        IERC20(STETH).approve(BASTION_VAULT, maxApproval);
        IERC20(CBETH).approve(BASTION_VAULT, maxApproval);
        IERC20(RETH).approve(BASTION_VAULT, maxApproval);

        console2.log("  Approved all tokens for protocol contracts");
    }

    function printSummary(address user) internal view {
        console2.log("Your Token Balances:");
        console2.log("  stETH:", IERC20(STETH).balanceOf(user) / 1e18, "tokens");
        console2.log("  cbETH:", IERC20(CBETH).balanceOf(user) / 1e18, "tokens");
        console2.log("  rETH:", IERC20(RETH).balanceOf(user) / 1e18, "tokens");
        console2.log("  USDe:", IERC20(USDE).balanceOf(user) / 1e18, "tokens");
        console2.log("  USDC:", IERC20(USDC).balanceOf(user) / 1e6, "tokens");

        console2.log("\nLending Pool:");
        console2.log("  Available liquidity:", LendingModule(LENDING_MODULE).totalLendingPool() / 1e6, "USDC");

        console2.log("\nInsurance Configuration:");
        console2.log("  Monitored assets: stETH, cbETH, rETH");
        console2.log("  Depeg threshold: 20%");
        console2.log("  Payout token: USDC");

        console2.log("\nVault Configuration:");
        console2.log("  Base asset: stETH");
        console2.log("  Basket assets: stETH (40%), cbETH (30%), rETH (30%)");

        console2.log("\nNext Steps:");
        console2.log("1. Visit http://localhost:3002");
        console2.log("2. Connect your wallet (0x208B2660e5F62CDca21869b389c5aF9E7f0faE89)");
        console2.log("3. Start testing:");
        console2.log("   - Deposit stETH into vault");
        console2.log("   - Borrow USDC against LP positions");
        console2.log("   - Monitor insurance coverage");
    }
}
