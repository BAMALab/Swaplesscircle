// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {V4RouterDeployer} from "hookmate/artifacts/V4Router.sol";
import {BaseScript} from "./base/BaseScript.sol";
import "forge-std/console.sol";

/// @notice Deploys the V4Router contract to enable swapExactTokensForTokens functionality
contract DeployV4RouterScript is BaseScript {
    function run() external {
        console.log("Deploying V4Router...");
        console.log("PoolManager address:", address(poolManager));
        console.log("Permit2 address:", address(permit2));

        vm.startBroadcast();

        // Deploy the V4Router using the hookmate deployer
        address v4RouterAddress = V4RouterDeployer.deploy(address(poolManager), address(permit2));

        vm.stopBroadcast();

        console.log("V4Router deployed at:", v4RouterAddress);
        console.log("Update your BaseScript.sol to use this address for Arbitrum Sepolia!");
    }
}
