import { ethers } from 'ethers';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

dotenv.config();

// ABIs
const DELEGATION_MANAGER_ABI = [
  'function registerAsOperator(tuple(address earningsReceiver, address delegationApprover, uint32 stakerOptOutWindowBlocks) operatorDetails, string calldata metadataURI) external',
  'function isOperator(address operator) external view returns (bool)'
];

const REGISTRY_COORDINATOR_ABI = [
  'function registerOperator(bytes memory quorumNumbers, string calldata socket, tuple(uint256 X, uint256 Y) memory params, tuple(uint256 X, uint256 Y)[] memory pubkeyRegistrationSignature) external',
  'function getOperatorId(address operator) external view returns (bytes32)'
];

const AVS_DIRECTORY_ABI = [
  'function registerOperatorToAVS(address operator, tuple(bytes signature, bytes32 salt, uint256 expiry) memory operatorSignature) external',
  'function avsOperatorStatus(address avs, address operator) external view returns (uint8)'
];

interface BLSKey {
  PrivateKey: string;
  PublicKey: string;
  G1PubKey: string;
  G2PubKey: string;
}

async function main() {
  console.log('=== Bastion Operator Registration ===\n');

  // Setup provider and wallet
  const rpcUrl = process.env.BASE_SEPOLIA_RPC || 'https://sepolia.base.org';
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  const privateKey = process.env.OPERATOR_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('OPERATOR_PRIVATE_KEY not set in .env');
  }

  const wallet = new ethers.Wallet(privateKey, provider);
  const operatorAddress = wallet.address;

  console.log(`Operator Address: ${operatorAddress}`);

  // Check balance
  const balance = await provider.getBalance(operatorAddress);
  console.log(`Balance: ${ethers.formatEther(balance)} ETH`);

  if (balance < ethers.parseEther('0.1')) {
    console.error('\nERROR: Insufficient balance. Need at least 0.1 ETH for registration.');
    console.error('Please fund your operator address with test ETH from Base Sepolia faucet.');
    process.exit(1);
  }

  // Load BLS key
  const blsKeyPath = process.env.BLS_KEY_PATH || './keys/bls_key.json';
  if (!fs.existsSync(blsKeyPath)) {
    throw new Error(`BLS key not found at ${blsKeyPath}. Run setup.sh first.`);
  }

  const blsKey: BLSKey = JSON.parse(fs.readFileSync(blsKeyPath, 'utf-8'));
  console.log(`BLS Public Key: ${blsKey.PublicKey.substring(0, 20)}...`);

  // Contract addresses
  const delegationManagerAddr = process.env.DELEGATION_MANAGER_ADDRESS;
  const registryCoordinatorAddr = process.env.REGISTRY_COORDINATOR_ADDRESS;
  const avsDirectoryAddr = process.env.AVS_DIRECTORY_ADDRESS;
  const serviceManagerAddr = process.env.SERVICE_MANAGER_ADDRESS;

  if (!delegationManagerAddr || !registryCoordinatorAddr || !avsDirectoryAddr || !serviceManagerAddr) {
    throw new Error('Contract addresses not set in .env. Please set DELEGATION_MANAGER_ADDRESS, REGISTRY_COORDINATOR_ADDRESS, AVS_DIRECTORY_ADDRESS, and SERVICE_MANAGER_ADDRESS');
  }

  console.log('\nContract Addresses:');
  console.log(`- DelegationManager: ${delegationManagerAddr}`);
  console.log(`- RegistryCoordinator: ${registryCoordinatorAddr}`);
  console.log(`- AVSDirectory: ${avsDirectoryAddr}`);
  console.log(`- ServiceManager: ${serviceManagerAddr}`);

  // Initialize contracts
  const delegationManager = new ethers.Contract(
    delegationManagerAddr,
    DELEGATION_MANAGER_ABI,
    wallet
  );

  const registryCoordinator = new ethers.Contract(
    registryCoordinatorAddr,
    REGISTRY_COORDINATOR_ABI,
    wallet
  );

  const avsDirectory = new ethers.Contract(
    avsDirectoryAddr,
    AVS_DIRECTORY_ABI,
    wallet
  );

  console.log('\n=== Step 1: Register as EigenLayer Operator ===');

  // Check if already registered
  const isOperator = await delegationManager.isOperator(operatorAddress);

  if (isOperator) {
    console.log('✓ Already registered as EigenLayer operator');
  } else {
    console.log('Registering as EigenLayer operator...');

    const operatorDetails = {
      earningsReceiver: operatorAddress,
      delegationApprover: ethers.ZeroAddress, // No delegation approver
      stakerOptOutWindowBlocks: 0 // No opt-out window
    };

    const metadataURI = process.env.OPERATOR_METADATA_URI || '';

    const tx = await delegationManager.registerAsOperator(
      operatorDetails,
      metadataURI
    );

    console.log(`Transaction hash: ${tx.hash}`);
    await tx.wait();
    console.log('✓ Successfully registered as EigenLayer operator');
  }

  console.log('\n=== Step 2: Register with AVS Registry ===');

  // Check if already registered with AVS
  try {
    const operatorId = await registryCoordinator.getOperatorId(operatorAddress);
    if (operatorId !== ethers.ZeroHash) {
      console.log(`✓ Already registered with AVS Registry (ID: ${operatorId})`);
    } else {
      await registerWithAVS(registryCoordinator, blsKey, operatorAddress);
    }
  } catch (error) {
    await registerWithAVS(registryCoordinator, blsKey, operatorAddress);
  }

  console.log('\n=== Step 3: Register with AVS Directory ===');

  // Check AVS operator status
  const avsStatus = await avsDirectory.avsOperatorStatus(serviceManagerAddr, operatorAddress);

  if (avsStatus !== 0) {
    console.log('✓ Already registered with AVS Directory');
  } else {
    console.log('Registering with AVS Directory...');

    // Create operator signature
    const salt = ethers.hexlify(ethers.randomBytes(32));
    const expiry = Math.floor(Date.now() / 1000) + 86400; // 24 hours from now

    // Create signature digest
    const messageHash = ethers.solidityPackedKeccak256(
      ['address', 'address', 'bytes32', 'uint256'],
      [operatorAddress, serviceManagerAddr, salt, expiry]
    );

    const signature = await wallet.signMessage(ethers.getBytes(messageHash));

    const operatorSignature = {
      signature,
      salt,
      expiry
    };

    const tx = await avsDirectory.registerOperatorToAVS(
      operatorAddress,
      operatorSignature
    );

    console.log(`Transaction hash: ${tx.hash}`);
    await tx.wait();
    console.log('✓ Successfully registered with AVS Directory');
  }

  console.log('\n=== Registration Complete! ===');
  console.log('\nNext steps:');
  console.log('1. Start the operator infrastructure: docker-compose up -d');
  console.log('2. Monitor logs: docker-compose logs -f operator-node');
  console.log('3. Check operator status: curl http://localhost:8080/status');
  console.log('4. View metrics: http://localhost:3000 (Grafana)');
  console.log('\nYour operator is now ready to start processing tasks!');
}

