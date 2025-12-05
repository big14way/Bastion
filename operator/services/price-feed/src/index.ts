import { ethers } from 'ethers';
import Redis from 'ioredis';
import { Pool } from 'pg';
import pino from 'pino';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

// Chainlink Aggregator ABI (minimal)
const AGGREGATOR_ABI = [
  'function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)',
  'function decimals() external view returns (uint8)'
];

interface PriceData {
  asset: string;
  price: string;
  decimals: number;
  timestamp: number;
  roundId: string;
}

class PriceFeedListener {
  private provider: ethers.JsonRpcProvider;
  private redis: Redis;
  private pg: Pool;
  private feeds: Map<string, ethers.Contract> = new Map();

  constructor() {
    this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    this.redis = new Redis(process.env.REDIS_URL!);
    this.pg = new Pool({ connectionString: process.env.POSTGRES_URL });

    this.initializeFeeds();
  }

  private initializeFeeds() {
    const feeds = {
      'stETH/USD': process.env.STETH_FEED,
      'ETH/USD': process.env.ETH_FEED,
    };

    for (const [asset, address] of Object.entries(feeds)) {
      if (address && address !== '0x0000000000000000000000000000000000000000') {
        this.feeds.set(asset, new ethers.Contract(address, AGGREGATOR_ABI, this.provider));
        logger.info({ asset, address }, 'Initialized price feed');
      }
    }
  }

  async start() {
    logger.info('🚀 Starting Bastion Price Feed Listener');

    // Initial fetch
    await this.fetchAllPrices();

    // Set up polling
    const interval = parseInt(process.env.POLL_INTERVAL || '30') * 1000;
    setInterval(() => this.fetchAllPrices(), interval);

    logger.info({ interval: interval / 1000 }, 'Price feed listener started');
  }

  private async fetchAllPrices() {
    const promises = Array.from(this.feeds.entries()).map(([asset, contract]) =>
      this.fetchPrice(asset, contract)
    );

    await Promise.allSettled(promises);
  }

  private async fetchPrice(asset: string, contract: ethers.Contract) {
    try {
      const [roundData, decimals] = await Promise.all([
        contract.latestRoundData(),
        contract.decimals()
      ]);

      const priceData: PriceData = {
        asset,
        price: roundData.answer.toString(),
        decimals: Number(decimals),
        timestamp: Number(roundData.updatedAt),
        roundId: roundData.roundId.toString()
      };

      // Store in Redis
      await this.redis.setex(
        `price:${asset}`,
        300, // 5 minute TTL
        JSON.stringify(priceData)
      );

      // Publish update
      await this.redis.publish('price-updates', JSON.stringify(priceData));

      // Store in PostgreSQL
      await this.pg.query(
        `INSERT INTO price_history (asset, price, decimals, timestamp, round_id)
         VALUES ($1, $2, $3, to_timestamp($4), $5)
         ON CONFLICT (asset, round_id) DO NOTHING`,
        [asset, priceData.price, priceData.decimals, priceData.timestamp, priceData.roundId]
      );

      // Check for depeg
      await this.checkDepeg(asset, priceData);

      logger.debug({ asset, price: priceData.price }, 'Price updated');
    } catch (error) {
      logger.error({ asset, error }, 'Failed to fetch price');
    }
  }

  private async checkDepeg(asset: string, priceData: PriceData) {
    if (!asset.startsWith('stETH')) return;

    // Get ETH price
    const ethPriceStr = await this.redis.get('price:ETH/USD');
    if (!ethPriceStr) return;

    const ethPrice = JSON.parse(ethPriceStr);

    // Calculate depeg percentage
    const stETHPrice = BigInt(priceData.price);
    const ethPriceBN = BigInt(ethPrice.price);

    // Both should have same decimals (8 for Chainlink)
    const diff = ethPriceBN > stETHPrice ? ethPriceBN - stETHPrice : stETHPrice - ethPriceBN;
    const depegBps = (diff * 10000n) / ethPriceBN;

    logger.info({ depegBps: depegBps.toString() }, 'Depeg check');

    // Trigger alert if depeg > 20% (2000 bps)
    if (depegBps > 2000n) {
      const depegEvent = {
        asset: 'stETH',
        depegPercentage: depegBps.toString(),
        stETHPrice: priceData.price,
        ethPrice: ethPrice.price,
        timestamp: Date.now()
      };

      await this.redis.publish('depeg-alert', JSON.stringify(depegEvent));
      logger.warn(depegEvent, '🚨 DEPEG DETECTED');

      // Store in database
      await this.pg.query(
        `INSERT INTO depeg_events (asset, depeg_bps, steth_price, eth_price, detected_at)
         VALUES ($1, $2, $3, $4, NOW())`,
        ['stETH', depegBps.toString(), priceData.price, ethPrice.price]
      );
    }
  }
}

// Start the service
const listener = new PriceFeedListener();
listener.start().catch((error) => {
  logger.fatal(error, 'Failed to start price feed listener');
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('Shutting down price feed listener');
  process.exit(0);
});
