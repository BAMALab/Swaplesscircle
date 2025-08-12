// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/CirclePaymaster.sol";

contract AuthorizeHookScript is Script {
    // Always update this to the latest deployed hook address
    address constant HOOK_CONTRACT = 0x75c4cD5D01368F89E4957e67867275DDEBE740C0;

    //Always update this to the latest deployed Circle Paymaster Integration address
    address constant ARB_CIRCLE_PAYMASTER_INTEGRATION = 0xA17eE04CFf341ab9FC7397c3FF5E262D7EafFb6b;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployer);

        console.log("Authorizing hook contract:", HOOK_CONTRACT);
        console.log("Circle Paymaster Integration:", ARB_CIRCLE_PAYMASTER_INTEGRATION);

        // Cast to CirclePaymasterIntegration and authorize the hook
        CirclePaymasterIntegration paymaster = CirclePaymasterIntegration(payable(ARB_CIRCLE_PAYMASTER_INTEGRATION));
        paymaster.setAuthorizedCaller(HOOK_CONTRACT, true);

        console.log("Hook authorized successfully!");

        vm.stopBroadcast();
    }
}