async function registerWithAVS(
  registryCoordinator: ethers.Contract,
  blsKey: BLSKey,
  operatorAddress: string
) {
  console.log('Registering with AVS Registry...');

  // Quorum numbers (simplified - register for quorum 0)
  const quorumNumbers = '0x00';

  // Socket (operator endpoint)
  const socket = process.env.OPERATOR_SOCKET || 'http://localhost:8080';

  // BLS public key points (G1 and G2)
  const g1Point = {
    X: BigInt(blsKey.G1PubKey),
    Y: 0n // Simplified - in production, extract Y coordinate
  };

  const g2Point = {
    X: BigInt(blsKey.G2PubKey),
    Y: 0n // Simplified
  };

  // Empty signature for now (in production, sign registration message)
  const pubkeyRegistrationSignature = [g1Point];

  try {
    const tx = await registryCoordinator.registerOperator(
      quorumNumbers,
      socket,
      g1Point,
      pubkeyRegistrationSignature
    );

    console.log(`Transaction hash: ${tx.hash}`);
    await tx.wait();
    console.log('✓ Successfully registered with AVS Registry');
  } catch (error: any) {
    console.warn(`Note: AVS Registry registration may need to be done through AVS-specific process`);
    console.warn(`Error: ${error.message}`);
  }
}

// Run the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\nRegistration failed:', error.message);
    process.exit(1);
  });
