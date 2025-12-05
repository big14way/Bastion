import { ethers } from 'ethers';
import express from 'express';
import { Client as PgClient } from 'pg';
import { createClient } from 'redis';
import { Registry, Counter, Gauge, Histogram } from 'prom-client';
import winston from 'winston';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

dotenv.config();

// Logger setup
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'operator.log' })
  ]
});

// Prometheus metrics
const register = new Registry();
const tasksReceived = new Counter({
  name: 'bastion_tasks_received_total',
  help: 'Total number of tasks received',
  registers: [register]
});
const tasksProcessed = new Counter({
  name: 'bastion_tasks_processed_total',
  help: 'Total number of tasks processed',
  labelNames: ['status'],
  registers: [register]
});
const taskProcessingTime = new Histogram({
  name: 'bastion_task_processing_seconds',
  help: 'Task processing time in seconds',
  registers: [register]
});
const operatorBalance = new Gauge({
  name: 'bastion_operator_balance_eth',
  help: 'Operator balance in ETH',
  registers: [register]
});

// ABIs
const TASK_MANAGER_ABI = [
  'event NewTaskCreated(uint32 indexed taskIndex, uint8 taskType, bytes taskData)',
  'function respondToTask(uint32 taskIndex, bytes calldata response, bytes calldata signature) external',
  'function taskNumber() external view returns (uint32)',
  'function allTaskResponses(uint32) external view returns (bytes32)'
];

const SERVICE_MANAGER_ABI = [
  'function owner() external view returns (address)',
  'function taskManager() external view returns (address)'
];

interface BLSKey {
  PrivateKey: string;
  PublicKey: string;
  G1PubKey: string;
  G2PubKey: string;
}

interface TaskData {
  taskIndex: number;
  taskType: number;
  taskData: string;
  blockNumber: number;
}

class BastionOperator {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private taskManager: ethers.Contract;
  private serviceManager: ethers.Contract;
  private pg: PgClient;
  private redis: any;
  private blsKey: BLSKey;
  private operatorAddress: string;

  constructor() {
    // Initialize provider and wallet
    const rpcUrl = process.env.BASE_SEPOLIA_RPC || 'https://sepolia.base.org';
    this.provider = new ethers.JsonRpcProvider(rpcUrl);

    const privateKey = process.env.OPERATOR_PRIVATE_KEY;
    if (!privateKey) {
      throw new Error('OPERATOR_PRIVATE_KEY not set');
    }
    this.wallet = new ethers.Wallet(privateKey, this.provider);
    this.operatorAddress = this.wallet.address;

    // Initialize contracts
    const taskManagerAddress = process.env.TASK_MANAGER_ADDRESS;
    const serviceManagerAddress = process.env.SERVICE_MANAGER_ADDRESS;

    if (!taskManagerAddress || !serviceManagerAddress) {
      throw new Error('Contract addresses not set');
    }

    this.taskManager = new ethers.Contract(
      taskManagerAddress,
      TASK_MANAGER_ABI,
      this.wallet
    );

    this.serviceManager = new ethers.Contract(
      serviceManagerAddress,
      SERVICE_MANAGER_ABI,
      this.wallet
    );

    // Initialize PostgreSQL
    this.pg = new PgClient({
      host: process.env.POSTGRES_HOST || 'postgres',
      port: parseInt(process.env.POSTGRES_PORT || '5432'),
      user: process.env.POSTGRES_USER || 'bastion',
      password: process.env.POSTGRES_PASSWORD || 'bastion',
      database: process.env.POSTGRES_DB || 'bastion_operator'
    });

    // Load BLS key
    const blsKeyPath = process.env.BLS_KEY_PATH || '/keys/bls_key.json';
    this.blsKey = JSON.parse(fs.readFileSync(blsKeyPath, 'utf-8'));

    logger.info('Bastion Operator initialized', {
      operator: this.operatorAddress,
      taskManager: taskManagerAddress,
      serviceManager: serviceManagerAddress
    });
  }

