const { ethers } = require("ethers");
require("dotenv").config();

// Addresses
const oappAddress = "0x610E0Dc451159339b0bb8216A423C8932F92558A"; // Replace with your OApp address
const receiveLibAddress = process.env.FUSE_RECEIVE_LIB; // Replace with your receive message library address

// Configuration
const remoteEid = process.env.MAINNET_EID; // Example EID, replace with the actual value
const ulnConfig = {
  confirmations: 99, // Example value, replace with actual
  requiredDVNCount: 1, // Example value, replace with actual
  optionalDVNCount: 0, // Example value, replace with actual
  optionalDVNThreshold: 0, // Example value, replace with actual
  requiredDVNs: [process.env.FUSE_DVN], // Replace with actual addresses
  optionalDVNs: [], // Replace with actual addresses
};

// Provider and Signer
const provider = new ethers.JsonRpcProvider(process.env.FUSE_RPC_URL);
const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// ABI and Contract
const endpointAbi = [
  "function setConfig(address oappAddress, address receiveLibAddress, tuple(uint32 eid, uint32 configType, bytes config)[] setConfigParams) external",
];
const endpointContract = new ethers.Contract(
  process.env.FUSE_EA,
  endpointAbi,
  signer
);

// Encode UlnConfig using AbiCoder
const configTypeUlnStruct =
  "tuple(uint64 confirmations, uint8 requiredDVNCount, uint8 optionalDVNCount, uint8 optionalDVNThreshold, address[] requiredDVNs, address[] optionalDVNs)";
const encodedUlnConfig = ethers.AbiCoder.defaultAbiCoder().encode(
  [configTypeUlnStruct],
  [ulnConfig]
);

// Define the SetConfigParam struct
const setConfigParam = {
  eid: remoteEid,
  configType: 2, // RECEIVE_CONFIG_TYPE
  config: encodedUlnConfig,
};

// Send the transaction
async function sendTransaction() {
  try {
    const tx = await endpointContract.setConfig(
      oappAddress,
      receiveLibAddress,
      [setConfigParam] // This should be an array of SetConfigParam structs
    );

    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction confirmed:", receipt.transactionHash);
  } catch (error) {
    console.error("Transaction failed:", error);
  }
}

sendTransaction();
