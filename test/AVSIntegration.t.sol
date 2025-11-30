// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {InsuranceTranche} from "../src/InsuranceTranche.sol";
import {MockBastionTaskManager} from "./mocks/MockBastionTaskManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title AVSIntegration Test
/// @notice Integration tests for AVS consumer functionality in InsuranceTranche
contract AVSIntegrationTest is Test {
    // Contracts
    InsuranceTranche public insuranceTranche;
    MockBastionTaskManager public mockTaskManager;

    // Mock contracts
    IERC20 public mockToken;
    AggregatorV3Interface public mockPriceFeed;

    // Test addresses
    address public owner;
    address public authorizedHook;
    address public stETH;

    // Test data
    bytes32 public testPoolId;

    function setUp() public {
        owner = address(this);
        authorizedHook = makeAddr("authorizedHook");
        stETH = makeAddr("stETH");

        // Deploy mocks
        mockToken = IERC20(makeAddr("token"));
        mockPriceFeed = AggregatorV3Interface(makeAddr("priceFeed"));

        // Deploy MockBastionTaskManager
        mockTaskManager = new MockBastionTaskManager();

        // Deploy InsuranceTranche
        insuranceTranche = new InsuranceTranche(authorizedHook);

        // Set task manager
        insuranceTranche.setBastionTaskManager(address(mockTaskManager));

        // Test pool ID
        testPoolId = keccak256(abi.encode(makeAddr("testPool")));
    }

    // -----------------------------------------------
    // InsuranceTranche AVS Integration Tests
    // -----------------------------------------------

    /// @notice Test that MockBastionTaskManager correctly stores and retrieves volatility data
    function test_MockTaskManager_Volatility() public {
        // Arrange & Act
        mockTaskManager.setMockVolatility(testPoolId, 1200, block.timestamp, true);
        (uint256 volatility, uint256 timestamp, bool isValid) = mockTaskManager.getLatestVolatility(testPoolId);

        // Assert
        assertEq(volatility, 1200, "Volatility mismatch");
        assertEq(timestamp, block.timestamp, "Timestamp mismatch");
        assertTrue(isValid, "Should be valid");
    }

    /// @notice Test that MockBastionTaskManager correctly stores and retrieves depeg data
    function test_MockTaskManager_DepegStatus() public {
        // Arrange & Act
        mockTaskManager.setMockDepegStatus(stETH, true, 95e7, 500, block.timestamp, true);
        (bool isDepegged, uint256 price, uint256 deviation, uint256 timestamp, bool isValid) =
            mockTaskManager.getLatestDepegStatus(stETH);

        // Assert
        assertTrue(isDepegged, "Should be depegged");
        assertEq(price, 95e7, "Price mismatch");
        assertEq(deviation, 500, "Deviation mismatch");
        assertEq(timestamp, block.timestamp, "Timestamp mismatch");
        assertTrue(isValid, "Should be valid");
    }

    function test_ExecutePayout_RequiresAVSConsensus() public {
        // Arrange: Configure asset in insurance tranche
        insuranceTranche.configureAsset(stETH, address(mockPriceFeed), 1e8, 2000);

        // Add LP shares (required for payout)
        vm.store(
            address(insuranceTranche),
            bytes32(uint256(2)), // totalLPShares slot (adjust if needed)
            bytes32(uint256(100 ether))
        );

        // Set insurance pool balance by using the collect premium function
        vm.mockCall(
            address(mockToken),
            abi.encodeWithSelector(IERC20.transferFrom.selector, authorizedHook, address(insuranceTranche), 1000 ether),
            abi.encode(true)
        );
        vm.prank(authorizedHook);
        insuranceTranche.collectPremiumWithToken(address(mockToken), 1000 ether);

        // Act & Assert: Should revert without AVS consensus
        vm.expectRevert(InsuranceTranche.AVSConsensusNotReached.selector);
        insuranceTranche.executePayout(stETH);
    }

    function test_ExecutePayout_RevertWhenAVSNotSet() public {
        // Arrange: Deploy new insurance tranche without task manager
        InsuranceTranche newInsurance = new InsuranceTranche(authorizedHook);
        newInsurance.configureAsset(stETH, address(mockPriceFeed), 1e8, 2000);

        // Act & Assert: Should revert
        vm.expectRevert(InsuranceTranche.AVSTaskManagerNotSet.selector);
        newInsurance.executePayout(stETH);
    }

    function test_ExecutePayout_RevertWhenAVSDataStale() public {
        // Arrange: Configure asset
        insuranceTranche.configureAsset(stETH, address(mockPriceFeed), 1e8, 2000);

        // Warp time forward so we can subtract
        vm.warp(block.timestamp + 10 hours);

        // Set old AVS data (2 hours old)
        uint256 oldTimestamp = block.timestamp - 2 hours;
        mockTaskManager.setMockDepegStatus(stETH, true, 95e7, 500, oldTimestamp, true);

        // Act & Assert: Should revert due to stale data
        vm.expectRevert();
        insuranceTranche.executePayout(stETH);
    }

    function test_ExecutePayout_EmitsAVSConsensusEvent() public {
        // Arrange: Configure asset with target price 1e8 and threshold 2000 (20%)
        insuranceTranche.configureAsset(stETH, address(mockPriceFeed), 1e8, 2000);

        // Set recent AVS consensus data
        uint256 timestamp = block.timestamp;
        mockTaskManager.setMockDepegStatus(stETH, true, 95e7, 500, timestamp, true);

        // Mock Chainlink price feed to show depeg (79e6 = 79,000,000 which is 21% below 1e8)
        vm.mockCall(
            address(mockPriceFeed),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(1), int256(79e6), block.timestamp, block.timestamp, uint80(1))
        );

        // Add LP shares
        vm.store(
            address(insuranceTranche),
            bytes32(uint256(2)),
            bytes32(uint256(100 ether))
        );

        // Set insurance pool balance
        vm.mockCall(
            address(mockToken),
            abi.encodeWithSelector(IERC20.transferFrom.selector, authorizedHook, address(insuranceTranche), 1000 ether),
            abi.encode(true)
        );
        vm.prank(authorizedHook);
        insuranceTranche.collectPremiumWithToken(address(mockToken), 1000 ether);

        // Act & Assert: Expect AVSConsensusVerified event
        vm.expectEmit(true, false, false, true);
        emit InsuranceTranche.AVSConsensusVerified(stETH, true, timestamp);

        insuranceTranche.executePayout(stETH);
    }
}
