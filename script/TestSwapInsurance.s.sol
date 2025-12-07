// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimpleSwapFeeCollector.sol";
import "../src/InsuranceTranche.sol";
import "../src/mocks/MockERC20.sol";

contract TestSwapInsurance is Script {
    address constant SIMPLE_SWAP = 0x9Be32DBdfbB0e8bAF561823388ccef589011bcf6;
    address constant INSURANCE_TRANCHE = 0x2139FDE811D0aF95b5b030A4583aAFa572d0bfBF;
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Testing Swap to Insurance Flow ===");

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 steth = MockERC20(STETH);
        SimpleSwapFeeCollector swapContract = SimpleSwapFeeCollector(SIMPLE_SWAP);
        InsuranceTranche insurance = InsuranceTranche(INSURANCE_TRANCHE);

        // Check initial balance
        uint256 initialPool = insurance.insurancePoolBalance();
        console.log("Initial Insurance Pool:", initialPool);

        // Mint if needed
        if (steth.balanceOf(deployer) < 10 ether) {
            steth.mint(deployer, 100 ether);
        }

        // Swap 10 stETH
        uint256 swapAmount = 10 ether;
        console.log("Swapping 10 stETH...");

        steth.approve(SIMPLE_SWAP, swapAmount);
        swapContract.swap(STETH, USDC, swapAmount);

        // Check final balance
        uint256 finalPool = insurance.insurancePoolBalance();
        console.log("Final Insurance Pool:", finalPool);
        console.log("Increase:", (finalPool - initialPool) / 1e18, "tokens");

        vm.stopBroadcast();
    }
}
