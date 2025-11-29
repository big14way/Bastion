// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title BastionServiceManager
/// @notice Service manager for Bastion AVS - manages operator registration and slashing logic
/// @dev Extends EigenLayer ServiceManager pattern with Bastion-specific functionality
/// @custom:security-contact security@bastion.xyz
contract BastionServiceManager is OwnableUpgradeable, PausableUpgradeable {
    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Address of the BastionTaskManager contract
    address public taskManager;

    /// @notice Address of the EigenLayer AVS Directory
    address public avsDirectory;

    /// @notice Minimum stake required for operators (in wei)
    uint256 public minimumStake;

    /// @notice Mapping of operator addresses to their registration status
    mapping(address => bool) public isOperatorRegistered;

    /// @notice Mapping of operator addresses to their stake amounts
    mapping(address => uint256) public operatorStakes;

    /// @notice Array of all registered operator addresses
    address[] public registeredOperators;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when an operator registers with the AVS
    /// @param operator Address of the registered operator
    /// @param stake Amount of stake provided by the operator
    event OperatorRegistered(address indexed operator, uint256 stake);

    /// @notice Emitted when an operator deregisters from the AVS
    /// @param operator Address of the deregistered operator
    event OperatorDeregistered(address indexed operator);

    /// @notice Emitted when an operator is slashed
    /// @param operator Address of the slashed operator
    /// @param amount Amount slashed
    /// @param reason Reason for slashing
    event OperatorSlashed(address indexed operator, uint256 amount, string reason);

    /// @notice Emitted when minimum stake is updated
    /// @param oldStake Previous minimum stake
    /// @param newStake New minimum stake
    event MinimumStakeUpdated(uint256 oldStake, uint256 newStake);

    /// @notice Emitted when task manager is updated
    /// @param oldTaskManager Previous task manager address
    /// @param newTaskManager New task manager address
    event TaskManagerUpdated(address indexed oldTaskManager, address indexed newTaskManager);

    // -----------------------------------------------
    // Errors
    // -----------------------------------------------

    error InsufficientStake(uint256 provided, uint256 required);
    error OperatorAlreadyRegistered(address operator);
    error OperatorNotRegistered(address operator);
    error InvalidAddress();
    error UnauthorizedCaller();

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    /// @notice Restricts function access to the task manager
    modifier onlyTaskManager() {
        if (msg.sender != taskManager) revert UnauthorizedCaller();
        _;
    }

    /// @notice Restricts function access to registered operators
    modifier onlyRegisteredOperator() {
        if (!isOperatorRegistered[msg.sender]) revert OperatorNotRegistered(msg.sender);
        _;
    }

    // -----------------------------------------------
    // Constructor & Initialization
    // -----------------------------------------------

    /// @notice Constructor - disables initializers for the implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the BastionServiceManager
    /// @param _avsDirectory Address of the EigenLayer AVS Directory
    /// @param _minimumStake Minimum stake required for operators
    /// @param _owner Address of the contract owner
    function initialize(address _avsDirectory, uint256 _minimumStake, address _owner) external initializer {
        if (_avsDirectory == address(0) || _owner == address(0)) revert InvalidAddress();

        __Ownable_init();
        __Pausable_init();

        if (_owner != msg.sender) {
            transferOwnership(_owner);
        }

        avsDirectory = _avsDirectory;
        minimumStake = _minimumStake;
    }

    // -----------------------------------------------
    // Operator Management Functions
    // -----------------------------------------------

    /// @notice Registers an operator with the Bastion AVS
    /// @dev Operator must provide sufficient stake
    /// @param stake Amount of stake to register with
    function registerOperator(uint256 stake) external whenNotPaused {
        if (isOperatorRegistered[msg.sender]) revert OperatorAlreadyRegistered(msg.sender);
        if (stake < minimumStake) revert InsufficientStake(stake, minimumStake);

        // Register operator
        isOperatorRegistered[msg.sender] = true;
        operatorStakes[msg.sender] = stake;
        registeredOperators.push(msg.sender);

        emit OperatorRegistered(msg.sender, stake);
    }

    /// @notice Deregisters an operator from the Bastion AVS
    /// @dev Operator must be currently registered
    function deregisterOperator() external onlyRegisteredOperator {
        // Mark as deregistered
        isOperatorRegistered[msg.sender] = false;
        uint256 stake = operatorStakes[msg.sender];
        operatorStakes[msg.sender] = 0;

        // Remove from registered operators array
        _removeOperatorFromArray(msg.sender);

        emit OperatorDeregistered(msg.sender);

        // TODO: Return stake to operator (implement stake withdrawal logic)
    }

    /// @notice Updates an operator's stake
    /// @param additionalStake Additional stake to add
    function updateOperatorStake(uint256 additionalStake) external onlyRegisteredOperator whenNotPaused {
        operatorStakes[msg.sender] += additionalStake;
    }

    // -----------------------------------------------
    // Slashing Functions
    // -----------------------------------------------

    /// @notice Slashes an operator for malicious behavior
    /// @dev Can only be called by the task manager
    /// @param operator Address of the operator to slash
    /// @param amount Amount to slash
    /// @param reason Reason for slashing
    function slashOperator(address operator, uint256 amount, string calldata reason)
        external
        onlyTaskManager
        whenNotPaused
    {
        if (!isOperatorRegistered[operator]) revert OperatorNotRegistered(operator);

        uint256 currentStake = operatorStakes[operator];
        uint256 slashAmount = amount > currentStake ? currentStake : amount;

        operatorStakes[operator] -= slashAmount;

        // If stake falls below minimum, deregister operator
        if (operatorStakes[operator] < minimumStake) {
            isOperatorRegistered[operator] = false;
            _removeOperatorFromArray(operator);
            emit OperatorDeregistered(operator);
        }

        emit OperatorSlashed(operator, slashAmount, reason);

        // TODO: Implement actual slashing logic with EigenLayer core contracts
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Returns the total number of registered operators
    /// @return count Number of registered operators
    function getRegisteredOperatorCount() external view returns (uint256 count) {
        return registeredOperators.length;
    }

    /// @notice Returns all registered operator addresses
    /// @return operators Array of registered operator addresses
    function getRegisteredOperators() external view returns (address[] memory operators) {
        return registeredOperators;
    }

    /// @notice Checks if an operator has sufficient stake
    /// @param operator Address of the operator to check
    /// @return hasSufficientStake True if operator has sufficient stake
    function hasMinimumStake(address operator) external view returns (bool hasSufficientStake) {
        return operatorStakes[operator] >= minimumStake;
    }

    /// @notice Returns an operator's current stake
    /// @param operator Address of the operator
    /// @return stake Current stake amount
    function getOperatorStake(address operator) external view returns (uint256 stake) {
        return operatorStakes[operator];
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Sets the task manager address
    /// @param _taskManager Address of the new task manager
    function setTaskManager(address _taskManager) external onlyOwner {
        if (_taskManager == address(0)) revert InvalidAddress();

        address oldTaskManager = taskManager;
        taskManager = _taskManager;

        emit TaskManagerUpdated(oldTaskManager, _taskManager);
    }

    /// @notice Updates the minimum stake requirement
    /// @param _minimumStake New minimum stake amount
    function setMinimumStake(uint256 _minimumStake) external onlyOwner {
        uint256 oldStake = minimumStake;
        minimumStake = _minimumStake;

        emit MinimumStakeUpdated(oldStake, _minimumStake);
    }

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    // -----------------------------------------------
    // Internal Helper Functions
    // -----------------------------------------------

    /// @notice Removes an operator from the registered operators array
    /// @param operator Address of the operator to remove
    function _removeOperatorFromArray(address operator) internal {
        uint256 length = registeredOperators.length;
        for (uint256 i = 0; i < length; i++) {
            if (registeredOperators[i] == operator) {
                // Move last element to this position and pop
                registeredOperators[i] = registeredOperators[length - 1];
                registeredOperators.pop();
                break;
            }
        }
    }
}
