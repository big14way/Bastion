// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

/// @title BastionVault
/// @notice ERC-4626 tokenized vault that wraps a multi-asset basket
/// @dev Manages deposits/withdrawals and tracks underlying basket value using oracle pricing
contract BastionVault is ERC4626 {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // -----------------------------------------------
    // Structs
    // -----------------------------------------------

    /// @notice Configuration for basket asset weights
    /// @dev Weights are in basis points (10000 = 100%)
    struct BasketAsset {
        address token;      // Token address
        uint256 weight;     // Target weight in basis points
        uint256 balance;    // Current balance held
    }

    // -----------------------------------------------
    // Constants
    // -----------------------------------------------

    /// @notice Basis points constant for percentage calculations
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Maximum number of assets in the basket
    uint256 public constant MAX_ASSETS = 10;

    /// @notice Price precision (18 decimals)
    uint256 public constant PRICE_PRECISION = 1e18;

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Array of basket assets
    BasketAsset[] public basketAssets;

    /// @notice Mapping of token address to asset index
    mapping(address => uint256) public assetIndex;

    /// @notice Whether an asset is part of the basket
    mapping(address => bool) public isBasketAsset;

    /// @notice Total weight of all assets (should equal BASIS_POINTS)
    uint256 public totalWeight;

    /// @notice Fee charged on deposits (in basis points)
    uint256 public depositFee;

    /// @notice Fee charged on withdrawals (in basis points)
    uint256 public withdrawalFee;

    /// @notice Address that receives fees
    address public feeRecipient;

    /// @notice Price oracle for asset valuation
    IPriceOracle public priceOracle;

    /// @notice Whether to use oracle pricing (false = 1:1 fallback)
    bool public useOraclePricing;

    // -----------------------------------------------
    // Ownable2Step State Variables
    // -----------------------------------------------

    /// @notice Current owner address
    address private _owner;

    /// @notice Pending owner for two-step transfer
    address private _pendingOwner;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when a basket asset is added
    event AssetAdded(address indexed token, uint256 weight);

    /// @notice Emitted when a basket asset weight is updated
    event AssetWeightUpdated(address indexed token, uint256 oldWeight, uint256 newWeight);

    /// @notice Emitted when fees are updated
    event FeesUpdated(uint256 depositFee, uint256 withdrawalFee);

    /// @notice Emitted when fee recipient is updated
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    /// @notice Emitted when basket is rebalanced
    event BasketRebalanced(uint256 timestamp);

    /// @notice Emitted when ownership transfer is started
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when price oracle is updated
    event PriceOracleUpdated(address indexed oldOracle, address indexed newOracle);

    /// @notice Emitted when oracle pricing mode is toggled
    event OraclePricingToggled(bool enabled);

    // -----------------------------------------------
    // Errors
    // -----------------------------------------------

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize the BastionVault
    /// @param _asset The base asset for deposits/withdrawals (e.g., USDC)
    /// @param _name The name of the vault token
    /// @param _symbol The symbol of the vault token
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        _owner = msg.sender;
        feeRecipient = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------
    // Ownable2Step Functions
    // -----------------------------------------------

    /// @notice Returns the current owner
    function owner() public view returns (address) {
        return _owner;
    }

    /// @notice Returns the pending owner
    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    /// @notice Starts ownership transfer to a new account
    /// @param newOwner Address of the new owner
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    /// @notice Accepts the ownership transfer
    function acceptOwnership() public {
        if (_pendingOwner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        address oldOwner = _owner;
        _owner = msg.sender;
        _pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, msg.sender);
    }

    /// @notice Renounces ownership (use with caution)
    function renounceOwnership() public onlyOwner {
        address oldOwner = _owner;
        _owner = address(0);
        _pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }

    // -----------------------------------------------
    // ERC-4626 Core Functions
    // -----------------------------------------------

    /// @notice Returns the total assets under management using oracle prices
    /// @return Total value of all basket assets in base asset terms
    function totalAssets() public view override returns (uint256) {
        uint256 total = 0;

        // Add base asset balance (deposits not yet allocated)
        total += IERC20(asset()).balanceOf(address(this));

        // Add value of all basket assets
        for (uint256 i = 0; i < basketAssets.length; i++) {
            BasketAsset storage basketAsset = basketAssets[i];
            uint256 balance = IERC20(basketAsset.token).balanceOf(address(this));

            if (balance > 0) {
                uint256 value = _getAssetValue(basketAsset.token, balance);
                total += value;
            }
        }

        return total;
    }

    /// @notice Converts assets to shares
    /// @param assets Amount of assets
    /// @return shares Amount of shares
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @notice Converts shares to assets
    /// @param shares Amount of shares
    /// @return assets Amount of assets
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @notice Preview how many shares would be minted for a deposit
    /// @param assets Amount of assets to deposit
    /// @return shares Amount of shares that would be minted
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 fee = _calculateDepositFee(assets);
        uint256 assetsAfterFee = assets - fee;
        return _convertToShares(assetsAfterFee, Math.Rounding.Floor);
    }

    /// @notice Preview how many assets are needed to mint specific shares
    /// @param shares Amount of shares to mint
    /// @return assets Amount of assets needed
    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 assets = _convertToAssets(shares, Math.Rounding.Ceil);
        // Add deposit fee
        return assets + _calculateDepositFee(assets);
    }

    /// @notice Preview how many assets would be received for a withdrawal
    /// @param assets Amount of assets to withdraw
    /// @return shares Amount of shares that would be burned
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 fee = _calculateWithdrawalFee(assets);
        uint256 assetsWithFee = assets + fee;
        return _convertToShares(assetsWithFee, Math.Rounding.Ceil);
    }

    /// @notice Preview how many assets would be received for redeeming shares
    /// @param shares Amount of shares to redeem
    /// @return assets Amount of assets that would be received
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 assets = _convertToAssets(shares, Math.Rounding.Floor);
        uint256 fee = _calculateWithdrawalFee(assets);
        return assets - fee;
    }

    /// @notice Deposit assets and receive shares
    /// @param assets Amount of assets to deposit
    /// @param receiver Address to receive shares
    /// @return shares Amount of shares minted
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets <= maxDeposit(receiver), "BastionVault: deposit exceeds max");

        // Calculate fee
        uint256 fee = _calculateDepositFee(assets);
        uint256 assetsAfterFee = assets - fee;

        // Calculate shares
        shares = previewDeposit(assets);
        require(shares > 0, "BastionVault: zero shares");

        // Transfer assets from sender
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), assets);

        // Transfer fee to recipient
        if (fee > 0 && feeRecipient != address(0)) {
            SafeERC20.safeTransfer(IERC20(asset()), feeRecipient, fee);
        }

        // Mint shares
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        // Allocate to basket if configured
        _allocateToBasket(assetsAfterFee);

        return shares;
    }

    /// @notice Withdraw assets by burning shares
    /// @param assets Amount of assets to withdraw
    /// @param receiver Address to receive assets
    /// @param shareOwner Address that owns the shares
    /// @return shares Amount of shares burned
    function withdraw(uint256 assets, address receiver, address shareOwner) public override returns (uint256 shares) {
        require(assets <= maxWithdraw(shareOwner), "BastionVault: withdraw exceeds max");

        // Calculate fee and shares needed
        uint256 fee = _calculateWithdrawalFee(assets);
        shares = previewWithdraw(assets);

        // Check allowance if not owner
        if (msg.sender != shareOwner) {
            _spendAllowance(shareOwner, msg.sender, shares);
        }

        // Burn shares
        _burn(shareOwner, shares);

        // Withdraw from basket if needed
        _withdrawFromBasket(assets + fee);

        // Transfer fee to recipient
        if (fee > 0 && feeRecipient != address(0)) {
            SafeERC20.safeTransfer(IERC20(asset()), feeRecipient, fee);
        }

        // Transfer assets to receiver
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(msg.sender, receiver, shareOwner, assets, shares);

        return shares;
    }

    // -----------------------------------------------
    // Internal Helper Functions
    // -----------------------------------------------

    /// @notice Get the value of an asset amount in base asset terms
    /// @param token Token address
    /// @param amount Amount of tokens
    /// @return value Value in base asset terms
    function _getAssetValue(address token, uint256 amount) internal view returns (uint256 value) {
        // If oracle pricing is disabled or not configured, use 1:1
        if (!useOraclePricing || address(priceOracle) == address(0)) {
            return amount;
        }

        // Check if oracle has a price feed for this token
        if (!priceOracle.hasPriceFeed(token)) {
            return amount; // Fallback to 1:1
        }

        // Get price from oracle (18 decimals)
        uint256 tokenPrice = priceOracle.getPrice(token);

        // Get base asset price
        uint256 basePrice = PRICE_PRECISION; // Default 1:1
        if (priceOracle.hasPriceFeed(asset())) {
            basePrice = priceOracle.getPrice(asset());
        }

        // Calculate value: (amount * tokenPrice) / basePrice
        // Adjust for token decimals
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        uint8 baseDecimals = IERC20Metadata(asset()).decimals();

        // Normalize to base asset decimals
        if (tokenDecimals > baseDecimals) {
            value = (amount * tokenPrice) / (basePrice * 10 ** (tokenDecimals - baseDecimals));
        } else if (tokenDecimals < baseDecimals) {
            value = (amount * tokenPrice * 10 ** (baseDecimals - tokenDecimals)) / basePrice;
        } else {
            value = (amount * tokenPrice) / basePrice;
        }
    }

    /// @notice Calculate deposit fee
    /// @param assets Amount of assets
    /// @return fee Fee amount
    function _calculateDepositFee(uint256 assets) internal view returns (uint256) {
        return (assets * depositFee) / BASIS_POINTS;
    }

    /// @notice Calculate withdrawal fee
    /// @param assets Amount of assets
    /// @return fee Fee amount
    function _calculateWithdrawalFee(uint256 assets) internal view returns (uint256) {
        return (assets * withdrawalFee) / BASIS_POINTS;
    }

    /// @notice Allocate base assets to basket according to weights
    /// @param assets Amount of assets to allocate
    function _allocateToBasket(uint256 assets) internal {
        if (basketAssets.length == 0 || totalWeight == 0) {
            return; // No basket configured
        }

        for (uint256 i = 0; i < basketAssets.length; i++) {
            BasketAsset storage basketAsset = basketAssets[i];
            uint256 allocation = (assets * basketAsset.weight) / totalWeight;

            if (allocation > 0) {
                // In production with DEX integration, this would swap base asset for basket asset
                // For now, we just track the allocation intent
                basketAsset.balance += allocation;
            }
        }
    }

    /// @notice Withdraw from basket to get base assets
    /// @param assets Amount of base assets needed
    function _withdrawFromBasket(uint256 assets) internal {
        // Check if we have enough base asset
        uint256 baseBalance = IERC20(asset()).balanceOf(address(this));

        if (baseBalance >= assets) {
            return; // Sufficient base asset available
        }

        uint256 needed = assets - baseBalance;

        // Withdraw proportionally from basket
        for (uint256 i = 0; i < basketAssets.length && needed > 0; i++) {
            BasketAsset storage basketAsset = basketAssets[i];

            if (basketAsset.balance > 0) {
                uint256 toWithdraw = (needed * basketAsset.weight) / totalWeight;
                if (toWithdraw > basketAsset.balance) {
                    toWithdraw = basketAsset.balance;
                }

                // In production with DEX integration, this would swap basket asset back to base asset
                // For now, we just track the withdrawal
                basketAsset.balance -= toWithdraw;
                needed -= toWithdraw;
            }
        }
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Set the price oracle
    /// @param _priceOracle Address of the price oracle
    function setPriceOracle(address _priceOracle) external onlyOwner {
        address oldOracle = address(priceOracle);
        priceOracle = IPriceOracle(_priceOracle);
        emit PriceOracleUpdated(oldOracle, _priceOracle);
    }

    /// @notice Toggle oracle pricing mode
    /// @param enabled Whether to use oracle pricing
    function setOraclePricing(bool enabled) external onlyOwner {
        useOraclePricing = enabled;
        emit OraclePricingToggled(enabled);
    }

    /// @notice Add a new asset to the basket
    /// @param token Token address
    /// @param weight Weight in basis points
    function addBasketAsset(address token, uint256 weight) external onlyOwner {
        require(token != address(0), "BastionVault: zero address");
        require(!isBasketAsset[token], "BastionVault: asset already exists");
        require(basketAssets.length < MAX_ASSETS, "BastionVault: max assets reached");
        require(totalWeight + weight <= BASIS_POINTS, "BastionVault: total weight exceeds 100%");

        basketAssets.push(BasketAsset({
            token: token,
            weight: weight,
            balance: 0
        }));

        assetIndex[token] = basketAssets.length - 1;
        isBasketAsset[token] = true;
        totalWeight += weight;

        emit AssetAdded(token, weight);
    }

    /// @notice Update the weight of a basket asset
    /// @param token Token address
    /// @param newWeight New weight in basis points
    function updateAssetWeight(address token, uint256 newWeight) external onlyOwner {
        require(isBasketAsset[token], "BastionVault: asset not in basket");

        uint256 index = assetIndex[token];
        uint256 oldWeight = basketAssets[index].weight;

        totalWeight = totalWeight - oldWeight + newWeight;
        require(totalWeight <= BASIS_POINTS, "BastionVault: total weight exceeds 100%");

        basketAssets[index].weight = newWeight;

        emit AssetWeightUpdated(token, oldWeight, newWeight);
    }

    /// @notice Set deposit and withdrawal fees
    /// @param _depositFee Deposit fee in basis points
    /// @param _withdrawalFee Withdrawal fee in basis points
    function setFees(uint256 _depositFee, uint256 _withdrawalFee) external onlyOwner {
        require(_depositFee <= 1000, "BastionVault: deposit fee too high"); // Max 10%
        require(_withdrawalFee <= 1000, "BastionVault: withdrawal fee too high"); // Max 10%

        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;

        emit FeesUpdated(_depositFee, _withdrawalFee);
    }

    /// @notice Set fee recipient address
    /// @param _feeRecipient New fee recipient
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "BastionVault: zero address");

        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;

        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Get the number of basket assets
    /// @return Number of assets in basket
    function getBasketAssetCount() external view returns (uint256) {
        return basketAssets.length;
    }

    /// @notice Get basket asset details
    /// @param index Asset index
    /// @return token Token address
    /// @return weight Weight in basis points
    /// @return balance Current balance
    function getBasketAsset(uint256 index) external view returns (address token, uint256 weight, uint256 balance) {
        require(index < basketAssets.length, "BastionVault: invalid index");
        BasketAsset storage basketAsset = basketAssets[index];
        return (basketAsset.token, basketAsset.weight, basketAsset.balance);
    }

    /// @notice Get the value of a specific basket asset
    /// @param token Token address
    /// @return value Current value in base asset terms
    function getAssetValue(address token) external view returns (uint256 value) {
        require(isBasketAsset[token], "BastionVault: asset not in basket");
        uint256 balance = IERC20(token).balanceOf(address(this));
        return _getAssetValue(token, balance);
    }
}
