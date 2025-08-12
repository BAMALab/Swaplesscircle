// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/CirclePaymaster.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DepositUSDCForGasScript is Script {
    // Always update these addresses to match your deployment
    address constant CIRCLE_PAYMASTER_INTEGRATION = 0xA17eE04CFf341ab9FC7397c3FF5E262D7EafFb6b;
    address constant USDC_TOKEN = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    // Amount of USDC to deposit for gas payments (in wei - 6 decimals)
    uint256 constant USDC_DEPOSIT_AMOUNT = 3000000; // 3 USDC (user has ~3.922 USDC)

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployer);

        console.log("=== DEPOSITING USDC FOR GAS PAYMENTS ===");
        console.log("User:", deployer);
        console.log("Circle Paymaster Integration:", CIRCLE_PAYMASTER_INTEGRATION);
        console.log("USDC Token:", USDC_TOKEN);
        console.log("Deposit Amount:", USDC_DEPOSIT_AMOUNT, "USDC (wei)");

        // Get USDC token contract
        IERC20 usdc = IERC20(USDC_TOKEN);

        // Check current USDC balance
        uint256 currentBalance = usdc.balanceOf(deployer);
        console.log("Current USDC balance:", currentBalance);

        if (currentBalance < USDC_DEPOSIT_AMOUNT) {
            console.log("Insufficient USDC balance!");
            console.log("Required:", USDC_DEPOSIT_AMOUNT);
            console.log("Available:", currentBalance);
            revert("Insufficient USDC balance");
        }

        // Check current allowance
        uint256 currentAllowance = usdc.allowance(deployer, CIRCLE_PAYMASTER_INTEGRATION);
        console.log("Current allowance:", currentAllowance);

        // Approve USDC spending if needed
        if (currentAllowance < USDC_DEPOSIT_AMOUNT) {
            console.log("Approving USDC spending...");
            usdc.approve(CIRCLE_PAYMASTER_INTEGRATION, USDC_DEPOSIT_AMOUNT);
            console.log("USDC approved for spending");
        }

        // Get Circle Paymaster Integration contract
        CirclePaymasterIntegration paymasterIntegration =
            CirclePaymasterIntegration(payable(CIRCLE_PAYMASTER_INTEGRATION));

        // Check current gas deposit
        uint256 currentDeposit = paymasterIntegration.getUserGasDeposit(deployer);
        console.log("Current gas deposit:", currentDeposit);

        // Process gas payment (this will transfer USDC and create a deposit)
        console.log("Processing gas payment deposit...");
        paymasterIntegration.processGasPayment(deployer, 200000); // 200k gas limit

        // Check new deposit amount
        uint256 newDeposit = paymasterIntegration.getUserGasDeposit(deployer);
        console.log("New gas deposit:", newDeposit);

        console.log("USDC deposited successfully for gas payments!");

        vm.stopBroadcast();

        console.log("\n=== DEPOSIT SUMMARY ===");
        console.log("User:", deployer);
        console.log("USDC Deposited:", USDC_DEPOSIT_AMOUNT);
        console.log("Total Gas Deposit:", newDeposit);
        console.log("========================\n");
    }
}
