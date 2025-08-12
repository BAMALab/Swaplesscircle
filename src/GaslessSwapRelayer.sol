// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title GaslessSwapRelayer
 * @dev Allows users with only USDC to execute swaps through a relayer
 */
contract GaslessSwapRelayer is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // USDC token
    address public immutable usdcToken;

    // Relayer fee in USDC (6 decimals)
    uint256 public relayerFee = 1000; // 0.001 USDC

    // Nonce tracking to prevent replay attacks
    mapping(address => uint256) public userNonces;

    // Events
    event SwapExecuted(
        address indexed user,
        address indexed relayer,
        uint256 usdcAmount,
        uint256 relayerFee,
        uint256 gasUsed
    );

    event RelayerFeeUpdated(uint256 newFee);

    constructor(address _usdcToken) Ownable(msg.sender) {
        usdcToken = _usdcToken;
    }

    /**
     * @dev Execute swap for user who has only USDC
     * @param user The user requesting the swap
     * @param swapData The swap data to execute
     * @param signature User's signature authorizing the swap
     * @param deadline Deadline for the swap
     */
    function executeSwapForUser(
        address user,
        bytes calldata swapData,
        bytes calldata signature,
        uint256 deadline
    ) external nonReentrant {
        require(block.timestamp <= deadline, "Swap expired");
        require(user != address(0), "Invalid user");

        // Verify user signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(user, swapData, deadline, userNonces[user])
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        address signer = ethSignedMessageHash.recover(signature);
        require(signer == user, "Invalid signature");

        // Increment nonce to prevent replay
        userNonces[user]++;

        // Calculate total USDC needed (swap amount + relayer fee)
        uint256 swapAmount = _extractSwapAmount(swapData);
        uint256 totalUsdcNeeded = swapAmount + relayerFee;

        // Check user has enough USDC
        require(
            IERC20(usdcToken).balanceOf(user) >= totalUsdcNeeded,
            "Insufficient USDC"
        );

        // Check user has approved this contract
        require(
            IERC20(usdcToken).allowance(user, address(this)) >= totalUsdcNeeded,
            "Insufficient USDC allowance"
        );

        // Transfer USDC from user
        IERC20(usdcToken).safeTransferFrom(
            user,
            address(this),
            totalUsdcNeeded
        );

        // Execute the swap (this would call the actual swap router)
        uint256 gasStart = gasleft();
        (bool success, ) = address(this).call(swapData);
        require(success, "Swap execution failed");
        uint256 gasUsed = gasStart - gasleft();

        // Transfer relayer fee to msg.sender (the relayer)
        IERC20(usdcToken).safeTransfer(msg.sender, relayerFee);

        emit SwapExecuted(user, msg.sender, swapAmount, relayerFee, gasUsed);
    }

    /**
     * @dev Extract swap amount from swap data
     * @param swapData The swap data
     * @return swapAmount The amount being swapped
     */
    function _extractSwapAmount(
        bytes calldata swapData
    ) internal pure returns (uint256) {
        // This is a simplified version - in practice you'd decode the actual swap data
        // For now, we'll assume the first 32 bytes contain the amount
        require(swapData.length >= 32, "Invalid swap data");
        return abi.decode(swapData[:32], (uint256));
    }

    /**
     * @dev Update relayer fee
     * @param newFee New fee in USDC (6 decimals)
     */
    function setRelayerFee(uint256 newFee) external onlyOwner {
        relayerFee = newFee;
        emit RelayerFeeUpdated(newFee);
    }

    /**
     * @dev Get user's current nonce
     * @param user The user address
     * @return nonce Current nonce
     */
    function getNonce(address user) external view returns (uint256) {
        return userNonces[user];
    }

    /**
     * @dev Emergency withdraw USDC
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        IERC20(usdcToken).safeTransfer(owner(), amount);
    }
}
