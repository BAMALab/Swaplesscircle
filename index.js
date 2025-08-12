import "dotenv/config";
import {
  createPublicClient,
  http,
  createWalletClient,
  encodeAbiParameters,
  encodeFunctionData,
} from "viem";
import { sepolia, arbitrumSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import {
  createBundlerClient,
  toSimple7702SmartAccount,
} from "viem/account-abstraction";
import { readFile } from "fs/promises";
import { erc20Abi } from "viem";
import { signPermit } from "./permit.js";

const routerAbi = JSON.parse(
  await readFile(new URL("./abi.json", import.meta.url))
);
import { hexToBigInt, encodePacked } from "viem";

// const chain = sepolia;
const chain = arbitrumSepolia;
const usdcAddress = "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d";
const ownerPrivateKey = process.env.OWNER_PRIVATE_KEY;
const recipientAddress = process.env.RECIPIENT_ADDRESS;
const swapAddress = "0xCD0b7d5ECd5279D946F99d98633E1942893C3573"; // Deployed V4 Router

// Official Circle Paymaster v0.7 addresses from Circle documentation
const paymasterAddress = "0x3BA9A96eE3eFf3A69E2B18886AcF52027EFF8966";
const ENTRYPOINT_V07 = "0x0000000071727De22E5E9d8BAf0edAc6f37da032";

const client = createPublicClient({ chain, transport: http() });
const owner = privateKeyToAccount(ownerPrivateKey);
const account = await toSimple7702SmartAccount({ client, owner });

const amountIn = 1000000n; // 1 USDC (6 decimals)
const amountOutMin = 0n;
const zeroForOne = true;
const fee = 5000;
const tickSpacing = 100;
const hooks = "0x75c4cD5D01368F89E4957e67867275DDEBE740C0"; // Deployed Hook contract
const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now
const userAddress = "0x9dBa18e9b96b905919cC828C399d313EfD55D800";

console.log("Account address:", account.address);
console.log("Owner address:", owner.address);
console.log("Swap address:", swapAddress);

const paymaster = {
  async getPaymasterData(parameters) {
    const permitAmount = 10000000n;
    const permitSignature = await signPermit({
      tokenAddress: usdcAddress,
      account,
      client,
      spenderAddress: paymasterAddress,
      permitAmount: permitAmount,
    });

    const paymasterData = encodePacked(
      ["uint8", "address", "uint256", "bytes"],
      [0, usdcAddress, permitAmount, permitSignature]
    );

    return {
      paymaster: paymasterAddress,
      paymasterData,
      paymasterVerificationGasLimit: 300000n,
      paymasterPostOpGasLimit: 20000n,
      isFinal: true,
    };
  },
};

// Create bundler client WITHOUT paymaster for testing
const bundlerClient = createBundlerClient({
  account,
  client,
  paymaster,
  userOperation: {
    estimateFeesPerGas: async ({ account, bundlerClient, userOperation }) => {
      const { standard: fees } = await bundlerClient.request({
        method: "pimlico_getUserOperationGasPrice",
      });
      const maxFeePerGas = hexToBigInt(fees.maxFeePerGas);
      const maxPriorityFeePerGas = hexToBigInt(fees.maxPriorityFeePerGas);
      return { maxFeePerGas, maxPriorityFeePerGas };
    },
  },
  transport: http(`https://public.pimlico.io/v2/${client.chain.id}/rpc`),
});

// Use the same tokens as in the successful swap transaction
const poolKey = [
  "0x00571860bB39C639e8aAD55B4E95D36BE228ae11", // Token1 from successful swap
  "0x6d521a93A3B1fEF995026eBD537405EBD4A1E481", // Token0 from successful swap
  fee,
  tickSpacing,
  hooks,
];
const hookData = encodeAbiParameters(
  [
    { name: "useGaslessMode", type: "bool" },
    { name: "actualUser", type: "address" },
  ],
  [true, userAddress] // gasless mode, user address
);

console.log("Pool key:", poolKey);
console.log("Hook data:", hookData);

const authorization = await owner.signAuthorization({
  chainId: chain.id,
  nonce: await client.getTransactionCount({ address: owner.address }),
  contractAddress: account.authorization.address,
});

// console.log("Sending user operation WITHOUT paymaster...");

const hash = await bundlerClient.sendUserOperation({
  account,
  calls: [
    {
      to: swapAddress,
      abi: routerAbi,
      functionName: "swapExactTokensForTokens",
      args: [
        amountIn,
        amountOutMin,
        zeroForOne,
        poolKey,
        hookData,
        recipientAddress,
        deadline,
      ],
    },
  ],
  authorization: authorization,
});
console.log("UserOperation hash", hash);

const receipt = await bundlerClient.waitForUserOperationReceipt({ hash });
console.log("Transaction hash", receipt.receipt.transactionHash);

// We need to manually exit the process, since viem leaves some promises on the
// event loop for features we're not using.
process.exit();
