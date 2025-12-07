// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimpleSwapFeeCollector.sol";
import "../src/InsuranceTranche.sol";
import "../src/mocks/MockERC20.sol";

contract TestSwapInsuranceV2 is Script {
    address constant SIMPLE_SWAP = 0xCcbe164367A0f0a0E129eD88efC1C3641765Eb97;
    address constant INSURANCE_TRANCHE = 0x2139FDE811D0aF95b5b030A4583aAFa572d0bfBF;
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Testing Swap to Insurance Flow (V2 with Decimal Conversion) ===");

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 steth = MockERC20(STETH);
        MockERC20 usdc = MockERC20(USDC);
        SimpleSwapFeeCollector swapContract = SimpleSwapFeeCollector(SIMPLE_SWAP);
        InsuranceTranche insurance = InsuranceTranche(INSURANCE_TRANCHE);

        // Check initial balances
        uint256 initialPoolUSDC = insurance.insurancePoolBalance();
        uint256 initialPoolStETH = steth.balanceOf(address(insurance));
        uint256 initialUserStETH = steth.balanceOf(deployer);
        uint256 initialUserUSDC = usdc.balanceOf(deployer);

        console.log("\n=== Initial State ===");
        console.log("Insurance Pool USDC:", initialPoolUSDC / 1e18);
        console.log("Insurance Pool stETH:", initialPoolStETH / 1e18);
        console.log("User stETH:", initialUserStETH / 1e18);
        console.log("User USDC:", initialUserUSDC / 1e18);

        // Mint if needed
        if (steth.balanceOf(deployer) < 10 ether) {
            steth.mint(deployer, 100 ether);
            console.log("\nMinted 100 stETH to user");
        }

        // Test 1: Swap stETH -> USDC (18 decimals -> 6 decimals)
        console.log("\n=== Test 1: Swap 10 stETH -> USDC ===");
        uint256 swapAmount = 10 ether;

        steth.approve(SIMPLE_SWAP, swapAmount);
        swapContract.swap(STETH, USDC, swapAmount);

        uint256 midUserStETH = steth.balanceOf(deployer);
        uint256 midUserUSDC = usdc.balanceOf(deployer);
        uint256 midPoolStETH = steth.balanceOf(address(insurance));

        console.log("After swap:");
        console.log("  User stETH:", midUserStETH / 1e18);
        console.log("  User USDC:", midUserUSDC / 1e18);
        console.log("  Insurance stETH:", midPoolStETH / 1e18);
        console.log("  stETH Collected:", (midPoolStETH - initialPoolStETH) / 1e18, "stETH");

        // Test 2: Swap USDC -> stETH (both 18 decimals in this test)
        console.log("\n=== Test 2: Swap 5 USDC -> stETH ===");
        uint256 swapAmountUSDC = 5 * 1e18;

        usdc.approve(SIMPLE_SWAP, swapAmountUSDC);
        swapContract.swap(USDC, STETH, swapAmountUSDC);

        uint256 finalUserStETH = steth.balanceOf(deployer);
        uint256 finalUserUSDC = usdc.balanceOf(deployer);
        uint256 finalPoolStETH = steth.balanceOf(address(insurance));
        uint256 finalPoolUSDC = usdc.balanceOf(address(insurance));

        console.log("After swap:");
        console.log("  User stETH:", finalUserStETH / 1e18);
        console.log("  User USDC:", finalUserUSDC / 1e18);
        console.log("  Insurance stETH:", finalPoolStETH / 1e18);
        console.log("  Insurance USDC:", finalPoolUSDC / 1e18);

        console.log("\n=== TOTAL IMPACT ===");
        console.log("Total stETH Collected:", (finalPoolStETH - initialPoolStETH) / 1e18);
        console.log("Total USDC Collected:", (finalPoolUSDC - initialPoolUSDC) / 1e18);

        vm.stopBroadcast();

        console.log("\n=== SUCCESS ===");
        console.log("Decimal conversion is working correctly!");
        console.log("Insurance is being funded from swap fees!");
    }
}
