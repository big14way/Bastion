// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/InsuranceTranche.sol";
import "../src/mocks/MockERC20.sol";

/**
 * @title TestInsurancePayout Script
 * @notice Funds insurance pool and creates a test payout event
 * @dev Uses the new testFundPool and testExecutePayout functions
 */
contract TestInsurancePayout is Script {
    // NEW DEPLOYED ADDRESS (with test functions)
    address constant INSURANCE_TRANCHE = 0x2139FDE811D0aF95b5b030A4583aAFa572d0bfBF;
    address constant USDC = 0x7BE60377E17aD50b289F306996fa31494364c56a;
    address constant STETH = 0x60D36283c134bF0f73B67626B47445455e1FbA9e;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Testing Insurance Payout ===");
        console.log("Deployer:", deployer);
        console.log("InsuranceTranche:", INSURANCE_TRANCHE);

        vm.startBroadcast(deployerPrivateKey);

        InsuranceTranche insurance = InsuranceTranche(INSURANCE_TRANCHE);
        MockERC20 usdc = MockERC20(USDC);

        // 1. Check/Mint USDC
        console.log("\n=== Step 1: Ensure USDC Balance ===");
        uint256 fundAmount = 10_000 * 1e6; // 10,000 USDC
        uint256 currentBalance = usdc.balanceOf(deployer);
        console.log("Current USDC balance:", currentBalance / 1e6);

        if (currentBalance < fundAmount) {
            console.log("Minting additional USDC...");
            usdc.mint(deployer, fundAmount - currentBalance + 100_000 * 1e6);
            console.log("Minted USDC successfully");
        }

        // 2. Approve InsuranceTranche
        console.log("\n=== Step 2: Approve USDC ===");
        usdc.approve(INSURANCE_TRANCHE, fundAmount);
        console.log("Approved", fundAmount / 1e6, "USDC");

        // 3. Fund insurance pool using test function
        console.log("\n=== Step 3: Fund Insurance Pool ===");
        insurance.testFundPool(USDC, fundAmount);
        uint256 poolBalance = insurance.insurancePoolBalance();
        console.log("Insurance pool funded with:", poolBalance / 1e18);

        // 4. Execute test payout
        console.log("\n=== Step 4: Execute Test Payout ===");
        uint256 mockPrice = 75000000; // $0.75 (Chainlink uses 8 decimals)
        uint256 mockDeviation = 2500; // 25% deviation (basis points)

        insurance.testExecutePayout(STETH, mockPrice, mockDeviation);
        console.log("Test payout executed for stETH");

        vm.stopBroadcast();

        // 5. Verify payout was created
        console.log("\n=== Step 5: Verify Payout ===");
        uint256 payoutCount = insurance.getPayoutHistoryCount();
        console.log("Total payout events:", payoutCount);

        if (payoutCount > 0) {
            (address asset, uint256 totalPayout, uint256 timestamp, uint256 price, uint256 deviation) =
                insurance.payoutHistory(payoutCount - 1);

            console.log("\nLatest Payout Event:");
            console.log("  Asset:", asset);
            console.log("  Total Payout:", totalPayout / 1e18);
            console.log("  Price:", price);
            console.log("  Deviation:", deviation, "bps");
            console.log("  Timestamp:", timestamp);
        }

        // 6. Check claimable amount for deployer
        (uint256 shares,, bool isActive) = insurance.getLPPosition(deployer);
        console.log("\nYour LP Position:");
        console.log("  Shares:", shares / 1e18);
        console.log("  Active:", isActive);

        if (payoutCount > 0 && shares > 0 && isActive) {
            uint256 claimable = insurance.getClaimableAmount(deployer, payoutCount - 1);
            console.log("  Claimable:", claimable / 1e18, "USDC equivalent");

            console.log("\n=== SUCCESS ===");
            console.log("You can now claim your payout!");
            console.log("Visit: http://localhost:3002/insurance");
        }
    }
}