  async start() {
    // Connect to databases
    await this.pg.connect();
    logger.info('Connected to PostgreSQL');

    this.redis = createClient({
      url: `redis://${process.env.REDIS_HOST || 'redis'}:${process.env.REDIS_PORT || 6379}`
    });
    await this.redis.connect();
    logger.info('Connected to Redis');

    // Update operator state
    await this.updateOperatorState();

    // Subscribe to depeg alerts
    await this.subscribeToDepegAlerts();

    // Listen for tasks
    await this.listenForTasks();

    // Start API server
    this.startApiServer();

    // Start balance monitoring
    this.startBalanceMonitoring();

    logger.info('Bastion Operator started successfully');
  }

  private async updateOperatorState() {
    const balance = await this.provider.getBalance(this.operatorAddress);

    await this.pg.query(
      `INSERT INTO operator_state (operator_address, bls_pub_key, last_heartbeat, updated_at)
       VALUES ($1, $2, NOW(), NOW())
       ON CONFLICT (operator_address) DO UPDATE
       SET bls_pub_key = $2, last_heartbeat = NOW(), updated_at = NOW()`,
      [this.operatorAddress, this.blsKey.PublicKey]
    );

    logger.info('Operator state updated', {
      address: this.operatorAddress,
      balance: ethers.formatEther(balance)
    });
  }

  private async subscribeToDepegAlerts() {
    const subscriber = this.redis.duplicate();
    await subscriber.connect();

    await subscriber.subscribe('depeg-alert', async (message: string) => {
      const depegEvent = JSON.parse(message);
      logger.warn('Depeg event detected', depegEvent);

      // Create task entry for potential manual intervention
      await this.pg.query(
        `INSERT INTO tasks (task_index, task_type, task_data, created_block, status)
         VALUES (-1, 99, $1, 0, 'alert')`,
        [JSON.stringify(depegEvent)]
      );
    });

    logger.info('Subscribed to depeg alerts');
  }

  private async listenForTasks() {
    logger.info('Listening for NewTaskCreated events...');

    // Listen for new tasks
    this.taskManager.on('NewTaskCreated', async (taskIndex: bigint, taskType: number, taskData: string, event: any) => {
      tasksReceived.inc();

      const task: TaskData = {
        taskIndex: Number(taskIndex),
        taskType,
        taskData,
        blockNumber: event.log.blockNumber
      };

      logger.info('New task received', task);

      // Store task in database
      await this.pg.query(
        `INSERT INTO tasks (task_index, task_type, task_data, created_block, status)
         VALUES ($1, $2, $3, $4, 'pending')
         ON CONFLICT (task_index) DO NOTHING`,
        [task.taskIndex, task.taskType, task.taskData, task.blockNumber]
      );

      // Publish to Redis for task responder
      await this.redis.publish('new-task', JSON.stringify(task));
    });

    // Catch up on past tasks
    const currentBlock = await this.provider.getBlockNumber();
    const fromBlock = currentBlock - 1000; // Last ~1000 blocks

    const filter = this.taskManager.filters.NewTaskCreated();
    const events = await this.taskManager.queryFilter(filter, fromBlock, currentBlock);

    logger.info(`Found ${events.length} historical tasks`);

    for (const event of events) {
      const args = event.args;
      if (args) {
        const task: TaskData = {
          taskIndex: Number(args[0]),
          taskType: Number(args[1]),
          taskData: args[2],
          blockNumber: event.blockNumber
        };

        await this.pg.query(
          `INSERT INTO tasks (task_index, task_type, task_data, created_block, status)
           VALUES ($1, $2, $3, $4, 'pending')
           ON CONFLICT (task_index) DO NOTHING`,
          [task.taskIndex, task.taskType, task.taskData, task.blockNumber]
        );
      }
    }
  }

