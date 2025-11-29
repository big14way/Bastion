// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title MockERC20
/// @notice Simple mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

/// @title MockChainlinkPriceFeed
/// @notice Mock Chainlink price feed for testing
contract MockChainlinkPriceFeed is AggregatorV3Interface {
    int256 private _price;
    uint8 private _decimals;
    uint80 private _roundId;
    uint256 private _updatedAt;

    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _roundId = 1;
        _updatedAt = block.timestamp;
    }

    function setPrice(int256 newPrice) external {
        _price = newPrice;
        _roundId++;
        _updatedAt = block.timestamp;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}

/// @title InsuranceTrancheTest
/// @notice Comprehensive tests for InsuranceTranche
contract InsuranceTrancheTest is Test {
    InsuranceTranche public insurance;
    MockERC20 public stETH;
    MockERC20 public usdc;
    MockChainlinkPriceFeed public stETHFeed;
    MockChainlinkPriceFeed public usdcFeed;

    address public owner;
    address public hook;
    address public lp1;
    address public lp2;

    uint256 constant INITIAL_BALANCE = 1000000e18;
    uint256 constant BASIS_POINTS = 10000;
    uint256 constant DEFAULT_DEPEG_THRESHOLD = 2000; // 20%

    // Price feed decimals (Chainlink uses 8 decimals)
    uint8 constant PRICE_DECIMALS = 8;

    // Target prices (in 8 decimals)
    int256 constant ETH_TARGET_PRICE = 1e8; // $1 for testing (stETH should be ~= ETH)
    int256 constant USDC_TARGET_PRICE = 1e8; // $1

    function setUp() public {
        owner = address(this);
        hook = address(0x1);
        lp1 = address(0x2);
        lp2 = address(0x3);

        // Deploy mock tokens
        stETH = new MockERC20("Lido Staked ETH", "stETH");
        usdc = new MockERC20("USD Coin", "USDC");

        // Deploy mock price feeds
        stETHFeed = new MockChainlinkPriceFeed(ETH_TARGET_PRICE, PRICE_DECIMALS);
        usdcFeed = new MockChainlinkPriceFeed(USDC_TARGET_PRICE, PRICE_DECIMALS);

        // Deploy insurance tranche
        insurance = new InsuranceTranche(hook);

        // Mint tokens for testing
        usdc.mint(hook, INITIAL_BALANCE);
        usdc.mint(owner, INITIAL_BALANCE);
        stETH.mint(address(insurance), INITIAL_BALANCE);

        vm.label(address(insurance), "InsuranceTranche");
        vm.label(hook, "Hook");
        vm.label(lp1, "LP1");
        vm.label(lp2, "LP2");
    }

    /// @notice Test asset configuration
    function testConfigureAsset() public {
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        assertTrue(insurance.isConfigured(address(stETH)), "Asset should be configured");

        (address token, address priceFeed, uint256 targetPrice, uint256 depegThreshold, bool isActive) =
            insurance.getAssetConfig(address(stETH));

        assertEq(token, address(stETH), "Token address should match");
        assertEq(priceFeed, address(stETHFeed), "Price feed should match");
        assertEq(targetPrice, uint256(uint256(ETH_TARGET_PRICE)), "Target price should match");
        assertEq(depegThreshold, DEFAULT_DEPEG_THRESHOLD, "Depeg threshold should match");
        assertTrue(isActive, "Asset should be active");
    }

    /// @notice Test premium collection
    function testCollectPremium() public {
        uint256 premiumAmount = 1000e18;

        // Approve insurance contract to spend tokens
        vm.startPrank(hook);
        usdc.approve(address(insurance), premiumAmount);

        // Collect premium
        insurance.collectPremiumWithToken(address(usdc), premiumAmount);
        vm.stopPrank();

        assertEq(insurance.insurancePoolBalance(), premiumAmount, "Pool balance should match premium");
    }

    /// @notice Test minimum premium requirement
    function testMinimumPremium() public {
        uint256 tinyPremium = 500; // Below MIN_PREMIUM of 1000

        vm.startPrank(hook);
        usdc.approve(address(insurance), tinyPremium);

        vm.expectRevert("InsuranceTranche: premium too small");
        insurance.collectPremiumWithToken(address(usdc), tinyPremium);
        vm.stopPrank();
    }

    /// @notice Test depeg detection when price is normal
    function testCheckDepegNormal() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Check depeg (price is at target)
        (bool isDepegged, uint256 currentPrice, uint256 deviation) = insurance.checkDepeg(address(stETH));

        assertFalse(isDepegged, "Should not be depegged at target price");
        assertEq(currentPrice, uint256(uint256(ETH_TARGET_PRICE)), "Current price should match target");
        assertEq(deviation, 0, "Deviation should be 0");
    }

    /// @notice Test depeg detection when price drops 25% (exceeds 20% threshold)
    function testCheckDepegExceeded() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Set price to 75% of target (25% drop)
        int256 depeggedPrice = (ETH_TARGET_PRICE * 75) / 100;
        stETHFeed.setPrice(depeggedPrice);

        // Check depeg
        (bool isDepegged, uint256 currentPrice, uint256 deviation) = insurance.checkDepeg(address(stETH));

        assertTrue(isDepegged, "Should be depegged with 25% drop");
        assertEq(currentPrice, uint256(uint256(depeggedPrice)), "Current price should match depegged price");
        assertEq(deviation, 2500, "Deviation should be 2500 basis points (25%)");
    }

    /// @notice Test depeg detection at exact threshold (20%)
    function testCheckDepegAtThreshold() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Set price to exactly 80% of target (20% drop - at threshold)
        int256 thresholdPrice = (ETH_TARGET_PRICE * 80) / 100;
        stETHFeed.setPrice(thresholdPrice);

        // Check depeg
        (bool isDepegged, uint256 currentPrice, uint256 deviation) = insurance.checkDepeg(address(stETH));

        assertFalse(isDepegged, "Should not be depegged at exactly threshold");
        assertEq(deviation, 2000, "Deviation should be 2000 basis points (20%)");
    }

    /// @notice Test depeg detection just below threshold (19%)
    function testCheckDepegBelowThreshold() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Set price to 81% of target (19% drop - just below threshold)
        int256 belowThresholdPrice = (ETH_TARGET_PRICE * 81) / 100;
        stETHFeed.setPrice(belowThresholdPrice);

        // Check depeg
        (bool isDepegged,,) = insurance.checkDepeg(address(stETH));

        assertFalse(isDepegged, "Should not be depegged below threshold");
    }

    /// @notice Test payout execution
    function testExecutePayout() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Add premium to pool
        uint256 premiumAmount = 10000e18;
        vm.startPrank(hook);
        usdc.approve(address(insurance), premiumAmount);
        insurance.collectPremiumWithToken(address(usdc), premiumAmount);
        vm.stopPrank();

        // Register LP positions
        vm.prank(hook);
        insurance.updateLPPosition(lp1, 1000e18);

        vm.prank(hook);
        insurance.updateLPPosition(lp2, 1000e18);

        // Cause depeg (30% drop)
        int256 depeggedPrice = (ETH_TARGET_PRICE * 70) / 100;
        stETHFeed.setPrice(depeggedPrice);

        // Execute payout
        insurance.executePayout(address(stETH));

        // Pool should be emptied
        assertEq(insurance.insurancePoolBalance(), 0, "Pool should be empty after payout");

        // Check payout history
        assertEq(insurance.getPayoutHistoryCount(), 1, "Should have 1 payout event");

        (address asset, uint256 totalPayout,, uint256 price, uint256 deviation) = insurance.getPayoutEvent(0);
        assertEq(asset, address(stETH), "Payout asset should be stETH");
        assertEq(totalPayout, premiumAmount, "Total payout should match pool balance");
        assertEq(price, uint256(uint256(depeggedPrice)), "Price should match depegged price");
        assertEq(deviation, 3000, "Deviation should be 3000 basis points (30%)");
    }

    /// @notice Test payout fails if not depegged
    function testPayoutFailsIfNotDepegged() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Add premium
        uint256 premiumAmount = 10000e18;
        vm.startPrank(hook);
        usdc.approve(address(insurance), premiumAmount);
        insurance.collectPremiumWithToken(address(usdc), premiumAmount);
        vm.stopPrank();

        // Try to execute payout without depeg
        vm.expectRevert("InsuranceTranche: asset not depegged");
        insurance.executePayout(address(stETH));
    }

    /// @notice Test LP position management
    function testLPPositionManagement() public {
        uint256 shares = 1000e18;

        vm.prank(hook);
        insurance.updateLPPosition(lp1, shares);

        (uint256 lpShares, uint256 lastUpdate, bool isActive) = insurance.getLPPosition(lp1);

        assertEq(lpShares, shares, "LP shares should match");
        assertEq(lastUpdate, block.timestamp, "Last update should be current timestamp");
        assertTrue(isActive, "Position should be active");
        assertEq(insurance.totalLPShares(), shares, "Total LP shares should match");
    }

    /// @notice Test LP position updates
    function testLPPositionUpdates() public {
        uint256 initialShares = 1000e18;
        uint256 newShares = 2000e18;

        // Initial position
        vm.prank(hook);
        insurance.updateLPPosition(lp1, initialShares);

        // Update position
        vm.prank(hook);
        insurance.updateLPPosition(lp1, newShares);

        (uint256 lpShares,,) = insurance.getLPPosition(lp1);
        assertEq(lpShares, newShares, "LP shares should be updated");
        assertEq(insurance.totalLPShares(), newShares, "Total LP shares should reflect update");
    }

    /// @notice Test multiple LP positions
    function testMultipleLPPositions() public {
        uint256 shares1 = 1000e18;
        uint256 shares2 = 2000e18;

        vm.prank(hook);
        insurance.updateLPPosition(lp1, shares1);

        vm.prank(hook);
        insurance.updateLPPosition(lp2, shares2);

        assertEq(insurance.totalLPShares(), shares1 + shares2, "Total shares should sum correctly");
    }

    /// @notice Test asset deactivation
    function testDeactivateAsset() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Deactivate
        insurance.deactivateAsset(address(stETH));

        (,,,, bool isActive) = insurance.getAssetConfig(address(stETH));
        assertFalse(isActive, "Asset should be inactive");
    }

    /// @notice Test asset reactivation
    function testReactivateAsset() public {
        // Configure and deactivate
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );
        insurance.deactivateAsset(address(stETH));

        // Reactivate
        insurance.activateAsset(address(stETH));

        (,,,, bool isActive) = insurance.getAssetConfig(address(stETH));
        assertTrue(isActive, "Asset should be active");
    }

    /// @notice Test emergency pause
    function testEmergencyPause() public {
        insurance.setPaused(true);
        assertTrue(insurance.paused(), "Should be paused");

        // Try to collect premium when paused
        vm.startPrank(hook);
        usdc.approve(address(insurance), 1000e18);
        vm.expectRevert("InsuranceTranche: contract is paused");
        insurance.collectPremiumWithToken(address(usdc), 1000e18);
        vm.stopPrank();
    }

    /// @notice Test emergency withdrawal
    function testEmergencyWithdraw() public {
        // Add some tokens to contract
        uint256 amount = 5000e18;
        vm.startPrank(hook);
        usdc.approve(address(insurance), amount);
        insurance.collectPremiumWithToken(address(usdc), amount);
        vm.stopPrank();

        // Pause and withdraw
        insurance.setPaused(true);
        address recipient = address(0x999);

        uint256 balanceBefore = usdc.balanceOf(recipient);
        insurance.emergencyWithdraw(address(usdc), amount, recipient);
        uint256 balanceAfter = usdc.balanceOf(recipient);

        assertEq(balanceAfter - balanceBefore, amount, "Recipient should receive withdrawn amount");
    }

    /// @notice Test emergency withdrawal fails when not paused
    function testEmergencyWithdrawFailsWhenNotPaused() public {
        vm.expectRevert("InsuranceTranche: not paused");
        insurance.emergencyWithdraw(address(usdc), 1000e18, address(0x999));
    }

    /// @notice Test check all assets
    function testCheckAllAssets() public {
        // Configure multiple assets
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );
        insurance.configureAsset(
            address(usdc), address(usdcFeed), uint256(uint256(USDC_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Depeg stETH only
        int256 depeggedPrice = (ETH_TARGET_PRICE * 70) / 100;
        stETHFeed.setPrice(depeggedPrice);

        // Check all
        address[] memory depegged = insurance.checkAllAssets();

        assertEq(depegged.length, 1, "Should have 1 depegged asset");
        assertEq(depegged[0], address(stETH), "Depegged asset should be stETH");
    }

    /// @notice Test ownership transfer
    function testOwnershipTransfer() public {
        address newOwner = address(0x888);
        insurance.transferOwnership(newOwner);

        // Old owner should not be able to configure asset
        vm.expectRevert("InsuranceTranche: caller is not owner");
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // New owner should be able to configure
        vm.prank(newOwner);
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        assertTrue(insurance.isConfigured(address(stETH)), "New owner should be able to configure");
    }

    /// @notice Test unauthorized hook cannot collect premium
    function testUnauthorizedHookCannotCollectPremium() public {
        address unauthorized = address(0x777);

        vm.startPrank(unauthorized);
        usdc.approve(address(insurance), 1000e18);
        vm.expectRevert("InsuranceTranche: caller is not authorized hook");
        insurance.collectPremiumWithToken(address(usdc), 1000e18);
        vm.stopPrank();
    }

    /// @notice Test authorized hook update
    function testSetAuthorizedHook() public {
        address newHook = address(0x666);
        insurance.setAuthorizedHook(newHook);

        // New hook should be able to collect premium
        usdc.mint(newHook, 10000e18);

        vm.startPrank(newHook);
        usdc.approve(address(insurance), 5000e18);
        insurance.collectPremiumWithToken(address(usdc), 5000e18);
        vm.stopPrank();

        assertEq(insurance.insurancePoolBalance(), 5000e18, "New hook should collect premium");
    }

    /// @notice Test configured asset count
    function testConfiguredAssetCount() public {
        assertEq(insurance.getConfiguredAssetCount(), 0, "Should start with 0 assets");

        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );
        assertEq(insurance.getConfiguredAssetCount(), 1, "Should have 1 asset");

        insurance.configureAsset(
            address(usdc), address(usdcFeed), uint256(uint256(USDC_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );
        assertEq(insurance.getConfiguredAssetCount(), 2, "Should have 2 assets");
    }

    /// @notice Test stale price detection
    function testStalePriceDetection() public {
        // Configure asset
        insurance.configureAsset(
            address(stETH), address(stETHFeed), uint256(uint256(ETH_TARGET_PRICE)), DEFAULT_DEPEG_THRESHOLD
        );

        // Warp time forward more than MAX_PRICE_AGE (2 hours)
        vm.warp(block.timestamp + 3 hours);

        // Should revert due to stale price
        vm.expectRevert("InsuranceTranche: price too old");
        insurance.checkDepeg(address(stETH));
    }
}
