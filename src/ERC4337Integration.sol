// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ERC4337Integration
 * @dev Integration for true gasless transactions using Circle's Paymaster
 * This allows users to perform swaps without any ETH, only USDC
 */
contract ERC4337Integration is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Circle Paymaster v0.8 address for Base Sepolia
    address public constant CIRCLE_PAYMASTER =
        0x3BA9A96eE3eFf3A69E2B18886AcF52027EFF8966;

    // USDC token
    address public immutable usdcToken;

    // Events
    event GaslessSwapRequested(
        address indexed user,
        bytes32 indexed swapHash,
        uint256 usdcAmount
    );

    event SwapCompleted(
        address indexed user,
        bytes32 indexed swapHash,
        uint256 actualUsdcCost
    );

    constructor(address _usdcToken) Ownable(msg.sender) {
        usdcToken = _usdcToken;
    }

    /**
     * @dev Request a gasless swap (to be submitted by bundler)
     * @param target The contract to call (swap router)
     * @param data The call data for the swap
     * @param usdcAmount The amount of USDC to pay for gas
     */
    function requestGaslessSwap(
        address target,
        bytes calldata data,
        uint256 usdcAmount
    ) external {
        // Validate inputs
        require(target != address(0), "Invalid target");
        require(data.length > 0, "Empty call data");
        require(usdcAmount > 0, "Invalid USDC amount");

        // Check user has enough USDC
        require(
            IERC20(usdcToken).balanceOf(msg.sender) >= usdcAmount,
            "Insufficient USDC"
        );

        // Check user has approved this contract
        require(
            IERC20(usdcToken).allowance(msg.sender, address(this)) >=
                usdcAmount,
            "Insufficient USDC allowance"
        );

        // Transfer USDC from user to this contract
        IERC20(usdcToken).safeTransferFrom(
            msg.sender,
            address(this),
            usdcAmount
        );

        // Create swap hash
        bytes32 swapHash = keccak256(
            abi.encodePacked(
                msg.sender,
                target,
                data,
                usdcAmount,
                block.timestamp
            )
        );

        emit GaslessSwapRequested(msg.sender, swapHash, usdcAmount);
    }

    /**
     * @dev Execute the swap (called by bundler)
     * @param user The user who requested the swap
     * @param target The contract to call
     * @param data The call data
     * @param swapHash The hash of the swap request
     */
    function executeSwap(
        address user,
        address target,
        bytes calldata data,
        bytes32 swapHash
    ) external onlyOwner {
        // Validate the swap request
        require(user != address(0), "Invalid user");
        require(target != address(0), "Invalid target");

        // Execute the swap
        (bool success, ) = target.call(data);
        require(success, "Swap execution failed");

        emit SwapCompleted(user, swapHash, 0);
    }

    /**
     * @dev Get the required USDC amount for gas
     * @param gasLimit The estimated gas limit
     */
    function getRequiredUsdcForGas(
        uint256 gasLimit
    ) external view returns (uint256) {
        // Estimate gas cost (assuming 1 gwei gas price)
        uint256 gasPrice = 1000000000; // 1 gwei
        uint256 ethCost = gasLimit * gasPrice;

        // Convert to USDC (assuming 1 ETH = 3000 USDC)
        return (ethCost * 3000) / 1e18;
    }

    /**
     * @dev Withdraw USDC from contract (emergency)
     */
    function withdrawUsdc(uint256 amount) external onlyOwner {
        IERC20(usdcToken).safeTransfer(owner(), amount);
    }
}
