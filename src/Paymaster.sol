// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEntryPoint {
    function balanceOf(address account) external view returns (uint256);
    function depositTo(address account) external payable;
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external;
}

contract Paymaster is Ownable, ReentrancyGuard {
    // ERC-4337 UserOperation struct
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    enum PostOpMode {
        opSucceeded,
        opReverted,
        postOpReverted
    }

    // State variables
    IEntryPoint public immutable entryPoint;
    mapping(address => uint256) public deposits;
    mapping(address => bool) public authorizedHooks;

    // Configuration
    uint256 public constant PAYMASTER_VALIDATION_GAS_OFFSET = 20000;
    uint256 public constant PAYMASTER_POSTOP_GAS_OFFSET = 40000;
    uint256 public constant PAYMASTER_DATA_OFFSET = 20;

    // Events
    event DepositReceived(address indexed account, uint256 amount);
    event PaymasterUsed(address indexed sender, uint256 actualGasCost);
    event Withdrawn(address indexed account, uint256 amount);
    event HookAuthorized(address indexed hook, bool authorized);
    event USDCReimbursed(
        address indexed user,
        address indexed relayer,
        uint256 usdcAmount
    );

    // Errors
    error InsufficientDeposit();
    error UnauthorizedHook();
    error InvalidUserOperation();
    error PostOpFailed();

    constructor(IEntryPoint _entryPoint) Ownable(msg.sender) {
        entryPoint = _entryPoint;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint), "Only EntryPoint can call");
        _;
    }

    modifier onlyAuthorizedHook() {
        require(authorizedHooks[msg.sender], "Unauthorized hook");
        _;
    }

    modifier onlyAuthorizedHookOrOwner() {
        require(
            authorizedHooks[msg.sender] || msg.sender == owner(),
            "Not authorized"
        );
        _;
    }

    /**
     * @dev Validate a user operation and return validation data
     * @param userOp The user operation to validate
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost that the paymaster will pay
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    )
        external
        onlyEntryPoint
        returns (bytes memory context, uint256 validationData)
    {
        // Basic validation
        require(userOp.sender != address(0), "Invalid sender");
        require(maxCost > 0, "Invalid max cost");

        // Check if user has sufficient deposit
        uint256 userDeposit = deposits[userOp.sender];
        if (userDeposit < maxCost) {
            revert InsufficientDeposit();
        }

        // Reserve the gas cost from user's deposit
        deposits[userOp.sender] -= maxCost;

        // Create context for postOp
        context = abi.encode(userOp.sender, maxCost, block.timestamp);

        // Return success validation (0 means success)
        validationData = 0;

        return (context, validationData);
    }

    /**
     * @dev Post-operation handler called after user operation execution
     * @param mode The mode of the post operation (success, revert, etc.)
     * @param context Context data from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external onlyEntryPoint {
        (address sender, uint256 maxCost, uint256 timestamp) = abi.decode(
            context,
            (address, uint256, uint256)
        );

        // Handle different post-op modes
        if (mode == PostOpMode.opSucceeded) {
            // Operation succeeded - charge actual gas cost
            if (actualGasCost < maxCost) {
                // Refund the difference
                uint256 refund = maxCost - actualGasCost;
                deposits[sender] += refund;
            }

            emit PaymasterUsed(sender, actualGasCost);
        } else if (mode == PostOpMode.opReverted) {
            // Operation reverted - still charge gas cost but might apply different logic
            if (actualGasCost < maxCost) {
                uint256 refund = maxCost - actualGasCost;
                deposits[sender] += refund;
            }

            emit PaymasterUsed(sender, actualGasCost);
        } else {
            // PostOp reverted - refund everything
            deposits[sender] += maxCost;
        }
    }

    /**
     * @dev Deposit ETH for a specific account
     * @param account The account to deposit for
     */
    function depositFor(address account) external payable {
        require(account != address(0), "Invalid account");
        require(msg.value > 0, "Must send ETH");

        deposits[account] += msg.value;

        // Also deposit to EntryPoint for gas accounting
        entryPoint.depositTo{value: msg.value}(account);

        emit DepositReceived(account, msg.value);
    }

    /**
     * @dev Get deposit balance for an account
     * @param account The account to check
     */
    function getDeposit(address account) external view returns (uint256) {
        return deposits[account];
    }

    /**
     * @dev Withdraw deposit (only account owner can withdraw their own deposit)
     * @param withdrawAddress Address to withdraw to
     * @param amount Amount to withdraw
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 amount
    ) external nonReentrant {
        require(withdrawAddress != address(0), "Invalid withdraw address");
        require(amount > 0, "Invalid amount");
        require(deposits[msg.sender] >= amount, "Insufficient balance");

        deposits[msg.sender] -= amount;

        // Transfer the funds
        (bool success, ) = withdrawAddress.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Authorize or deauthorize a hook contract
     * @param hook The hook contract address
     * @param authorized Whether to authorize or deauthorize
     */
    function setAuthorizedHook(
        address hook,
        bool authorized
    ) external onlyOwner {
        authorizedHooks[hook] = authorized;
        emit HookAuthorized(hook, authorized);
    }

    /**
     * @dev Add stake to EntryPoint (required for paymaster)
     * @param unstakeDelaySec Unstake delay in seconds
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @dev Get the deposit of this paymaster in the EntryPoint
     */
    function getEntryPointDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /**
     * @dev Emergency withdrawal function (only owner)
     * @param to Address to send funds to
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address payable to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(amount <= address(this).balance, "Insufficient balance");

        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev Batch deposit for multiple accounts (useful for testing)
     * @param accounts Array of accounts to deposit for
     * @param amounts Array of amounts to deposit for each account
     */
    function batchDeposit(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external payable onlyOwner {
        require(accounts.length == amounts.length, "Array length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
            deposits[accounts[i]] += amounts[i];
            emit DepositReceived(accounts[i], amounts[i]);
        }

        require(msg.value == totalAmount, "Insufficient ETH sent");

        // Deposit total to EntryPoint
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @dev Check if an address is an authorized hook
     */
    function isAuthorizedHook(address hook) external view returns (bool) {
        return authorizedHooks[hook];
    }

    /**
     * @dev Get contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Reimburse a relayer in USDC for paying gas on behalf of a user.
     * @param user The user who is paying in USDC
     * @param relayer The relayer who paid ETH gas
     * @param usdc The USDC token address
     * @param usdcAmount The amount of USDC to reimburse
     */
    function reimburseRelayerInUSDC(
        address user,
        address relayer,
        address usdc,
        uint256 usdcAmount
    ) external onlyAuthorizedHookOrOwner {
        require(user != address(0) && relayer != address(0), "Invalid address");
        require(usdcAmount > 0, "Zero amount");
        require(
            IERC20(usdc).allowance(user, address(this)) >= usdcAmount,
            "Insufficient allowance"
        );
        require(
            IERC20(usdc).balanceOf(user) >= usdcAmount,
            "Insufficient USDC"
        );
        bool success = IERC20(usdc).transferFrom(user, relayer, usdcAmount);
        require(success, "USDC transfer failed");
        emit USDCReimbursed(user, relayer, usdcAmount);
    }

    // Receive ETH
    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }

    // Fallback function
    fallback() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }
}
