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
import { getContract } from "viem";


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


const usdc = getContract({ client, address: usdcAddress, abi: erc20Abi });
const usdcBalance = await usdc.read.balanceOf([account.address]);

if (usdcBalance < 1000000) {
  console.log(
    `Fund ${account.address} with USDC on ${client.chain.name} using https://faucet.circle.com, then run this again.`,
  );
  process.exit();
}
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
        [0, usdcAddress, permitAmount, permitSignature],
      );
  
      return {
        paymaster: paymasterAddress,
        paymasterData,
        paymasterVerificationGasLimit: 200000n,
        paymasterPostOpGasLimit: 15000n,
        isFinal: true,
      };
    },
  };

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


  const authorization = await owner.signAuthorization({
    chainId: chain.id,
    nonce: await client.getTransactionCount({ address: owner.address }),
    contractAddress: account.authorization.address,
  });
  
  const hash = await bundlerClient.sendUserOperation({
    account,
    calls: [
      {
        to: usdc.address,
        abi: usdc.abi,
        functionName: "transfer",
        args: [recipientAddress, 10000n],
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