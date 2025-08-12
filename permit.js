// import { maxUint256, erc20Abi, parseErc6492Signature, getContract } from "viem";

// // Adapted from https://github.com/vacekj/wagmi-permit/blob/main/src/permit.ts
// export async function eip2612Permit({
//   token,
//   chain,
//   ownerAddress,
//   spenderAddress,
//   value,
// }) {
//   try {
//     const name = await token.read.name();
//     const nonce = await token.read.nonces([ownerAddress]);

//     console.log("[permit.js] Token name:", name);
//     console.log("[permit.js] Nonce:", nonce);

//     const domain = {
//       name: name, // Use actual token name instead of hardcoded
//       version: "2", // USDC's EIP-2612 version
//       chainId: chain.id,
//       verifyingContract: token.address,
//     };

//     // Use a reasonable deadline instead of maxUint256
//     const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now

//     const message = {
//       owner: ownerAddress,
//       spender: spenderAddress,
//       value,
//       nonce,
//       deadline,
//     };

//     console.log("[permit.js] Permit domain:", domain);
//     console.log("[permit.js] Permit message:", message);

//     return {
//       types: {
//         Permit: [
//           { name: "owner", type: "address" },
//           { name: "spender", type: "address" },
//           { name: "value", type: "uint256" },
//           { name: "nonce", type: "uint256" },
//           { name: "deadline", type: "uint256" },
//         ],
//       },
//       primaryType: "Permit",
//       domain,
//       message,
//     };
//   } catch (error) {
//     console.error("[permit.js] Error creating permit data:", error);
//     throw error;
//   }
// }

// export const eip2612Abi = [
//   ...erc20Abi,
//   {
//     inputs: [
//       {
//         internalType: "address",
//         name: "owner",
//         type: "address",
//       },
//     ],
//     stateMutability: "view",
//     type: "function",
//     name: "nonces",
//     outputs: [
//       {
//         internalType: "uint256",
//         name: "",
//         type: "uint256",
//       },
//     ],
//   },
//   {
//     inputs: [],
//     name: "version",
//     outputs: [{ internalType: "string", name: "", type: "string" }],
//     stateMutability: "view",
//     type: "function",
//   },
// ];

// export async function signPermit({
//   tokenAddress,
//   client,
//   account,
//   spenderAddress,
//   permitAmount,
// }) {
//   try {
//     console.log("[permit.js] Creating permit for token:", tokenAddress);
//     console.log("[permit.js] Spender:", spenderAddress);
//     console.log("[permit.js] Amount:", permitAmount);

//     const token = getContract({
//       client,
//       address: tokenAddress,
//       abi: eip2612Abi,
//     });

//     const permitData = await eip2612Permit({
//       token,
//       chain: client.chain,
//       ownerAddress: account.address,
//       spenderAddress,
//       value: permitAmount,
//     });

//     console.log("[permit.js] Signing permit data...");
//     const wrappedPermitSignature = await account.signTypedData(permitData);
//     console.log("[permit.js] Raw signature:", wrappedPermitSignature);

//     const isValid = await client.verifyTypedData({
//       ...permitData,
//       address: account.address,
//       signature: wrappedPermitSignature,
//     });

//     console.log("[permit.js] Signature valid:", isValid);

//     if (!isValid) {
//       throw new Error(
//         `Invalid permit signature for ${account.address}: ${wrappedPermitSignature}`
//       );
//     }

//     const { signature } = parseErc6492Signature(wrappedPermitSignature);
//     console.log("[permit.js] Parsed signature:", signature);

//     return signature;
//   } catch (error) {
//     console.error("[permit.js] Error in signPermit:", error);
//     throw error;
//   }
// }
import { maxUint256, erc20Abi, parseErc6492Signature, getContract } from "viem";

// Adapted from https://github.com/vacekj/wagmi-permit/blob/main/src/permit.ts
export async function eip2612Permit({
  token,
  chain,
  ownerAddress,
  spenderAddress,
  value,
}) {
  return {
    types: {
      // Required for compatibility with Circle PW Sign Typed Data API
      EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        { name: "chainId", type: "uint256" },
        { name: "verifyingContract", type: "address" },
      ],
      Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    },
    primaryType: "Permit",
    domain: {
      name: await token.read.name(),
      version: await token.read.version(),
      chainId: chain.id,
      verifyingContract: token.address,
    },
    message: {
      // Convert bigint fields to string to match EIP-712 JSON schema expectations
      owner: ownerAddress,
      spender: spenderAddress,
      value: value.toString(),
      nonce: (await token.read.nonces([ownerAddress])).toString(),
      // The paymaster cannot access block.timestamp due to 4337 opcode
      // restrictions, so the deadline must be MAX_UINT256.
      deadline: maxUint256.toString(),
    },
  };
}

export const eip2612Abi = [
  ...erc20Abi,
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
    name: "nonces",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
  },
  {
    inputs: [],
    name: "version",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    stateMutability: "view",
    type: "function",
  },
];

export async function signPermit({
  tokenAddress,
  client,
  account,
  spenderAddress,
  permitAmount,
}) {
  const token = getContract({
    client,
    address: tokenAddress,
    abi: eip2612Abi,
  });
  const permitData = await eip2612Permit({
    token,
    chain: client.chain,
    ownerAddress: account.address,
    spenderAddress,
    value: permitAmount,
  });

  const wrappedPermitSignature = await account.signTypedData(permitData);

  const isValid = await client.verifyTypedData({
    ...permitData,
    address: account.address,
    signature: wrappedPermitSignature,
  });

  if (!isValid) {
    throw new Error(
      `Invalid permit signature for ${account.address}: ${wrappedPermitSignature}`,
    );
  }

  const { signature } = parseErc6492Signature(wrappedPermitSignature);
  return signature;
}
