import { ethers } from 'ethers';
import { logger } from './logger';

export class SignatureService {
  private wallet: ethers.Wallet;

  constructor(wallet: ethers.Wallet) {
    this.wallet = wallet;
  }

  /**
   * Signs a task response using ECDSA signature
   * Following the same pattern as the smart contract verification:
   * keccak256(abi.encodePacked(taskIndex, responseData))
   *
   * @param taskIndex - Index of the task
   * @param responseData - ABI-encoded response data
   * @returns Signature string
   */
  async signTaskResponse(taskIndex: number, responseData: string): Promise<string> {
    try {
      // Create message hash: keccak256(abi.encodePacked(taskIndex, responseData))
      const messageHash = ethers.solidityPackedKeccak256(
        ['uint32', 'bytes'],
        [taskIndex, responseData]
      );

      logger.debug(`Message hash for task #${taskIndex}: ${messageHash}`);

      // Sign the message hash (wallet will automatically add Ethereum Signed Message prefix)
      const signature = await this.wallet.signMessage(ethers.getBytes(messageHash));

      logger.debug(`Generated signature: ${signature}`);

      return signature;
    } catch (error) {
      logger.error(`Failed to sign task response:`, error);
      throw error;
    }
  }

  /**
   * Verifies a signature (for testing purposes)
   *
   * @param taskIndex - Index of the task
   * @param responseData - ABI-encoded response data
   * @param signature - Signature to verify
   * @returns Recovered signer address
   */
  async verifySignature(
    taskIndex: number,
    responseData: string,
    signature: string
  ): Promise<string> {
    try {
      const messageHash = ethers.solidityPackedKeccak256(
        ['uint32', 'bytes'],
        [taskIndex, responseData]
      );

      // Add Ethereum Signed Message prefix
      const ethSignedMessageHash = ethers.hashMessage(ethers.getBytes(messageHash));

      // Recover signer
      const recoveredSigner = ethers.recoverAddress(ethSignedMessageHash, signature);

      return recoveredSigner;
    } catch (error) {
      logger.error(`Failed to verify signature:`, error);
      throw error;
    }
  }
}
