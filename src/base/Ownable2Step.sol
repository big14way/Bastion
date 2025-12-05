// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Ownable2Step
/// @notice Two-step ownership transfer pattern for safer ownership management
/// @dev Prevents accidental transfers to wrong addresses by requiring acceptance
abstract contract Ownable2Step {
    // -----------------------------------------------
    // State Variables
    // -----------------------------------------------

    /// @notice Current owner address
    address private _owner;

    /// @notice Pending owner address (awaiting acceptance)
    address private _pendingOwner;

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    /// @notice Emitted when ownership transfer is initiated
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when ownership transfer is completed
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------
    // Errors
    // -----------------------------------------------

    /// @notice Thrown when caller is not the owner
    error OwnableUnauthorizedAccount(address account);

    /// @notice Thrown when new owner is the zero address
    error OwnableInvalidOwner(address owner);

    // -----------------------------------------------
    // Modifiers
    // -----------------------------------------------

    /// @notice Restricts function access to owner only
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    // -----------------------------------------------
    // Constructor
    // -----------------------------------------------

    /// @notice Initialize with initial owner
    /// @param initialOwner Address of the initial owner
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    // -----------------------------------------------
    // External Functions
    // -----------------------------------------------

    /// @notice Returns the current owner
    /// @return Current owner address
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @notice Returns the pending owner
    /// @return Pending owner address
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /// @notice Starts the ownership transfer to a new account
    /// @dev Can only be called by current owner. Replaces any pending transfer.
    /// @param newOwner Address of the new owner
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    /// @notice Accepts the ownership transfer
    /// @dev Can only be called by the pending owner
    function acceptOwnership() public virtual {
        address sender = msg.sender;
        if (_pendingOwner != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }

    /// @notice Renounces ownership, leaving contract without owner
    /// @dev Can only be called by current owner. Contract will be unmanageable.
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    // -----------------------------------------------
    // Internal Functions
    // -----------------------------------------------

    /// @notice Checks if caller is owner
    function _checkOwner() internal view virtual {
        if (_owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    /// @notice Internal ownership transfer
    /// @param newOwner New owner address
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        _pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
