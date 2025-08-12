// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import "forge-std/console2.sol";

import {BaseScript} from "./base/BaseScript.sol";
import {LiquidityHelpers} from "./base/LiquidityHelpers.sol";

contract CreatePoolAndAddLiquidityScript is BaseScript, LiquidityHelpers {
    using CurrencyLibrary for Currency;

    /////////////////////////////////////
    // --- Configure These ---
    /////////////////////////////////////

    uint24 lpFee = 5000; // 0.50%
    int24 tickSpacing = 100;
    uint160 startingPrice = 2 ** 96; // Starting price, sqrtPriceX96; floor(sqrt(1) * 2^96)

    // --- liquidity position configuration --- //
    uint256 public token0Amount = 1e18;
    uint256 public token1Amount = 1e18;

    // range of the position, must be a multiple of tickSpacing
    int24 tickLower;
    int24 tickUpper;
    /////////////////////////////////////

    function run() external {
        // Use the sorted currencies from base class
        (Currency currency0, Currency currency1) = getCurrencies();

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });

        bytes memory hookData = new bytes(0);
        console2.log(address(poolManager), "pool");

        int24 currentTick = TickMath.getTickAtSqrtPrice(startingPrice);

        tickLower = ((currentTick - 750 * tickSpacing) / tickSpacing) * tickSpacing;
        tickUpper = ((currentTick + 750 * tickSpacing) / tickSpacing) * tickSpacing;

        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        // slippage limits
        uint256 amount0Max = token0Amount + 1;
        uint256 amount1Max = token1Amount + 1;

        (bytes memory actions, bytes[] memory mintParams) = _mintLiquidityParams(
            poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, deployerAddress, hookData
        );

        // multicall parameters
        bytes[] memory params = new bytes[](2);

        // Initialize Pool
        params[0] = abi.encodeWithSelector(positionManager.initializePool.selector, poolKey, startingPrice, hookData);

        // Mint Liquidity
        params[1] = abi.encodeWithSelector(
            positionManager.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 3600
        );

        // If the pool is an ETH pair, native tokens are to be transferred
        uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;
        // console2.log("positionManager", address(positionManager));
        vm.startBroadcast();
        tokenApprovals();

        // Multicall to atomically create pool & add liquidity
        positionManager.multicall{value: valueToPass}(params);
        vm.stopBroadcast();
    }
}

//  forge script script/01_CreatePoolAndAddLiquidity.s.sol:CreatePoolAndAddLiquidityScript --rpc-url https://sepolia.infura.io/v3/709bdd438a58422b891043c58e636a64 --broadcast --private-key $PRIVATE_KEY -vvvv
