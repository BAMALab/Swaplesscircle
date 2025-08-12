import "dotenv/config";
import { createPublicClient, http } from "viem";
import { arbitrumSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { signPermit } from "./permit.js";

const chain = arbitrumSepolia;
const ownerPrivateKey = process.env.OWNER_PRIVATE_KEY;
const paymasterAddress = "0x31BE08D380A21fc740883c0BC434FcFc88740b58";
const usdcAddress = "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d";

const client = createPublicClient({ chain, transport: http() });
const owner = privateKeyToAccount(ownerPrivateKey);

console.log("Testing permit signature...");
console.log("Owner address:", owner.address);
console.log("Paymaster address:", paymasterAddress);
console.log("USDC address:", usdcAddress);

try {
  const permitAmount = 10000000n; // 10 USDC

  const permitSignature = await signPermit({
    tokenAddress: usdcAddress,
    account: owner,
    client,
    spenderAddress: paymasterAddress,
    permitAmount: permitAmount,
  });

  console.log("✅ Permit signature created successfully!");
  console.log("Signature:", permitSignature);

  // Test the paymaster data encoding
  const { encodePacked } = await import("viem");
  const paymasterData = encodePacked(
    ["uint8", "address", "uint256", "bytes"],
    [0, usdcAddress, permitAmount, permitSignature]
  );

  console.log("✅ Paymaster data encoded successfully!");
  console.log("Paymaster data:", paymasterData);
} catch (error) {
  console.error("❌ Error creating permit signature:", error);
  process.exit(1);
}

console.log("✅ All tests passed!");
process.exit(0);