  private async submitTaskResponse(taskIndex: number, response: string, signature: string) {
    const timer = taskProcessingTime.startTimer();

    try {
      logger.info('Submitting task response', { taskIndex, response, signature });

      const tx = await this.taskManager.respondToTask(
        taskIndex,
        response,
        signature
      );

      const receipt = await tx.wait();
      logger.info('Task response submitted', {
        taskIndex,
        txHash: receipt.hash,
        gasUsed: receipt.gasUsed.toString()
      });

      // Update database
      await this.pg.query(
        `UPDATE tasks SET status = 'completed', completed_at = NOW()
         WHERE task_index = $1`,
        [taskIndex]
      );

      await this.pg.query(
        `UPDATE task_responses SET tx_hash = $1, confirmed = true
         WHERE task_index = $2`,
        [receipt.hash, taskIndex]
      );

      tasksProcessed.inc({ status: 'success' });
    } catch (error: any) {
      logger.error('Failed to submit task response', {
        taskIndex,
        error: error.message
      });

      await this.pg.query(
        `UPDATE tasks SET status = 'failed' WHERE task_index = $1`,
        [taskIndex]
      );

      tasksProcessed.inc({ status: 'failed' });
      throw error;
    } finally {
      timer();
    }
  }

  private startApiServer() {
    const app = express();
    app.use(express.json());

    // Health check
    app.get('/health', (req, res) => {
      res.json({
        status: 'healthy',
        operator: this.operatorAddress,
        timestamp: new Date().toISOString()
      });
    });

    // Metrics endpoint
    app.get('/metrics', async (req, res) => {
      res.set('Content-Type', register.contentType);
      res.end(await register.metrics());
    });

    // Get operator status
    app.get('/status', async (req, res) => {
      const result = await this.pg.query(
        'SELECT * FROM operator_state WHERE operator_address = $1',
        [this.operatorAddress]
      );

      const tasksResult = await this.pg.query(
        'SELECT status, COUNT(*) as count FROM tasks GROUP BY status'
      );

      res.json({
        operator: result.rows[0],
        tasks: tasksResult.rows,
        blsPublicKey: this.blsKey.PublicKey
      });
    });

    // Get pending tasks
    app.get('/tasks/pending', async (req, res) => {
      const result = await this.pg.query(
        `SELECT * FROM tasks WHERE status = 'pending' ORDER BY created_at ASC LIMIT 100`
      );
      res.json(result.rows);
    });

    // Manual task submission endpoint
    app.post('/tasks/:taskIndex/respond', async (req, res) => {
      const { taskIndex } = req.params;
      const { response, signature } = req.body;

      try {
        await this.submitTaskResponse(Number(taskIndex), response, signature);
        res.json({ success: true });
      } catch (error: any) {
        res.status(500).json({ error: error.message });
      }
    });

    const port = process.env.API_PORT || 8080;
    app.listen(port, () => {
      logger.info(`API server listening on port ${port}`);
    });
  }

  private startBalanceMonitoring() {
    setInterval(async () => {
      try {
        const balance = await this.provider.getBalance(this.operatorAddress);
        const balanceEth = parseFloat(ethers.formatEther(balance));
        operatorBalance.set(balanceEth);

        if (balanceEth < 0.1) {
          logger.warn('Low operator balance', { balance: balanceEth });
        }

        // Update heartbeat
        await this.pg.query(
          `UPDATE operator_state SET last_heartbeat = NOW(), updated_at = NOW()
           WHERE operator_address = $1`,
          [this.operatorAddress]
        );
      } catch (error: any) {
        logger.error('Balance monitoring error', { error: error.message });
      }
    }, 60000); // Every minute
  }
}

// Start the operator
const operator = new BastionOperator();
operator.start().catch((error) => {
  logger.error('Fatal error starting operator', { error: error.message });
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down gracefully');
  process.exit(0);
});
