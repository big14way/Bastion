import { ethers } from 'ethers';
import { logger } from './logger';
import { TaskHandler } from './taskHandler';
import { SignatureService } from './signatureService';

export interface OperatorConfig {
  provider: ethers.WebSocketProvider;
  wallet: ethers.Wallet;
  taskManagerAddress: string;
  serviceManagerAddress: string;
  chainlinkPriceFeedETHUSD: string;
  chainlinkPriceFeedSTETH: string;
}

export class BastionOperator {
  private provider: ethers.WebSocketProvider;
  private wallet: ethers.Wallet;
  private taskManager: ethers.Contract;
  private serviceManager: ethers.Contract;
  private taskHandler: TaskHandler;
  private signatureService: SignatureService;
  private isRunning: boolean = false;

  // Task Manager ABI (simplified - only events and functions we need)
  private static readonly TASK_MANAGER_ABI = [
    'event NewTaskCreated(uint32 indexed taskIndex, uint8 taskType, bytes taskData, uint32 quorumThresholdPercentage, bytes quorumNumbers)',
    'event TaskResponseSubmitted(uint32 indexed taskIndex, address indexed operator, tuple(uint32 referenceTaskIndex, bytes responseData, bytes signature, address operator, uint256 timestamp) response)',
    'event TaskCompleted(uint32 indexed taskIndex, bytes32 responseHash)',
    'function respondToTask(uint32 referenceTaskIndex, bytes calldata responseData, bytes calldata signature) external',
    'function getTask(uint32 taskIndex) external view returns (tuple(uint8 taskType, bytes taskData, uint32 taskCreatedBlock, uint32 quorumThresholdPercentage, bytes quorumNumbers, uint8 status))',
  ];

  private static readonly SERVICE_MANAGER_ABI = [
    'function isOperatorRegistered(address operator) external view returns (bool)',
    'function getOperatorStake(address operator) external view returns (uint256)',
  ];

  constructor(config: OperatorConfig) {
    this.provider = config.provider;
    this.wallet = config.wallet;

    // Initialize contracts
    this.taskManager = new ethers.Contract(
      config.taskManagerAddress,
      BastionOperator.TASK_MANAGER_ABI,
      this.wallet
    );

    this.serviceManager = new ethers.Contract(
      config.serviceManagerAddress,
      BastionOperator.SERVICE_MANAGER_ABI,
      this.wallet
    );

    // Initialize task handler
    this.taskHandler = new TaskHandler({
      provider: this.provider,
      chainlinkPriceFeedETHUSD: config.chainlinkPriceFeedETHUSD,
      chainlinkPriceFeedSTETH: config.chainlinkPriceFeedSTETH,
    });

    // Initialize signature service
    this.signatureService = new SignatureService(this.wallet);
  }

  async start(): Promise<void> {
    logger.info('Starting Bastion AVS Operator...');

    // Check if operator is registered
    const isRegistered = await this.serviceManager.isOperatorRegistered(this.wallet.address);
    if (!isRegistered) {
      logger.error('Operator is not registered with the AVS. Please register first.');
      throw new Error('Operator not registered');
    }

    const stake = await this.serviceManager.getOperatorStake(this.wallet.address);
    logger.info(`Operator registered with stake: ${ethers.formatEther(stake)} ETH`);

    // Start listening for events
    this.isRunning = true;
    await this.subscribeToTasks();

    logger.info('Operator is now listening for tasks...');
  }

  async stop(): Promise<void> {
    logger.info('Stopping operator...');
    this.isRunning = false;

    // Remove all listeners
    await this.taskManager.removeAllListeners();
    await this.provider.destroy();

    logger.info('Operator stopped');
  }

  private async subscribeToTasks(): Promise<void> {
    // Listen for NewTaskCreated events
    this.taskManager.on(
      'NewTaskCreated',
      async (
        taskIndex: bigint,
        taskType: bigint,
        taskData: string,
        quorumThresholdPercentage: bigint,
        quorumNumbers: string,
        event: ethers.EventLog
      ) => {
        try {
          logger.info(`New task created: #${taskIndex}, type: ${taskType}`);

          // Process task
          await this.processTask(
            Number(taskIndex),
            Number(taskType),
            taskData,
            Number(quorumThresholdPercentage),
            quorumNumbers
          );
        } catch (error) {
          logger.error(`Error processing task #${taskIndex}:`, error);
        }
      }
    );

    // Handle connection errors and reconnection
    this.provider.on('error', (error) => {
      logger.error('WebSocket error:', error);
    });

    this.provider.on('disconnect', () => {
      logger.warn('WebSocket disconnected, attempting to reconnect...');
    });
  }

  private async processTask(
    taskIndex: number,
    taskType: number,
    taskData: string,
    quorumThresholdPercentage: number,
    quorumNumbers: string
  ): Promise<void> {
    logger.info(`Processing task #${taskIndex}, type: ${this.getTaskTypeName(taskType)}`);

    try {
      // Handle task based on type
      let responseData: string;

      switch (taskType) {
        case 0: // DEPEG_CHECK
          responseData = await this.taskHandler.handleDepegCheck(taskData);
          break;
        case 1: // VOLATILITY_CALC
          responseData = await this.taskHandler.handleVolatilityCalc(taskData);
          break;
        case 2: // RATE_UPDATE
          responseData = await this.taskHandler.handleRateUpdate(taskData);
          break;
        default:
          logger.error(`Unknown task type: ${taskType}`);
          return;
      }

      // Sign the response
      const signature = await this.signatureService.signTaskResponse(taskIndex, responseData);

      // Submit response to task manager
      await this.submitTaskResponse(taskIndex, responseData, signature);

      logger.info(`Successfully submitted response for task #${taskIndex}`);
    } catch (error) {
      logger.error(`Failed to process task #${taskIndex}:`, error);
      throw error;
    }
  }

  private async submitTaskResponse(
    taskIndex: number,
    responseData: string,
    signature: string
  ): Promise<void> {
    try {
      const tx = await this.taskManager.respondToTask(taskIndex, responseData, signature);
      logger.info(`Submitted task response transaction: ${tx.hash}`);

      const receipt = await tx.wait();
      logger.info(`Task response confirmed in block ${receipt.blockNumber}`);
    } catch (error) {
      logger.error(`Failed to submit task response:`, error);
      throw error;
    }
  }

  private getTaskTypeName(taskType: number): string {
    const types = ['DEPEG_CHECK', 'VOLATILITY_CALC', 'RATE_UPDATE'];
    return types[taskType] || 'UNKNOWN';
  }
}
