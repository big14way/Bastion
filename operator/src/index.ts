import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import { BastionOperator } from './operator';
import { logger } from './logger';

dotenv.config();

async function main() {
  logger.info('Starting Bastion AVS Operator...');

  // Validate environment variables
  const requiredEnvVars = [
    'RPC_URL',
    'PRIVATE_KEY',
    'TASK_MANAGER_ADDRESS',
    'SERVICE_MANAGER_ADDRESS',
  ];

  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
      logger.error(`Missing required environment variable: ${envVar}`);
      process.exit(1);
    }
  }

  // Initialize provider and wallet
  const provider = new ethers.WebSocketProvider(process.env.RPC_URL!);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

  logger.info(`Operator address: ${wallet.address}`);

  // Initialize operator
  const operator = new BastionOperator({
    provider,
    wallet,
    taskManagerAddress: process.env.TASK_MANAGER_ADDRESS!,
    serviceManagerAddress: process.env.SERVICE_MANAGER_ADDRESS!,
    chainlinkPriceFeedETHUSD: process.env.CHAINLINK_ETH_USD || '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
    chainlinkPriceFeedSTETH: process.env.CHAINLINK_STETH || '0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8',
  });

  // Start operator
  await operator.start();

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    logger.info('Received SIGINT, shutting down gracefully...');
    await operator.stop();
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    logger.info('Received SIGTERM, shutting down gracefully...');
    await operator.stop();
    process.exit(0);
  });
}

main().catch((error) => {
  logger.error('Fatal error:', error);
  process.exit(1);
});
