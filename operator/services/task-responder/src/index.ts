import { ethers } from 'ethers';
import { Client as PgClient } from 'pg';
import { createClient } from 'redis';
import { Registry, Counter, Gauge } from 'prom-client';
import winston from 'winston';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
import * as crypto from 'crypto';

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
    new winston.transports.File({ filename: 'responder.log' })
  ]
});

// Prometheus metrics
const register = new Registry();
const responsesGenerated = new Counter({
  name: 'bastion_responses_generated_total',
  help: 'Total number of task responses generated',
  labelNames: ['task_type'],
  registers: [register]
});
const responsesSubmitted = new Counter({
  name: 'bastion_responses_submitted_total',
  help: 'Total number of responses submitted to operator',
  registers: [register]
});

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

interface PriceData {
  asset: string;
  price: string;
  decimals: number;
  timestamp: number;
}

class TaskResponder {
  private pg: PgClient;
  private redis: any;
  private blsKey: BLSKey;
  private operatorAddress: string;

  constructor() {
    // Load operator address
    const privateKey = process.env.OPERATOR_PRIVATE_KEY;
    if (!privateKey) {
      throw new Error('OPERATOR_PRIVATE_KEY not set');
    }
    const wallet = new ethers.Wallet(privateKey);
    this.operatorAddress = wallet.address;

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

    logger.info('Task Responder initialized', {
      operator: this.operatorAddress
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

    // Subscribe to new tasks
    await this.subscribeToTasks();

    logger.info('Task Responder started successfully');
  }

  private async subscribeToTasks() {
    const subscriber = this.redis.duplicate();
    await subscriber.connect();

    await subscriber.subscribe('new-task', async (message: string) => {
      try {
        const task: TaskData = JSON.parse(message);
        logger.info('Processing task', task);

        await this.processTask(task);
      } catch (error: any) {
        logger.error('Error processing task message', { error: error.message });
      }
    });

    logger.info('Subscribed to new-task channel');
  }

  private async processTask(task: TaskData) {
    try {
      let response: string;
      let responseData: any;

      // Task types:
      // 0 = Price verification
      // 1 = Depeg detection
      // 2 = Volatility calculation
      // 3 = Risk assessment

      switch (task.taskType) {
        case 0:
          responseData = await this.handlePriceVerification(task);
          break;
        case 1:
          responseData = await this.handleDepegDetection(task);
          break;
        case 2:
          responseData = await this.handleVolatilityCalculation(task);
          break;
        case 3:
          responseData = await this.handleRiskAssessment(task);
          break;
        default:
          logger.warn('Unknown task type', { taskType: task.taskType });
          return;
      }

      // Encode response
      response = this.encodeResponse(responseData);

      // Sign response with BLS key
      const signature = this.signResponse(response);

      // Store response in database
      await this.pg.query(
        `INSERT INTO task_responses (task_index, operator_address, response_data, signature)
         VALUES ($1, $2, $3, $4)`,
        [task.taskIndex, this.operatorAddress, response, signature]
      );

      // Update task status
      await this.pg.query(
        `UPDATE tasks SET status = 'responded', responded_at = NOW()
         WHERE task_index = $1`,
        [task.taskIndex]
      );

      // Publish response for operator node to submit
      await this.redis.publish('task-response', JSON.stringify({
        taskIndex: task.taskIndex,
        response,
        signature
      }));

      responsesGenerated.inc({ task_type: task.taskType.toString() });
      responsesSubmitted.inc();

      logger.info('Task response generated', {
        taskIndex: task.taskIndex,
        taskType: task.taskType,
        response,
        signature: signature.substring(0, 20) + '...'
      });

    } catch (error: any) {
      logger.error('Failed to process task', {
        taskIndex: task.taskIndex,
        error: error.message
      });

      await this.pg.query(
        `UPDATE tasks SET status = 'failed' WHERE task_index = $1`,
        [task.taskIndex]
      );
    }
  }

  private async handlePriceVerification(task: TaskData): Promise<any> {
    // Decode task data to get asset
    const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
      ['string'],
      task.taskData
    );
    const asset = decoded[0];

    // Get latest price from database
    const result = await this.pg.query(
      `SELECT price, decimals, timestamp FROM price_history
       WHERE asset = $1 ORDER BY timestamp DESC LIMIT 1`,
      [asset]
    );

    if (result.rows.length === 0) {
      throw new Error(`No price data for asset ${asset}`);
    }

    const priceData = result.rows[0];

    return {
      asset,
      price: priceData.price,
      decimals: priceData.decimals,
      timestamp: Math.floor(new Date(priceData.timestamp).getTime() / 1000),
      verified: true
    };
  }

  private async handleDepegDetection(task: TaskData): Promise<any> {
    // Check for recent depeg events
    const result = await this.pg.query(
      `SELECT * FROM depeg_events
       WHERE resolved_at IS NULL
       ORDER BY detected_at DESC
       LIMIT 1`
    );

    if (result.rows.length === 0) {
      return {
        depegged: false,
        depegBps: 0,
        timestamp: Math.floor(Date.now() / 1000)
      };
    }

    const depegEvent = result.rows[0];

    return {
      depegged: true,
      asset: depegEvent.asset,
      depegBps: depegEvent.depeg_bps,
      stethPrice: depegEvent.steth_price,
      ethPrice: depegEvent.eth_price,
      detectedAt: Math.floor(new Date(depegEvent.detected_at).getTime() / 1000),
      timestamp: Math.floor(Date.now() / 1000)
    };
  }

  private async handleVolatilityCalculation(task: TaskData): Promise<any> {
    // Decode task data to get asset and period
    const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
      ['string', 'uint256'],
      task.taskData
    );
    const asset = decoded[0];
    const periodHours = Number(decoded[1]);

    // Get price history
    const result = await this.pg.query(
      `SELECT price, timestamp FROM price_history
       WHERE asset = $1 AND timestamp > NOW() - INTERVAL '${periodHours} hours'
       ORDER BY timestamp ASC`,
      [asset]
    );

    if (result.rows.length < 2) {
      throw new Error('Insufficient price history for volatility calculation');
    }

    // Calculate returns
    const returns: number[] = [];
    for (let i = 1; i < result.rows.length; i++) {
      const prevPrice = parseFloat(result.rows[i - 1].price);
      const currPrice = parseFloat(result.rows[i].price);
      const ret = Math.log(currPrice / prevPrice);
      returns.push(ret);
    }

    // Calculate standard deviation (volatility)
    const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
    const variance = returns.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / returns.length;
    const volatility = Math.sqrt(variance);

    // Annualize volatility (assuming hourly data)
    const annualizedVol = volatility * Math.sqrt(24 * 365);

    // Convert to basis points
    const volatilityBps = Math.floor(annualizedVol * 10000);

    return {
      asset,
      volatilityBps,
      periodHours,
      dataPoints: returns.length,
      timestamp: Math.floor(Date.now() / 1000)
    };
  }

