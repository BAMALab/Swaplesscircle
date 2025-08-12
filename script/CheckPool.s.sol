// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "forge-std/console.sol";

import {BaseScript} from "./base/BaseScript.sol";

contract CheckPoolScript is BaseScript {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    function run() external {
        // Get the correctly sorted currencies from base class
        (Currency currency0, Currency currency1) = getCurrencies();

        // Use the same pool configuration as other scripts
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 5000, // 0.50%
            tickSpacing: 100,
            hooks: hookContract
        });

        PoolId poolId = poolKey.toId();

        console.log("Pool ID:", vm.toString(PoolId.unwrap(poolId)));
        console.log("Currency0:", Currency.unwrap(currency0));
        console.log("Currency1:", Currency.unwrap(currency1));
        console.log("Fee:", poolKey.fee);
        console.log("Hook address:", address(poolKey.hooks));

        // Check if pool is initialized
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 == 0) {
            console.log("Pool does not exist or is not initialized!");
            console.log("You need to run the CreatePoolAndAddLiquidity script first");
        } else {
            console.log("Pool exists!");
            console.log("Current sqrtPriceX96:", sqrtPriceX96);
            console.log("Current tick:", vm.toString(tick));
            console.log("Protocol fee:", protocolFee);
            console.log("LP fee:", lpFee);

            // Check liquidity
            uint128 liquidity = poolManager.getLiquidity(poolId);
            console.log("Pool liquidity:", liquidity);

            if (liquidity == 0) {
                console.log("WARNING: Pool has no liquidity!");
            } else {
                console.log("Pool has liquidity - should be able to swap");
            }
        }
    }
}
