// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/interfaces/IERC20.sol";

contract ApproveUSDCScript is Script {
    // USDC token address on Arbitrum Sepolia
    address constant USDC_TOKEN = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    // Circle Paymaster Integration address
    address constant ARB_CIRCLE_PAYMASTER_INTEGRATION = 0xA17eE04CFf341ab9FC7397c3FF5E262D7EafFb6b;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployer);

        console.log("Deployer address:", deployer);
        console.log("USDC token address:", USDC_TOKEN);
        console.log("Circle Paymaster Integration address:", ARB_CIRCLE_PAYMASTER_INTEGRATION);

        // Check current USDC balance
        uint256 balance = IERC20(USDC_TOKEN).balanceOf(deployer);
        console.log("Current USDC balance:", balance);

        // Check current allowance
        uint256 allowance = IERC20(USDC_TOKEN).allowance(deployer, ARB_CIRCLE_PAYMASTER_INTEGRATION);
        console.log("Current allowance:", allowance);

        // Approve USDC spending for the CirclePaymasterIntegration contract
        IERC20(USDC_TOKEN).approve(ARB_CIRCLE_PAYMASTER_INTEGRATION, type(uint256).max);

        console.log("Approved USDC spending for CirclePaymasterIntegration");

        // Verify the approval
        uint256 newAllowance = IERC20(USDC_TOKEN).allowance(deployer, ARB_CIRCLE_PAYMASTER_INTEGRATION);
        console.log("New allowance:", newAllowance);

        vm.stopBroadcast();
    }
}