  private async handleRiskAssessment(task: TaskData): Promise<any> {
    // Decode task data to get parameters
    const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
      ['string', 'uint256'],
      task.taskData
    );
    const asset = decoded[0];
    const amount = decoded[1];

    // Get latest price and volatility
    const priceResult = await this.pg.query(
      `SELECT price FROM price_history
       WHERE asset = $1 ORDER BY timestamp DESC LIMIT 1`,
      [asset]
    );

    // Check for depeg
    const depegResult = await this.pg.query(
      `SELECT COUNT(*) as count FROM depeg_events
       WHERE asset = $1 AND resolved_at IS NULL`,
      [asset]
    );

    const isDepegged = depegResult.rows[0].count > 0;

    // Simple risk score calculation (0-100)
    let riskScore = 0;
    if (isDepegged) riskScore += 50;

    // Get volatility from recent calculations
    const volatilityResult = await this.pg.query(
      `SELECT metric_value FROM operator_metrics
       WHERE metric_name = 'volatility' AND labels->>'asset' = $1
       ORDER BY recorded_at DESC LIMIT 1`,
      [asset]
    );

    if (volatilityResult.rows.length > 0) {
      const vol = parseFloat(volatilityResult.rows[0].metric_value);
      riskScore += Math.min(vol / 100, 50); // Cap volatility contribution at 50
    }

    return {
      asset,
      amount: amount.toString(),
      riskScore: Math.floor(riskScore),
      isDepegged,
      timestamp: Math.floor(Date.now() / 1000)
    };
  }

  private encodeResponse(responseData: any): string {
    // Encode response data as bytes
    // This is a simplified version - in production, use proper ABI encoding
    const jsonString = JSON.stringify(responseData);
    const encoder = new TextEncoder();
    const bytes = encoder.encode(jsonString);
    return '0x' + Buffer.from(bytes).toString('hex');
  }

  private signResponse(response: string): string {
    // Sign response with BLS private key
    // This is a simplified implementation using ECDSA instead of BLS
    // In production, use proper BLS signatures (e.g., @noble/curves/bls12-381)

    const messageHash = ethers.keccak256(response);

    // Use BLS private key for signing (simplified - convert to bytes)
    const blsPrivateKey = this.blsKey.PrivateKey.replace('0x', '');
    const privateKeyBytes = Buffer.from(blsPrivateKey, 'hex');

    // Create a simple signature using the first 32 bytes as a seed
    const signingKey = new ethers.SigningKey(privateKeyBytes.subarray(0, 32));
    const signature = signingKey.sign(messageHash);

    // Return serialized signature
    return signature.serialized;
  }
}

// Start the responder
const responder = new TaskResponder();
responder.start().catch((error) => {
  logger.error('Fatal error starting responder', { error: error.message });
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
