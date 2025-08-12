// SPDX-Lincense-Identifier: MIT

pragma solidity 0.8.28;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";

// errors
error PayWithUSDC__InsufficientDeposit();
error PayWithUSDC__InvalidCaller();
error PayWithUSDC__GaslessNotRequested();
error PayWithUSDC__InvalidHookData();
error MustUseDynamicFee();

// interfaces, libraries, contracts
interface ICirclePaymaster {
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

    function validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        external
        returns (bytes memory context, uint256 validationData);

    function postOp(IPaymaster.PostOpMode mode, bytes calldata context, uint256 actualGasCost) external;

    function depositFor(address account) external payable;
    function getDeposit(address account) external view returns (uint256);
}

interface IPaymaster {
    enum PostOpMode {
        opSucceeded,
        opReverted,
        postOpReverted
    }
}

contract PayGasWithUSDCHook is BaseHook {
    using LPFeeLibrary for uint24;
    using SafeERC20 for IERC20;

    address public immutable USDC;
    ICirclePaymaster public immutable circlePaymaster;

    constructor(IPoolManager _manager)
        // address _usdc,
        // ICirclePaymaster _circlePaymaster
        BaseHook(_manager)
    {
        // USDC = _usdc;
        // circlePaymaster = _circlePaymaster;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // function beforeInitilize(address, PoolKey calldata key, uint160) external pure override returns (bytes4) {
    //     if(!key.fee.isDynamicFee()) {
    //         revert MustUseDynamicFee();
    //     }

    //     return this.beforeInitialize.selector;
    // }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // Your implementation here
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
}
