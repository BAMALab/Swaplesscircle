// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../src/oracle/DataConsumerV3.sol";
import "forge-std/console.sol";

/**
 * @title CirclePaymasterIntegration
 * @dev Integration contract for Circle's ERC-4337 Paymaster service
 * Allows users to pay gas fees in USDC instead of native tokens
 *
 * Circle Paymaster Addresses:
 * - Arbitrum Mainnet: 0x6C973eBe80dCD8660841D4356bf15c32460271C9
 * - Arbitrum Testnet: 0x31BE08D380A21fc740883c0BC434FcFc88740b58
 * - Base Mainnet: 0x6C973eBe80dCD8660841D4356bf15c32460271C9
 * - Base Testnet: 0x31BE08D380A21fc740883c0BC434FcFc88740b58
 */
contract CirclePaymasterIntegration is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Circle Paymaster contract addresses
    address public immutable circlePaymaster;
    address public immutable usdcToken;

    // Gas estimation constants
    uint256 public constant BASE_GAS_COST = 21000;
    uint256 public constant SWAP_GAS_OVERHEAD = 150000;

    DataConsumerV3 public immutable ORACLE;

    // Events
    event GasPaymentProcessed(
        address indexed user,
        uint256 usdcAmount,
        uint256 gasUsed
    );

    event PaymasterDeposit(address indexed user, uint256 amount);
    event RelayerReimbursed(
        address indexed user,
        address indexed relayer,
        uint256 usdcAmount
    );

    // User gas payment tracking
    mapping(address => uint256) public userGasDeposits;
    mapping(address => bool) public authorizedCallers;

    constructor(
        address _circlePaymaster,
        address _usdcToken,
        address _oracle
    ) Ownable(msg.sender) {
        circlePaymaster = _circlePaymaster;
        usdcToken = _usdcToken;
        ORACLE = DataConsumerV3(_oracle);
    }

    /**
     * @dev Estimate gas cost for a swap operation
     * @param user The user performing the swap
     * @return ethCost Estimated ETH cost
     * @return usdcCost Estimated USDC cost
     */
    function getGasEstimate(
        address user
    ) external view returns (uint256 ethCost, uint256 usdcCost) {
        ethCost = _estimateGasCost();
        usdcCost = _convertEthToUsdc(ethCost);
    }

    /**
     * @dev Process gas payment in USDC for a user operation
     * @param user The user paying for gas
     * @param gasLimit The gas limit for the operation
     */
    function processGasPayment(
        address user,
        uint256 gasLimit
    ) external onlyAuthorizedCaller {
        uint256 estimatedGas = _estimateGasCost();
        uint256 usdcRequired = _convertEthToUsdc(estimatedGas);

        // Check user has enough USDC
        require(
            IERC20(usdcToken).balanceOf(user) >= usdcRequired,
            "Insufficient USDC for gas payment"
        );

        // Check user has approved this contract to spend USDC
        require(
            IERC20(usdcToken).allowance(user, address(this)) >= usdcRequired,
            "Insufficient USDC allowance"
        );

        // Transfer USDC from user to this contract
        IERC20(usdcToken).safeTransferFrom(user, address(this), usdcRequired);

        // Store the gas deposit
        userGasDeposits[user] += usdcRequired;

        console.log("USDC deposited for gas payment:", usdcRequired);
        emit GasPaymentProcessed(user, usdcRequired, estimatedGas);
    }

    /**
     * @dev Reimburse a relayer in USDC for paying gas on behalf of a user
     * @param user The user who is paying in USDC
     * @param relayer The relayer who paid ETH gas
     * @param usdcAmount The amount of USDC to reimburse
     */
    function reimburseRelayerInUSDC(
        address user,
        address relayer,
        uint256 usdcAmount
    ) external onlyAuthorizedCaller {
        require(user != address(0) && relayer != address(0), "Invalid address");
        require(usdcAmount > 0, "Zero amount");

        // Check if user has enough USDC deposit
        require(
            userGasDeposits[user] >= usdcAmount,
            "Insufficient USDC deposit"
        );

        // Deduct from user's deposit
        userGasDeposits[user] -= usdcAmount;

        // Transfer USDC to relayer
        IERC20(usdcToken).safeTransfer(relayer, usdcAmount);

        emit RelayerReimbursed(user, relayer, usdcAmount);
    }

    /**
     * @dev Deposit ETH to Circle Paymaster for a user
     * @param user The user to deposit for
     * @param amount The amount of ETH to deposit
     */
    function depositToCirclePaymaster(
        address user,
        uint256 amount
    ) external payable onlyAuthorizedCaller {
        require(user != address(0), "Invalid user");
        require(msg.value == amount, "Incorrect ETH amount");

        // Call Circle Paymaster's depositFor function
        (bool success, ) = circlePaymaster.call{value: amount}(
            abi.encodeWithSignature("depositFor(address)", user)
        );
        require(success, "Circle Paymaster deposit failed");

        emit PaymasterDeposit(user, amount);
    }

    /**
     * @dev Get user's USDC gas deposit balance
     * @param user The user to check
     */
    function getUserGasDeposit(address user) external view returns (uint256) {
        return userGasDeposits[user];
    }

    /**
     * @dev Get Circle Paymaster deposit for a user
     * @param user The user to check
     */
    function getCirclePaymasterDeposit(
        address user
    ) external view returns (uint256) {
        (bool success, bytes memory data) = circlePaymaster.staticcall(
            abi.encodeWithSignature("getDeposit(address)", user)
        );
        require(success, "Failed to get Circle Paymaster deposit");
        return abi.decode(data, (uint256));
    }

    /**
     * @dev Returns the USDC/ETH rate (hardcoded for reliability)
     * @return Rate with 6 decimals representing USDC per ETH
     */
    function usdcToEthRate() external view returns (uint256) {
        // Try to get the rate from the oracle
        try ORACLE.getChainlinkDataFeedLatestAnswer() returns (
            int256 ethUsdPrice
        ) {
            require(ethUsdPrice > 0, "Invalid ETH/USD price");

            // Convert ETH/USD to USDC/ETH rate
            // USDC/ETH = ETH/USD * 1e6 (since USDC has 6 decimals)
            return uint256(ethUsdPrice) * 1e6;
        } catch {
            // Fallback to a hardcoded rate if oracle fails
            // This is a rough estimate: 1 ETH = 2000 USDC (with 6 decimals)
            return 3500 * 1e6; // 2000 USDC with 6 decimals
        }
    }

    /**
     * @dev Withdraw user's USDC gas deposit
     * @param user The user to withdraw for
     * @param amount The amount to withdraw
     */
    function withdrawUserGasDeposit(
        address user,
        uint256 amount
    ) external onlyAuthorizedCaller {
        require(userGasDeposits[user] >= amount, "Insufficient deposit");

        userGasDeposits[user] -= amount;
        IERC20(usdcToken).safeTransfer(user, amount);
    }

    function setAuthorizedCaller(
        address caller,
        bool authorized
    ) external onlyOwner {
        authorizedCallers[caller] = authorized;
    }

    // Emergency functions
    function emergencyWithdrawUsdc(uint256 amount) external onlyOwner {
        IERC20(usdcToken).safeTransfer(owner(), amount);
    }

    function emergencyWithdrawEth(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    // Internal functions
    function _estimateGasCost() private view returns (uint256) {
        // Use a fixed gas price instead of tx.gasprice to avoid issues in gasless transactions
        uint256 gasPrice = 1e9; // 1 gwei as a reasonable estimate
        return (BASE_GAS_COST + SWAP_GAS_OVERHEAD) * gasPrice;
    }

    function _convertEthToUsdc(
        uint256 ethAmount
    ) private view returns (uint256) {
        // Use hardcoded rate for reliability
        // 1 ETH = 3000 USDC
        // ethAmount is in wei (18 decimals)
        // We want USDC with 6 decimals
        // Formula: (ethAmount * 3000 * 1e6) / 1e18
        return (ethAmount * 3000 * 1e6) / 1e18;
    }

    // Modifiers
    modifier onlyAuthorizedCaller() {
        require(
            authorizedCallers[msg.sender] || msg.sender == owner(),
            "Not authorized"
        );
        _;
    }

    // Receive ETH for Circle Paymaster operations
    receive() external payable {}
}
