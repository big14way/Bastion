import { ethers } from 'ethers';
import { logger } from './logger';

export interface TaskHandlerConfig {
  provider: ethers.Provider;
  chainlinkPriceFeedETHUSD: string;
  chainlinkPriceFeedSTETH: string;
}

interface DepegCheckTask {
  assetAddress: string;
  timestamp: bigint;
}

interface VolatilityCalcTask {
  poolAddress: string;
  timeWindow: bigint;
  timestamp: bigint;
}

interface RateUpdateTask {
  lendingModuleAddress: string;
  utilization: bigint;
  timestamp: bigint;
}

export class TaskHandler {
  private provider: ethers.Provider;
  private chainlinkETHUSD: ethers.Contract;
  private chainlinkSTETH: ethers.Contract;

  // Chainlink Aggregator ABI (minimal)
  private static readonly CHAINLINK_ABI = [
    'function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)',
    'function decimals() external view returns (uint8)',
  ];

  // Price deviation threshold (5% = 500 basis points)
  private static readonly DEPEG_THRESHOLD_BPS = 500;
  private static readonly BASIS_POINTS = 10000;

  constructor(config: TaskHandlerConfig) {
    this.provider = config.provider;

    // Initialize Chainlink price feeds
    this.chainlinkETHUSD = new ethers.Contract(
      config.chainlinkPriceFeedETHUSD,
      TaskHandler.CHAINLINK_ABI,
      this.provider
    );

    this.chainlinkSTETH = new ethers.Contract(
      config.chainlinkPriceFeedSTETH,
      TaskHandler.CHAINLINK_ABI,
      this.provider
    );
  }

