// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

import {BaseScript} from "./base/BaseScript.sol";
import "../src/Hook.sol";
// 0x68d99e5b7e75863ff68843bece98da4b8be440c0
// Sepoli paymaster 0x3BA9A96eE3eFf3A69E2B18886AcF52027EFF8966

/// @notice Mines the address and deploys the Counter.sol Hook contract
contract DeployHookScript is BaseScript {
    // address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant ARB_SEPOLIA_USDC_TESTNET = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant ARB_CIRCLE_PAYMASTER_INTEGRATION = 0xA17eE04CFf341ab9FC7397c3FF5E262D7EafFb6b;

    // address constant SEPOLIA_CIRCLE_PAYMASTER_INTEGRATION =
    // 0xdF6a271B2D5eE0Edf407081686Bef05EDb97d131;
    function run() public {
        // hook contracts must have specific flags encoded in the address
        // uint160 flags = uint160(
        //     Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        //         | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        // );

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs =
            abi.encode(poolManager, payable(ARB_CIRCLE_PAYMASTER_INTEGRATION), ARB_SEPOLIA_USDC_TESTNET);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(CirclePaymasterHook).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.startBroadcast();
        CirclePaymasterHook circlePaymasterHook = new CirclePaymasterHook{salt: salt}(
            poolManager, payable(ARB_CIRCLE_PAYMASTER_INTEGRATION), ARB_SEPOLIA_USDC_TESTNET
        );
        vm.stopBroadcast();

        console.log("pool manager", address(poolManager));
        console.log("Hook address:", address(circlePaymasterHook));

        require(address(circlePaymasterHook) == hookAddress, "DeployHookScript: Hook Address Mismatch");
    }
}
// == Logs ==

// == Logs ==
//   pool manager 0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317
//   Hook address: 0x56745b76A98FE5313C199080c1222Abe5a1440c0
