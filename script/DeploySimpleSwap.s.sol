// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimpleSwapFeeCollector.sol";
import "../src/InsuranceTranche.sol";
import "../src/mocks/MockERC20.sol";

/**
 * @title DeploySimpleSwap
 * @notice Deploy SimpleSwapFeeCollector to enable swap fees funding insurance
 * @dev Simplified alternative to Uniswap v4 hooks for testnet
 */
contract DeploySimpleSwap is Script {
    // Known addresses
    address constant INSURANCE_TRANCHE = 0x2139FDE811D0aF95b5b030A4583aAFa572d0bfBF;
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying Simple Swap Fee Collector ===");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy SimpleSwapFeeCollector
        console.log("\n=== Step 1: Deploy Swap Contract ===");
        SimpleSwapFeeCollector swapContract = new SimpleSwapFeeCollector(INSURANCE_TRANCHE);
        console.log("SimpleSwapFeeCollector deployed at:", address(swapContract));

        // 2. Authorize swap contract in InsuranceTranche
        console.log("\n=== Step 2: Authorize Swap Contract ===");
        InsuranceTranche insurance = InsuranceTranche(INSURANCE_TRANCHE);
        insurance.setAuthorizedHook(address(swapContract));
        console.log("Swap contract authorized in InsuranceTranche");

        // 3. Add liquidity to swap contract for testing
        console.log("\n=== Step 3: Add Liquidity for Testing ===");
        MockERC20 steth = MockERC20(STETH);
        MockERC20 usdc = MockERC20(USDC);

        // Mint tokens for liquidity
        uint256 liquidityAmount = 100_000 * 1e18; // 100k stETH
        uint256 liquidityAmountUSDC = 100_000 * 1e6; // 100k USDC

        steth.mint(address(swapContract), liquidityAmount);
        usdc.mint(address(swapContract), liquidityAmountUSDC);

        console.log("Added liquidity:");
        console.log("  stETH:", liquidityAmount / 1e18);
        console.log("  USDC:", liquidityAmountUSDC / 1e6);

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("\nContract Addresses:");
        console.log("  SimpleSwapFeeCollector:", address(swapContract));
        console.log("  InsuranceTranche:", INSURANCE_TRANCHE);

        console.log("\n=== How It Works ===");
        console.log("1. Users swap tokens through SimpleSwapFeeCollector");
        console.log("2. 0.2% fee is charged on swaps");
        console.log("3. 80% of fee (0.16%) goes to insurance pool");
        console.log("4. Insurance pool balance increases automatically");

        console.log("\n=== Next Steps ===");
        console.log("1. Update frontend/lib/contracts/addresses.ts:");
        console.log("   SimpleSwap:", address(swapContract));
        console.log("\n2. Create swap UI in frontend");
        console.log("\n3. Test: Swap stETH <-> USDC to fund insurance");

        console.log("\n=== Test Swap Command ===");
        console.log("To test manually:");
        console.log("cast send", address(swapContract));
        console.log("  'swap(address,address,uint256)'");
        console.log("  ", STETH);
        console.log("  ", USDC);
        console.log("  ", "1000000000000000000000");  // 1000 stETH
        console.log("  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY");
    }
}
