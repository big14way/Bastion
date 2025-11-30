// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {BastionServiceManager} from "./BastionServiceManager.sol";

/// @title BastionTaskManager
/// @notice Manages task creation and validation for Bastion AVS operators
/// @dev Implements task-based AVS archetype with three task types: DEPEG_CHECK, VOLATILITY_CALC, RATE_UPDATE
/// @custom:security-contact security@bastion.xyz
contract BastionTaskManager is OwnableUpgradeable, PausableUpgradeable {
    // -----------------------------------------------
    // Enums & Structs
    // -----------------------------------------------

    /// @notice Supported task types for Bastion AVS
    enum TaskType {
        DEPEG_CHECK,      // Check for asset depeg events
        VOLATILITY_CALC,  // Calculate pool volatility
        RATE_UPDATE       // Update interest rates based on utilization
    }

    /// @notice Status of a task
    enum TaskStatus {
        PENDING,          // Task created but not completed
        COMPLETED,        // Task completed successfully
        CHALLENGED,       // Task response challenged
        FAILED            // Task failed or timed out
    }

    /// @notice Task structure containing all task metadata
    struct Task {
        TaskType taskType;              // Type of task
        uint32 taskCreatedBlock;        // Block number when task was created
        bytes taskData;                 // Task-specific data
        uint32 quorumThresholdPercentage; // Percentage of stake needed for consensus
        bytes quorumNumbers;            // Quorum identifiers required for this task
        TaskStatus status;              // Current status of the task
    }

    /// @notice Task response submitted by an operator
    struct TaskResponse {
        uint32 referenceTaskIndex;      // Index of the task being responded to
        bytes responseData;             // Operator's response data
        bytes signature;                // Operator's signature
        address operator;               // Operator submitting response
        uint256 timestamp;              // When response was submitted
    }

    /// @notice Aggregated response for a task (after reaching quorum)
    struct AggregatedResponse {
        bytes32 responseHash;           // Hash of the aggregated response
        uint256 stakeSigned;            // Total stake that signed this response
        uint256 timestamp;              // When quorum was reached
        address[] signers;              // Operators who signed
    }

    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Reference to the Bastion Service Manager
    BastionServiceManager public serviceManager;

    /// @notice Counter for task indices
    uint32 public latestTaskNum;

    /// @notice Counter for successful task completions
    uint256 public totalTasksCompleted;

    /// @notice Task timeout period in blocks
    uint32 public taskTimeoutBlocks;

    /// @notice Minimum quorum percentage required (in basis points, 10000 = 100%)
    uint32 public minimumQuorumPercentage;

    /// @notice Mapping of task index to task hash
    mapping(uint32 => bytes32) public allTaskHashes;

    /// @notice Mapping of task index to task
    mapping(uint32 => Task) public allTasks;

    /// @notice Mapping of task index to array of responses
    mapping(uint32 => TaskResponse[]) public taskResponses;

    /// @notice Mapping of task index to aggregated response
    mapping(uint32 => AggregatedResponse) public aggregatedResponses;

    /// @notice Mapping to track if an operator has responded to a task
    mapping(uint32 => mapping(address => bool)) public hasOperatorResponded;

    /// @notice Mapping of pool ID to latest VOLATILITY_CALC task index
    mapping(bytes32 => uint32) public latestVolatilityTaskIndex;

    /// @notice Mapping of asset address to latest DEPEG_CHECK task index
    mapping(address => uint32) public latestDepegCheckTaskIndex;

    /// @notice Mapping of lending module address to latest RATE_UPDATE task index
    mapping(address => uint32) public latestRateUpdateTaskIndex;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when a new task is created
    /// @param taskIndex Index of the created task
    /// @param task The task struct
    event NewTaskCreated(uint32 indexed taskIndex, Task task);

    /// @notice Emitted when an operator responds to a task
    /// @param taskIndex Index of the task
    /// @param operator Address of the responding operator
    /// @param response The task response
    event TaskResponseSubmitted(uint32 indexed taskIndex, address indexed operator, TaskResponse response);

    /// @notice Emitted when a task reaches quorum and is completed
    /// @param taskIndex Index of the task
    /// @param responseHash Hash of the agreed-upon response
    event TaskCompleted(uint32 indexed taskIndex, bytes32 responseHash);

    /// @notice Emitted when a task is challenged
    /// @param taskIndex Index of the task
    /// @param challenger Address of the challenger
    /// @param reason Reason for challenge
    event TaskChallenged(uint32 indexed taskIndex, address indexed challenger, string reason);

    /// @notice Emitted when a task times out
    /// @param taskIndex Index of the task
    event TaskTimedOut(uint32 indexed taskIndex);

    /// @notice Emitted when task timeout is updated
    /// @param oldTimeout Previous timeout in blocks
    /// @param newTimeout New timeout in blocks
    event TaskTimeoutUpdated(uint32 oldTimeout, uint32 newTimeout);

    // -----------------------------------------------
    // Errors
    // -----------------------------------------------

    error TaskNotFound(uint32 taskIndex);
    error TaskAlreadyCompleted(uint32 taskIndex);
    error OperatorAlreadyResponded(uint32 taskIndex, address operator);
    error OperatorNotRegistered(address operator);
    error InvalidTaskData();
    error InvalidQuorumPercentage(uint32 provided);
    error TaskTimeout(uint32 taskIndex);
    error InsufficientStake(address operator);
    error InvalidSignature();

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    /// @notice Restricts function to registered operators with sufficient stake
    modifier onlyRegisteredOperator() {
        if (!serviceManager.isOperatorRegistered(msg.sender)) {
            revert OperatorNotRegistered(msg.sender);
        }
        if (!serviceManager.hasMinimumStake(msg.sender)) {
            revert InsufficientStake(msg.sender);
        }
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

    /// @notice Initializes the BastionTaskManager
    /// @param _serviceManager Address of the Bastion Service Manager
    /// @param _taskTimeoutBlocks Number of blocks before a task times out
    /// @param _minimumQuorumPercentage Minimum quorum percentage (in basis points)
    /// @param _owner Address of the contract owner
    function initialize(
        address _serviceManager,
        uint32 _taskTimeoutBlocks,
        uint32 _minimumQuorumPercentage,
        address _owner
    ) external initializer {
        require(_serviceManager != address(0) && _owner != address(0), "Invalid address");
        require(_minimumQuorumPercentage <= 10000, "Invalid quorum percentage");

        __Ownable_init();
        __Pausable_init();

        if (_owner != msg.sender) {
            transferOwnership(_owner);
        }

        serviceManager = BastionServiceManager(_serviceManager);
        taskTimeoutBlocks = _taskTimeoutBlocks;
        minimumQuorumPercentage = _minimumQuorumPercentage;
    }

    // -----------------------------------------------
    // Task Creation Functions
    // -----------------------------------------------

    /// @notice Creates a new depeg check task
    /// @param assetAddress Address of the asset to check for depeg
    /// @param quorumThresholdPercentage Percentage of stake required for consensus
    /// @param quorumNumbers Quorum identifiers
    /// @return taskIndex Index of the created task
    function createDepegCheckTask(
        address assetAddress,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external onlyOwner whenNotPaused returns (uint32 taskIndex) {
        bytes memory taskData = abi.encode(assetAddress, block.timestamp);
        return _createTask(TaskType.DEPEG_CHECK, taskData, quorumThresholdPercentage, quorumNumbers);
    }

    /// @notice Creates a new volatility calculation task
    /// @param poolAddress Address of the pool to calculate volatility for
    /// @param timeWindow Time window for volatility calculation (in seconds)
    /// @param quorumThresholdPercentage Percentage of stake required for consensus
    /// @param quorumNumbers Quorum identifiers
    /// @return taskIndex Index of the created task
    function createVolatilityCalcTask(
        address poolAddress,
        uint256 timeWindow,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external onlyOwner whenNotPaused returns (uint32 taskIndex) {
        bytes memory taskData = abi.encode(poolAddress, timeWindow, block.timestamp);
        return _createTask(TaskType.VOLATILITY_CALC, taskData, quorumThresholdPercentage, quorumNumbers);
    }

    /// @notice Creates a new interest rate update task
    /// @param lendingModuleAddress Address of the lending module to update rates for
    /// @param utilization Current utilization rate (in basis points)
    /// @param quorumThresholdPercentage Percentage of stake required for consensus
    /// @param quorumNumbers Quorum identifiers
    /// @return taskIndex Index of the created task
    function createRateUpdateTask(
        address lendingModuleAddress,
        uint256 utilization,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external onlyOwner whenNotPaused returns (uint32 taskIndex) {
        bytes memory taskData = abi.encode(lendingModuleAddress, utilization, block.timestamp);
        return _createTask(TaskType.RATE_UPDATE, taskData, quorumThresholdPercentage, quorumNumbers);
    }

    /// @notice Internal function to create a task
    /// @param taskType Type of task to create
    /// @param taskData Task-specific data
    /// @param quorumThresholdPercentage Percentage of stake required
    /// @param quorumNumbers Quorum identifiers
    /// @return taskIndex Index of the created task
    function _createTask(
        TaskType taskType,
        bytes memory taskData,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) internal returns (uint32 taskIndex) {
        if (quorumThresholdPercentage < minimumQuorumPercentage || quorumThresholdPercentage > 10000) {
            revert InvalidQuorumPercentage(quorumThresholdPercentage);
        }
        if (taskData.length == 0) revert InvalidTaskData();

        // Create new task
        Task memory newTask = Task({
            taskType: taskType,
            taskCreatedBlock: uint32(block.number),
            taskData: taskData,
            quorumThresholdPercentage: quorumThresholdPercentage,
            quorumNumbers: quorumNumbers,
            status: TaskStatus.PENDING
        });

        // Store task
        taskIndex = latestTaskNum;
        allTaskHashes[taskIndex] = keccak256(abi.encode(newTask));
        allTasks[taskIndex] = newTask;

        emit NewTaskCreated(taskIndex, newTask);

        latestTaskNum++;

        return taskIndex;
    }

    // -----------------------------------------------
    // Task Response Functions
    // -----------------------------------------------

    /// @notice Operators respond to a task with their computed result
    /// @param referenceTaskIndex Index of the task to respond to
    /// @param responseData Operator's computed response
    /// @param signature Operator's signature over the response
    function respondToTask(uint32 referenceTaskIndex, bytes calldata responseData, bytes calldata signature)
        external
        onlyRegisteredOperator
        whenNotPaused
    {
        Task storage task = allTasks[referenceTaskIndex];

        // Validation checks
        if (task.taskCreatedBlock == 0) revert TaskNotFound(referenceTaskIndex);
        if (task.status != TaskStatus.PENDING) revert TaskAlreadyCompleted(referenceTaskIndex);
        if (hasOperatorResponded[referenceTaskIndex][msg.sender]) {
            revert OperatorAlreadyResponded(referenceTaskIndex, msg.sender);
        }
        if (block.number > task.taskCreatedBlock + taskTimeoutBlocks) {
            _markTaskAsTimedOut(referenceTaskIndex);
            revert TaskTimeout(referenceTaskIndex);
        }

        // Verify signature
        bytes32 messageHash = keccak256(abi.encodePacked(referenceTaskIndex, responseData));
        if (!_verifySignature(messageHash, signature, msg.sender)) {
            revert InvalidSignature();
        }

        // Create response
        TaskResponse memory response = TaskResponse({
            referenceTaskIndex: referenceTaskIndex,
            responseData: responseData,
            signature: signature,
            operator: msg.sender,
            timestamp: block.timestamp
        });

        // Store response
        taskResponses[referenceTaskIndex].push(response);
        hasOperatorResponded[referenceTaskIndex][msg.sender] = true;

        emit TaskResponseSubmitted(referenceTaskIndex, msg.sender, response);

        // Check if quorum reached
        _checkAndAggregateResponses(referenceTaskIndex);
    }

    /// @notice Checks if responses have reached quorum and aggregates if so
    /// @param taskIndex Index of the task
    function _checkAndAggregateResponses(uint32 taskIndex) internal {
        Task storage task = allTasks[taskIndex];
        TaskResponse[] storage responses = taskResponses[taskIndex];

        if (responses.length == 0) return;

        uint256 totalStake = _getTotalStake();
        uint256 requiredStake = (totalStake * task.quorumThresholdPercentage) / 10000;

        // Track unique response hashes and their stakes
        bytes32[] memory uniqueHashes = new bytes32[](responses.length);
        uint256[] memory stakes = new uint256[](responses.length);
        address[][] memory signers = new address[][](responses.length);
        uint256 uniqueCount = 0;

        // Aggregate stakes for each unique response
        for (uint256 i = 0; i < responses.length; i++) {
            bytes32 responseHash = keccak256(responses[i].responseData);
            uint256 operatorStake = serviceManager.getOperatorStake(responses[i].operator);

            // Find if this hash already exists
            bool found = false;
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (uniqueHashes[j] == responseHash) {
                    stakes[j] += operatorStake;
                    // Resize signers array and add new signer
                    address[] memory oldSigners = signers[j];
                    signers[j] = new address[](oldSigners.length + 1);
                    for (uint256 k = 0; k < oldSigners.length; k++) {
                        signers[j][k] = oldSigners[k];
                    }
                    signers[j][oldSigners.length] = responses[i].operator;
                    found = true;
                    break;
                }
            }

            if (!found) {
                uniqueHashes[uniqueCount] = responseHash;
                stakes[uniqueCount] = operatorStake;
                signers[uniqueCount] = new address[](1);
                signers[uniqueCount][0] = responses[i].operator;
                uniqueCount++;
            }
        }

        // Find winning response (highest stake)
        bytes32 winningResponseHash;
        uint256 maxStake = 0;
        uint256 winningIndex = 0;

        for (uint256 i = 0; i < uniqueCount; i++) {
            if (stakes[i] > maxStake) {
                maxStake = stakes[i];
                winningResponseHash = uniqueHashes[i];
                winningIndex = i;
            }
        }

        // Check if quorum reached
        if (maxStake >= requiredStake) {
            // Create aggregated response
            aggregatedResponses[taskIndex] = AggregatedResponse({
                responseHash: winningResponseHash,
                stakeSigned: maxStake,
                timestamp: block.timestamp,
                signers: signers[winningIndex]
            });

            // Mark task as completed
            task.status = TaskStatus.COMPLETED;
            totalTasksCompleted++;

            // Update latest task index for consumer contracts to read
            _updateLatestTaskIndex(task.taskType, taskIndex, task.taskData);

            emit TaskCompleted(taskIndex, winningResponseHash);
        }
    }

    // -----------------------------------------------
    // Challenge Functions
    // -----------------------------------------------

    /// @notice Allows challenging a task response
    /// @param taskIndex Index of the task to challenge
    /// @param reason Reason for the challenge
    function challengeTask(uint32 taskIndex, string calldata reason)
        external
        onlyRegisteredOperator
        whenNotPaused
    {
        Task storage task = allTasks[taskIndex];

        if (task.status != TaskStatus.COMPLETED) revert TaskNotFound(taskIndex);

        // Mark task as challenged
        task.status = TaskStatus.CHALLENGED;

        emit TaskChallenged(taskIndex, msg.sender, reason);

        // TODO: Implement challenge resolution logic and potential slashing
    }

    // -----------------------------------------------
    // View Functions
    // -----------------------------------------------

    /// @notice Gets a task by index
    /// @param taskIndex Index of the task
    /// @return task The task struct
    function getTask(uint32 taskIndex) external view returns (Task memory task) {
        return allTasks[taskIndex];
    }

    /// @notice Gets all responses for a task
    /// @param taskIndex Index of the task
    /// @return responses Array of task responses
    function getTaskResponses(uint32 taskIndex) external view returns (TaskResponse[] memory responses) {
        return taskResponses[taskIndex];
    }

    /// @notice Gets the aggregated response for a task
    /// @param taskIndex Index of the task
    /// @return response The aggregated response
    function getAggregatedResponse(uint32 taskIndex) external view returns (AggregatedResponse memory response) {
        return aggregatedResponses[taskIndex];
    }

    /// @notice Checks if a task has timed out
    /// @param taskIndex Index of the task
    /// @return isTimedOut True if task has timed out
    function isTaskTimedOut(uint32 taskIndex) external view returns (bool isTimedOut) {
        Task storage task = allTasks[taskIndex];
        return block.number > task.taskCreatedBlock + taskTimeoutBlocks;
    }

    /// @notice Gets the total number of tasks created
    /// @return count Total task count
    function getTotalTasks() external view returns (uint32 count) {
        return latestTaskNum;
    }

    // -----------------------------------------------
    // Admin Functions
    // -----------------------------------------------

    /// @notice Updates the task timeout period
    /// @param _taskTimeoutBlocks New timeout in blocks
    function setTaskTimeout(uint32 _taskTimeoutBlocks) external onlyOwner {
        uint32 oldTimeout = taskTimeoutBlocks;
        taskTimeoutBlocks = _taskTimeoutBlocks;

        emit TaskTimeoutUpdated(oldTimeout, _taskTimeoutBlocks);
    }

    /// @notice Updates the minimum quorum percentage
    /// @param _minimumQuorumPercentage New minimum quorum (in basis points)
    function setMinimumQuorumPercentage(uint32 _minimumQuorumPercentage) external onlyOwner {
        require(_minimumQuorumPercentage <= 10000, "Invalid quorum percentage");
        minimumQuorumPercentage = _minimumQuorumPercentage;
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

    /// @notice Marks a task as timed out
    /// @param taskIndex Index of the task
    function _markTaskAsTimedOut(uint32 taskIndex) internal {
        Task storage task = allTasks[taskIndex];
        task.status = TaskStatus.FAILED;

        emit TaskTimedOut(taskIndex);
    }

    /// @notice Verifies an operator's signature
    /// @param messageHash Hash of the message
    /// @param signature Signature to verify
    /// @param operator Address of the operator
    /// @return isValid True if signature is valid
    function _verifySignature(bytes32 messageHash, bytes memory signature, address operator)
        internal
        pure
        returns (bool isValid)
    {
        // Create Ethereum Signed Message hash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Recover signer from signature
        address recoveredSigner = _recoverSigner(ethSignedMessageHash, signature);

        return recoveredSigner == operator;
    }

    /// @notice Recovers the signer address from a signature
    /// @param ethSignedMessageHash Ethereum signed message hash
    /// @param signature The signature
    /// @return signer The recovered signer address
    function _recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature)
        internal
        pure
        returns (address signer)
    {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    /// @notice Gets the total stake of all registered operators
    /// @return totalStake Total stake amount
    function _getTotalStake() internal view returns (uint256 totalStake) {
        address[] memory operators = serviceManager.getRegisteredOperators();
        for (uint256 i = 0; i < operators.length; i++) {
            totalStake += serviceManager.getOperatorStake(operators[i]);
        }
        return totalStake;
    }

    /// @notice Updates the latest task index mapping for a given task type
    /// @param taskType The type of task
    /// @param taskIndex The task index
    /// @param taskData The task data to decode identifiers from
    function _updateLatestTaskIndex(TaskType taskType, uint32 taskIndex, bytes memory taskData) internal {
        if (taskType == TaskType.DEPEG_CHECK) {
            (address assetAddress,) = abi.decode(taskData, (address, uint256));
            latestDepegCheckTaskIndex[assetAddress] = taskIndex;
        } else if (taskType == TaskType.VOLATILITY_CALC) {
            (address poolAddress,,) = abi.decode(taskData, (address, uint256, uint256));
            bytes32 poolId = keccak256(abi.encode(poolAddress)); // Simple pool ID derivation
            latestVolatilityTaskIndex[poolId] = taskIndex;
        } else if (taskType == TaskType.RATE_UPDATE) {
            (address lendingModuleAddress,,) = abi.decode(taskData, (address, uint256, uint256));
            latestRateUpdateTaskIndex[lendingModuleAddress] = taskIndex;
        }
    }

    // -----------------------------------------------
    // Consumer View Functions (for IAVSConsumer)
    // -----------------------------------------------

    /// @notice Gets the latest validated volatility for a pool
    /// @param poolId The pool identifier
    /// @return volatility Volatility in basis points
    /// @return timestamp When the data was validated
    /// @return isValid Whether consensus was reached
    function getLatestVolatility(bytes32 poolId)
        external
        view
        returns (uint256 volatility, uint256 timestamp, bool isValid)
    {
        uint32 taskIndex = latestVolatilityTaskIndex[poolId];
        if (taskIndex == 0) return (0, 0, false);

        Task storage task = allTasks[taskIndex];
        if (task.status != TaskStatus.COMPLETED) return (0, 0, false);

        AggregatedResponse storage response = aggregatedResponses[taskIndex];
        if (response.timestamp == 0) return (0, 0, false);

        // Find the actual response data from one of the signers
        TaskResponse[] storage responses = taskResponses[taskIndex];
        if (responses.length == 0) return (0, 0, false);

        // Decode the response data: (uint256 volatility, uint256 timestamp)
        (volatility, timestamp) = abi.decode(responses[0].responseData, (uint256, uint256));
        isValid = true;
    }

    /// @notice Gets the latest validated depeg status for an asset
    /// @param assetAddress The asset address
    /// @return isDepegged Whether the asset is depegged
    /// @return currentPrice Current price ratio (18 decimals)
    /// @return deviation Deviation from peg in basis points
    /// @return timestamp When the data was validated
    /// @return isValid Whether consensus was reached
    function getLatestDepegStatus(address assetAddress)
        external
        view
        returns (
            bool isDepegged,
            uint256 currentPrice,
            uint256 deviation,
            uint256 timestamp,
            bool isValid
        )
    {
        uint32 taskIndex = latestDepegCheckTaskIndex[assetAddress];
        if (taskIndex == 0) return (false, 0, 0, 0, false);

        Task storage task = allTasks[taskIndex];
        if (task.status != TaskStatus.COMPLETED) return (false, 0, 0, 0, false);

        AggregatedResponse storage response = aggregatedResponses[taskIndex];
        if (response.timestamp == 0) return (false, 0, 0, 0, false);

        TaskResponse[] storage responses = taskResponses[taskIndex];
        if (responses.length == 0) return (false, 0, 0, 0, false);

        // Decode the response data: (bool isDepegged, uint256 currentPrice, uint256 deviation)
        (isDepegged, currentPrice, deviation) = abi.decode(
            responses[0].responseData,
            (bool, uint256, uint256)
        );
        timestamp = response.timestamp;
        isValid = true;
    }

    /// @notice Gets the latest validated interest rate for a lending module
    /// @param lendingModuleAddress The lending module address
    /// @return newRate Interest rate in basis points
    /// @return timestamp When the data was validated
    /// @return isValid Whether consensus was reached
    function getLatestInterestRate(address lendingModuleAddress)
        external
        view
        returns (uint256 newRate, uint256 timestamp, bool isValid)
    {
        uint32 taskIndex = latestRateUpdateTaskIndex[lendingModuleAddress];
        if (taskIndex == 0) return (0, 0, false);

        Task storage task = allTasks[taskIndex];
        if (task.status != TaskStatus.COMPLETED) return (0, 0, false);

        AggregatedResponse storage response = aggregatedResponses[taskIndex];
        if (response.timestamp == 0) return (0, 0, false);

        TaskResponse[] storage responses = taskResponses[taskIndex];
        if (responses.length == 0) return (0, 0, false);

        // Decode the response data: (uint256 newRate, uint256 timestamp)
        (newRate, timestamp) = abi.decode(responses[0].responseData, (uint256, uint256));
        isValid = true;
    }
}
