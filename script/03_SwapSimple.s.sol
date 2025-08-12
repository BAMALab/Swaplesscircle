// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import "forge-std/console.sol";

import {BaseScript} from "./base/BaseScript.sol";

contract SwapSimpleScript is BaseScript {
    function run() external {
        // Get the correctly sorted currencies from base class
        (Currency currency0, Currency currency1) = getCurrencies();

        // Use the existing pool with hooks
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 5000, // Matching the pool initialization parameters (0.50%)
            tickSpacing: 100, // Matching the pool initialization parameters
            hooks: IHooks(address(0)) // Let Try WITHOUT hooks first
        });

        // Get deployer address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Testing swap WITHOUT hooks first");
        console.log("Currency0 (sorted):", Currency.unwrap(currency0));
        console.log("Currency1 (sorted):", Currency.unwrap(currency1));

        // Check balances
        uint256 token0Balance = token0.balanceOf(deployer);
        uint256 token1Balance = token1.balanceOf(deployer);

        console.log("Deployer token0 balance:", token0Balance);
        console.log("Deployer token1 balance:", token1Balance);

        if (token0Balance == 0 && token1Balance == 0) {
            console.log("ERROR: Deployer has no tokens to swap!");
            return;
        }

        vm.startBroadcast();

        // Approve tokens for swap router
        token1.approve(address(swapRouter), type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);

        // Empty hook data
        bytes memory hookData = abi.encode(false);

        console.log("Attempting swap WITHOUT hooks");

        // Execute swap using the swap router
        swapRouter.swapExactTokensForTokens({
            amountIn: 1e15, // Even smaller amount: 0.001 tokens
            amountOutMin: 0,
            zeroForOne: false, // Swap currency1 for currency0
            poolKey: poolKey,
            hookData: hookData,
            receiver: deployer,
            deadline: block.timestamp + 3600
        });

        console.log("Swap WITHOUT hooks completed successfully!");

        vm.stopBroadcast();
    }
}
