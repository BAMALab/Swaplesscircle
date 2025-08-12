// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/CirclePaymaster.sol";
import "../src/Hook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

contract DeploySepolia is Script {
    // Sepolia Testnet Configuration
    // address constant SEPOLIA_CIRCLE_PAYMASTER =
    //     0x3BA9A96eE3eFf3A69E2B18886AcF52027EFF8966;
    // address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    // address constant SEPOLIA_PRICE_ORACLE =
    //     0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // Arbitrum Sepolia Testnet Configuration
    address constant ARB_SEPOLIA_USDC_TESTNET = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant ARBITRUM_SEPOLIA_PRICE_ORACLE = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address ARBITRUM_SEPOLIA_CIRCLE_PAYMASTER = 0x31BE08D380A21fc740883c0BC434FcFc88740b58;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING TO SEPOLIA TESTNET ===");
        console.log("Deployer:", deployer);
        console.log("Circle Paymaster:", ARBITRUM_SEPOLIA_CIRCLE_PAYMASTER);
        console.log("USDC:", ARB_SEPOLIA_USDC_TESTNET);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Circle Paymaster Integration
        CirclePaymasterIntegration circlePaymasterIntegration = new CirclePaymasterIntegration(
            ARBITRUM_SEPOLIA_CIRCLE_PAYMASTER, ARB_SEPOLIA_USDC_TESTNET, ARBITRUM_SEPOLIA_PRICE_ORACLE
        );

        console.log("Circle Paymaster Integration deployed at:", address(circlePaymasterIntegration));

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Sepolia Testnet");
        console.log("Circle Paymaster Integration:", address(circlePaymasterIntegration));
        console.log("Circle Paymaster Address:", ARBITRUM_SEPOLIA_CIRCLE_PAYMASTER);
        console.log("USDC Address:", ARB_SEPOLIA_USDC_TESTNET);
        console.log("========================\n");
    }
}

// == Logs ==
//   === DEPLOYING TO SEPOLIA TESTNET ===
//   Deployer: 0x9dBa18e9b96b905919cC828C399d313EfD55D800
//   Circle Paymaster: 0x31BE08D380A21fc740883c0BC434FcFc88740b58
//   USDC: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
//   Circle Paymaster Integration deployed at: 0xA17eE04CFf341ab9FC7397c3FF5E262D7EafFb6b
  
// === DEPLOYMENT SUMMARY ===
//   Network: Sepolia Testnet
//   Circle Paymaster Integration: 0xA17eE04CFf341ab9FC7397c3FF5E262D7EafFb6b
//   Circle Paymaster Address: 0x31BE08D380A21fc740883c0BC434FcFc88740b58
//   USDC Address: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
//   ========================