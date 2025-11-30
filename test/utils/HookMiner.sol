// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Hooks} from "v4-core/src/libraries/Hooks.sol";

/**
 * @title HookMiner
 * @notice Utility to mine hook addresses with specific permission flags
 * @dev Based on Uniswap V4 hook address requirements
 */
library HookMiner {
    /**
     * @notice Find a salt that produces a hook address with required flags
     * @param deployer Address that will deploy the hook
     * @param flags Required hook permission flags
     * @param creationCode Contract creation bytecode
     * @param constructorArgs ABI-encoded constructor arguments
     * @return hookAddress The mined hook address
     * @return salt The salt that produces the hook address
     */
    function find(address deployer, uint160 flags, bytes memory creationCode, bytes memory constructorArgs)
        internal
        view
        returns (address, bytes32)
    {
        // Combine creation code with constructor args
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);

        // Try different salts until we find one that works
        for (uint256 i = 0; i < 100000; i++) {
            bytes32 salt = bytes32(i);
            address hookAddress = computeAddress(deployer, salt, bytecode);

            // Check if this address has the required flags
            if (uint160(hookAddress) & Hooks.ALL_HOOK_MASK == flags) {
                return (hookAddress, salt);
            }
        }

        revert("HookMiner: Could not find salt");
    }

    /**
     * @notice Compute CREATE2 address
     * @param deployer Deployer address
     * @param salt CREATE2 salt
     * @param bytecode Contract bytecode
     * @return Computed address
     */
    function computeAddress(address deployer, bytes32 salt, bytes memory bytecode)
        internal
        pure
        returns (address)
    {
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        return address(uint160(uint256(data)));
    }
}
