// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/mocks/MockERC20.sol";

contract AddLiquidity is Script {
    address constant SIMPLE_SWAP = 0xCcbe164367A0f0a0E129eD88efC1C3641765Eb97;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Adding Liquidity to SimpleSwap ===");

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 usdc = MockERC20(USDC);
        MockERC20 steth = MockERC20(STETH);

        // Mint 100k tokens to swap contract
        usdc.mint(SIMPLE_SWAP, 100_000 * 1e18); // 100k USDC (18 decimals)
        steth.mint(SIMPLE_SWAP, 100_000 * 1e18); // 100k stETH

        console.log("Minted:");
        console.log("  100k USDC to SimpleSwap");
        console.log("  100k stETH to SimpleSwap");

        vm.stopBroadcast();
    }
}