  /**
   * Handle DEPEG_CHECK task
   * Fetches Chainlink prices and computes deviation from peg
   *
   * @param taskData - ABI-encoded task data: (address assetAddress, uint256 timestamp)
   * @returns ABI-encoded response: (bool isDepegged, uint256 currentPrice, uint256 deviation)
   */
  async handleDepegCheck(taskData: string): Promise<string> {
    try {
      // Decode task data
      const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
        ['address', 'uint256'],
        taskData
      );

      const task: DepegCheckTask = {
        assetAddress: decoded[0],
        timestamp: decoded[1],
      };

      logger.info(`DEPEG_CHECK: Checking asset ${task.assetAddress}`);

      // For this example, we'll check stETH/ETH price
      // In production, you'd check the specific asset
      const { currentPrice, deviation, isDepegged } = await this.checkDepeg(task.assetAddress);

      logger.info(
        `DEPEG_CHECK result: price=${currentPrice}, deviation=${deviation}bps, depegged=${isDepegged}`
      );

      // Encode response: (bool isDepegged, uint256 currentPrice, uint256 deviation)
      const responseData = ethers.AbiCoder.defaultAbiCoder().encode(
        ['bool', 'uint256', 'uint256'],
        [isDepegged, currentPrice, deviation]
      );

      return responseData;
    } catch (error) {
      logger.error('DEPEG_CHECK failed:', error);
      throw error;
    }
  }

  /**
   * Handle VOLATILITY_CALC task
   * Computes realized volatility from historical prices
   *
   * @param taskData - ABI-encoded task data: (address poolAddress, uint256 timeWindow, uint256 timestamp)
   * @returns ABI-encoded response: (uint256 volatility, uint256 timestamp)
   */
  async handleVolatilityCalc(taskData: string): Promise<string> {
    try {
      // Decode task data
      const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
        ['address', 'uint256', 'uint256'],
        taskData
      );

      const task: VolatilityCalcTask = {
        poolAddress: decoded[0],
        timeWindow: decoded[1],
        timestamp: decoded[2],
      };

      logger.info(
        `VOLATILITY_CALC: Computing volatility for pool ${task.poolAddress}, window=${task.timeWindow}s`
      );

      // Compute realized volatility
      const volatility = await this.computeRealizedVolatility(
        task.poolAddress,
        Number(task.timeWindow)
      );

      logger.info(`VOLATILITY_CALC result: volatility=${volatility}bps`);

      // Encode response: (uint256 volatility, uint256 timestamp)
      const responseData = ethers.AbiCoder.defaultAbiCoder().encode(
        ['uint256', 'uint256'],
        [volatility, BigInt(Math.floor(Date.now() / 1000))]
      );

      return responseData;
    } catch (error) {
      logger.error('VOLATILITY_CALC failed:', error);
      throw error;
    }
  }

  /**
   * Handle RATE_UPDATE task
   * Computes optimal interest rate based on utilization
   *
   * @param taskData - ABI-encoded task data: (address lendingModuleAddress, uint256 utilization, uint256 timestamp)
   * @returns ABI-encoded response: (uint256 newRate, uint256 timestamp)
   */
  async handleRateUpdate(taskData: string): Promise<string> {
    try {
      // Decode task data
      const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
        ['address', 'uint256', 'uint256'],
        taskData
      );

      const task: RateUpdateTask = {
        lendingModuleAddress: decoded[0],
        utilization: decoded[1],
        timestamp: decoded[2],
      };

      logger.info(
        `RATE_UPDATE: Computing rate for lending module ${task.lendingModuleAddress}, utilization=${task.utilization}bps`
      );

      // Compute optimal interest rate using utilization curve
      const newRate = await this.computeInterestRate(Number(task.utilization));

      logger.info(`RATE_UPDATE result: newRate=${newRate}bps`);

      // Encode response: (uint256 newRate, uint256 timestamp)
      const responseData = ethers.AbiCoder.defaultAbiCoder().encode(
        ['uint256', 'uint256'],
        [newRate, BigInt(Math.floor(Date.now() / 1000))]
      );

      return responseData;
    } catch (error) {
      logger.error('RATE_UPDATE failed:', error);
      throw error;
    }
  }

  /**
   * Checks if an asset is depegged by comparing to Chainlink price
   *
   * @param assetAddress - Address of the asset to check
   * @returns Object containing price, deviation, and depeg status
   */
  private async checkDepeg(assetAddress: string): Promise<{
    currentPrice: bigint;
    deviation: bigint;
    isDepegged: boolean;
  }> {
    try {
      // Fetch ETH/USD price
      const ethUsdData = await this.chainlinkETHUSD.latestRoundData();
      const ethUsdPrice = ethUsdData.answer; // 8 decimals

      // Fetch stETH/USD price (or asset-specific price)
      const stEthData = await this.chainlinkSTETH.latestRoundData();
      const stEthPrice = stEthData.answer; // 8 decimals

      // Calculate stETH/ETH ratio (normalized to 18 decimals)
      const ratio = (BigInt(stEthPrice) * BigInt(1e18)) / BigInt(ethUsdPrice);

      // Calculate deviation from 1:1 peg in basis points
      const expectedPeg = BigInt(1e18); // 1:1 ratio
      const deviation =
        ((expectedPeg - ratio) * BigInt(TaskHandler.BASIS_POINTS)) / expectedPeg;
      const absoluteDeviation = deviation < 0 ? -deviation : deviation;

      // Check if depegged (deviation > threshold)
      const isDepegged = absoluteDeviation > BigInt(TaskHandler.DEPEG_THRESHOLD_BPS);

      return {
        currentPrice: ratio,
        deviation: absoluteDeviation,
        isDepegged,
      };
    } catch (error) {
      logger.error('Failed to check depeg:', error);
      throw error;
    }
  }

  /**
   * Computes realized volatility from historical price data
   *
   * @param poolAddress - Address of the pool
   * @param timeWindow - Time window in seconds
   * @returns Volatility in basis points
   */
  private async computeRealizedVolatility(
    poolAddress: string,
    timeWindow: number
  ): Promise<bigint> {
    try {
      // In a production implementation, you would:
      // 1. Fetch historical price data from the pool
      // 2. Calculate log returns
      // 3. Compute standard deviation of returns
      // 4. Annualize the volatility

      // For this example, we'll fetch current price and estimate volatility
      // based on recent price movements (simplified)

      const currentBlock = await this.provider.getBlockNumber();
      const blocksInWindow = Math.floor(timeWindow / 12); // ~12 sec per block

      // Fetch price at current block and historical block
      // This is simplified - in production you'd use price oracle or pool events
      const historicalBlock = currentBlock - blocksInWindow;

      // Mock volatility calculation (replace with actual price fetching)
      // For demonstration: return volatility between 0.5% and 2.5%
      const mockVolatility = Math.floor(Math.random() * 200) + 50; // 50-250 bps

      logger.debug(
        `Computed volatility for pool ${poolAddress}: ${mockVolatility}bps over ${timeWindow}s`
      );

      return BigInt(mockVolatility);
    } catch (error) {
      logger.error('Failed to compute volatility:', error);
      // Return conservative high volatility on error
      return BigInt(500); // 5%
    }
  }

  /**
   * Computes optimal interest rate based on utilization
   * Uses a kinked interest rate model similar to Aave/Compound
   *
   * @param utilizationBps - Current utilization in basis points (0-10000)
   * @returns Interest rate in basis points
   */
  private async computeInterestRate(utilizationBps: number): Promise<bigint> {
    // Interest rate model parameters (in basis points)
    const BASE_RATE = 200; // 2% base rate
    const SLOPE_1 = 400; // 4% slope before kink
    const SLOPE_2 = 6000; // 60% slope after kink
    const OPTIMAL_UTILIZATION = 8000; // 80% optimal utilization

    let interestRate: number;

    if (utilizationBps <= OPTIMAL_UTILIZATION) {
      // Before kink: rate = BASE + (utilization * SLOPE_1) / OPTIMAL_UTILIZATION
      interestRate =
        BASE_RATE + (utilizationBps * SLOPE_1) / OPTIMAL_UTILIZATION;
    } else {
      // After kink: rate = BASE + SLOPE_1 + ((utilization - optimal) * SLOPE_2) / (10000 - optimal)
      const excessUtilization = utilizationBps - OPTIMAL_UTILIZATION;
      const excessSlope =
        (excessUtilization * SLOPE_2) / (10000 - OPTIMAL_UTILIZATION);
      interestRate = BASE_RATE + SLOPE_1 + excessSlope;
    }

    logger.debug(
      `Computed interest rate: ${interestRate}bps for utilization ${utilizationBps}bps`
    );

    return BigInt(Math.floor(interestRate));
  }
}
