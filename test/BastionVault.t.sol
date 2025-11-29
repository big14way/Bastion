// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BastionVault} from "../src/BastionVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockERC20
/// @notice Simple mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title BastionVaultTest
/// @notice Comprehensive tests for BastionVault ERC-4626 functionality
contract BastionVaultTest is Test {
    BastionVault public vault;
    MockERC20 public baseAsset;
    MockERC20 public stETH;
    MockERC20 public cbETH;
    MockERC20 public rETH;
    MockERC20 public usdE;

    address public owner;
    address public user1;
    address public user2;
    address public feeRecipient;

    uint256 constant INITIAL_BALANCE = 1000000e18;
    uint256 constant BASIS_POINTS = 10000;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        feeRecipient = address(0x3);

        // Deploy mock tokens
        baseAsset = new MockERC20("USD Coin", "USDC");
        stETH = new MockERC20("Lido Staked ETH", "stETH");
        cbETH = new MockERC20("Coinbase Staked ETH", "cbETH");
        rETH = new MockERC20("Rocket Pool ETH", "rETH");
        usdE = new MockERC20("Ethena USD", "USDe");

        // Deploy vault
        vault = new BastionVault(
            IERC20(address(baseAsset)),
            "Bastion Vault Token",
            "bvtUSDC"
        );

        // Mint initial balances to test users
        baseAsset.mint(user1, INITIAL_BALANCE);
        baseAsset.mint(user2, INITIAL_BALANCE);

        vm.label(address(vault), "BastionVault");
        vm.label(address(baseAsset), "USDC");
        vm.label(address(stETH), "stETH");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
    }

    /// @notice Test basic deposit functionality without fees
    function testBasicDeposit() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // First deposit should mint 1:1 shares
        assertEq(shares, depositAmount, "Should receive 1:1 shares on first deposit");
        assertEq(vault.balanceOf(user1), depositAmount, "User should have correct share balance");
        assertEq(vault.totalSupply(), depositAmount, "Total supply should match deposit");
        assertEq(vault.totalAssets(), depositAmount, "Total assets should match deposit");
    }

    /// @notice Test basic withdraw functionality
    function testBasicWithdraw() public {
        uint256 depositAmount = 1000e18;
        uint256 withdrawAmount = 500e18;

        // First deposit
        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);

        // Then withdraw
        uint256 sharesBurned = vault.withdraw(withdrawAmount, user1, user1);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1), depositAmount - sharesBurned, "Shares should be burned");
        assertEq(baseAsset.balanceOf(user1), INITIAL_BALANCE - depositAmount + withdrawAmount, "Should receive withdrawn assets");
    }

    /// @notice Test deposit with fees enabled
    function testDepositWithFees() public {
        // Set 1% deposit fee (100 basis points)
        vault.setFees(100, 0);
        vault.setFeeRecipient(feeRecipient);

        uint256 depositAmount = 1000e18;
        uint256 expectedFee = (depositAmount * 100) / BASIS_POINTS; // 1% = 10e18
        uint256 expectedAssetsAfterFee = depositAmount - expectedFee;

        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        assertEq(shares, expectedAssetsAfterFee, "Shares should reflect assets after fee");
        assertEq(baseAsset.balanceOf(feeRecipient), expectedFee, "Fee recipient should receive fee");
        assertEq(vault.totalAssets(), expectedAssetsAfterFee, "Total assets should exclude fee");
    }

    /// @notice Test withdraw with fees enabled
    function testWithdrawWithFees() public {
        uint256 depositAmount = 1000e18;

        // First deposit without fees
        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Set 2% withdrawal fee
        vault.setFees(0, 200);
        vault.setFeeRecipient(feeRecipient);

        uint256 withdrawAmount = 500e18;
        uint256 expectedFee = (withdrawAmount * 200) / BASIS_POINTS; // 2% = 10e18

        vm.startPrank(user1);
        uint256 sharesBurned = vault.withdraw(withdrawAmount, user1, user1);
        vm.stopPrank();

        assertEq(baseAsset.balanceOf(feeRecipient), expectedFee, "Fee recipient should receive withdrawal fee");
        assertEq(baseAsset.balanceOf(user1), INITIAL_BALANCE - depositAmount + withdrawAmount, "User receives requested amount");
    }

    /// @notice Test preview functions accuracy
    function testPreviewFunctions() public {
        uint256 depositAmount = 1000e18;

        // Preview deposit
        uint256 previewedShares = vault.previewDeposit(depositAmount);

        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        uint256 actualShares = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        assertEq(actualShares, previewedShares, "Actual shares should match preview");

        // Preview withdraw
        uint256 withdrawAmount = 500e18;
        uint256 previewedShareCost = vault.previewWithdraw(withdrawAmount);

        vm.startPrank(user1);
        uint256 actualShareCost = vault.withdraw(withdrawAmount, user1, user1);
        vm.stopPrank();

        assertEq(actualShareCost, previewedShareCost, "Actual share cost should match preview");
    }

    /// @notice Test previewMint and previewRedeem
    function testPreviewMintAndRedeem() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Preview mint
        uint256 sharesToMint = 500e18;
        uint256 assetsNeeded = vault.previewMint(sharesToMint);
        assertTrue(assetsNeeded >= sharesToMint, "Assets needed should account for shares");

        // Preview redeem
        uint256 sharesToRedeem = 500e18;
        uint256 assetsReceived = vault.previewRedeem(sharesToRedeem);
        assertTrue(assetsReceived > 0, "Should receive assets for redemption");
    }

    /// @notice Test convertToShares and convertToAssets
    function testConversionFunctions() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Test conversions
        uint256 assets = 100e18;
        uint256 shares = vault.convertToShares(assets);
        uint256 assetsBack = vault.convertToAssets(shares);

        assertEq(assetsBack, assets, "Round-trip conversion should match");
    }

    /// @notice Test adding basket assets
    function testAddBasketAsset() public {
        // Add stETH with 40% weight
        vault.addBasketAsset(address(stETH), 4000);

        (address token, uint256 weight, uint256 balance) = vault.getBasketAsset(0);
        assertEq(token, address(stETH), "Token address should match");
        assertEq(weight, 4000, "Weight should be 40%");
        assertEq(balance, 0, "Initial balance should be 0");
        assertEq(vault.totalWeight(), 4000, "Total weight should be 4000");
        assertTrue(vault.isBasketAsset(address(stETH)), "Should be marked as basket asset");
    }

    /// @notice Test updating basket asset weight
    function testUpdateAssetWeight() public {
        vault.addBasketAsset(address(stETH), 4000);
        vault.updateAssetWeight(address(stETH), 5000);

        (, uint256 weight,) = vault.getBasketAsset(0);
        assertEq(weight, 5000, "Weight should be updated to 50%");
        assertEq(vault.totalWeight(), 5000, "Total weight should reflect update");
    }

    /// @notice Test complete basket configuration
    function testCompleteBasketSetup() public {
        // Add all basket assets to total 100%
        vault.addBasketAsset(address(stETH), 4000);  // 40%
        vault.addBasketAsset(address(cbETH), 3000);  // 30%
        vault.addBasketAsset(address(rETH), 2000);   // 20%
        vault.addBasketAsset(address(usdE), 1000);   // 10%

        assertEq(vault.totalWeight(), 10000, "Total weight should be 100%");
        assertEq(vault.getBasketAssetCount(), 4, "Should have 4 basket assets");
    }

    /// @notice Test that weights cannot exceed 100%
    function testCannotExceed100PercentWeight() public {
        vault.addBasketAsset(address(stETH), 6000);

        vm.expectRevert("BastionVault: total weight exceeds 100%");
        vault.addBasketAsset(address(cbETH), 5000); // Would total 110%
    }

    /// @notice Test maximum asset limit
    function testMaxAssetLimit() public {
        // Add maximum allowed assets (10)
        for (uint256 i = 0; i < 10; i++) {
            address mockToken = address(uint160(0x1000 + i));
            vault.addBasketAsset(mockToken, 1000);
        }

        // Try to add 11th asset
        address extraToken = address(0x2000);
        vm.expectRevert("BastionVault: max assets reached");
        vault.addBasketAsset(extraToken, 0);
    }

    /// @notice Test fee limits (max 10%)
    function testFeeLimit() public {
        // Should succeed with 10% fee
        vault.setFees(1000, 1000);

        // Should fail with >10% deposit fee
        vm.expectRevert("BastionVault: deposit fee too high");
        vault.setFees(1001, 0);

        // Should fail with >10% withdrawal fee
        vm.expectRevert("BastionVault: withdrawal fee too high");
        vault.setFees(0, 1001);
    }

    /// @notice Test zero deposit
    function testZeroDeposit() public {
        vm.startPrank(user1);
        baseAsset.approve(address(vault), 0);

        vm.expectRevert("BastionVault: zero shares");
        vault.deposit(0, user1);
        vm.stopPrank();
    }

    /// @notice Test multiple users depositing
    function testMultipleUserDeposits() public {
        uint256 depositAmount1 = 1000e18;
        uint256 depositAmount2 = 2000e18;

        // User1 deposits
        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount1);
        uint256 shares1 = vault.deposit(depositAmount1, user1);
        vm.stopPrank();

        // User2 deposits
        vm.startPrank(user2);
        baseAsset.approve(address(vault), depositAmount2);
        uint256 shares2 = vault.deposit(depositAmount2, user2);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1), shares1, "User1 should have correct shares");
        assertEq(vault.balanceOf(user2), shares2, "User2 should have correct shares");
        assertEq(vault.totalSupply(), shares1 + shares2, "Total supply should equal sum of shares");
        assertEq(vault.totalAssets(), depositAmount1 + depositAmount2, "Total assets should equal sum of deposits");
    }

    /// @notice Test ownership transfer
    function testOwnershipTransfer() public {
        address newOwner = address(0x4);
        vault.transferOwnership(newOwner);

        // Old owner should not be able to set fees
        vm.prank(newOwner);
        vault.setFees(100, 100);

        // Verify only new owner can make changes
        vm.expectRevert("BastionVault: caller is not owner");
        vault.setFees(200, 200);
    }

    /// @notice Test cannot transfer to zero address
    function testCannotTransferToZeroAddress() public {
        vm.expectRevert("BastionVault: zero address");
        vault.transferOwnership(address(0));
    }

    /// @notice Test fee recipient update
    function testFeeRecipientUpdate() public {
        address newFeeRecipient = address(0x5);
        vault.setFeeRecipient(newFeeRecipient);

        vault.setFees(100, 0);

        uint256 depositAmount = 1000e18;
        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        uint256 expectedFee = (depositAmount * 100) / BASIS_POINTS;
        assertEq(baseAsset.balanceOf(newFeeRecipient), expectedFee, "New fee recipient should receive fees");
    }

    /// @notice Test redeem functionality
    function testRedeem() public {
        uint256 depositAmount = 1000e18;

        // First deposit
        vm.startPrank(user1);
        baseAsset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user1);

        // Then redeem half the shares
        uint256 sharesToRedeem = shares / 2;
        uint256 assetsReceived = vault.redeem(sharesToRedeem, user1, user1);
        vm.stopPrank();

        assertTrue(assetsReceived > 0, "Should receive assets");
        assertEq(vault.balanceOf(user1), shares - sharesToRedeem, "Shares should be burned");
    }

    /// @notice Test mint functionality
    function testMint() public {
        uint256 sharesToMint = 1000e18;
        uint256 maxAssets = 2000e18;

        vm.startPrank(user1);
        baseAsset.approve(address(vault), maxAssets);
        uint256 assetsUsed = vault.mint(sharesToMint, user1);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1), sharesToMint, "Should receive requested shares");
        assertTrue(assetsUsed <= maxAssets, "Should not use more than max assets");
    }
}
