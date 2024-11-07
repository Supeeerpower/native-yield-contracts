const { ethers } = require("ethers");
require("dotenv").config();

// Addresses
const oappAddress = "0x610E0Dc451159339b0bb8216A423C8932F92558A"; // Replace with your OApp address
const sendLibAddress = process.env.FUSE_SEND_LIB; // Replace with your send message library address

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

const executorConfig = {
  maxMessageSize: 10000, // Example value, replace with actual
  executorAddress: process.env.FUSE_EXECUTOR, // Replace with the actual executor address
};

// Provider and Signer
const provider = new ethers.JsonRpcProvider(process.env.FUSE_RPC_URL);
const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// ABI and Contract
const endpointAbi = [
  "function setConfig(address oappAddress, address sendLibAddress, tuple(uint32 eid, uint32 configType, bytes config)[] setConfigParams) external",
];
const endpointContract = new ethers.Contract(
  process.env.FUSE_EA,
  endpointAbi,
  signer
);

// Encode UlnConfig using defaultAbiCoder
const configTypeUlnStruct =
  "tuple(uint64 confirmations, uint8 requiredDVNCount, uint8 optionalDVNCount, uint8 optionalDVNThreshold, address[] requiredDVNs, address[] optionalDVNs)";
const encodedUlnConfig = ethers.AbiCoder.defaultAbiCoder().encode(
  [configTypeUlnStruct],
  [ulnConfig]
);

// Encode ExecutorConfig using defaultAbiCoder
const configTypeExecutorStruct =
  "tuple(uint32 maxMessageSize, address executorAddress)";
const encodedExecutorConfig = ethers.AbiCoder.defaultAbiCoder().encode(
  [configTypeExecutorStruct],
  [executorConfig]
);

// Define the SetConfigParam structs
const setConfigParamUln = {
  eid: remoteEid,
  configType: 2, // ULN_CONFIG_TYPE
  config: encodedUlnConfig,
};

const setConfigParamExecutor = {
  eid: remoteEid,
  configType: 1, // EXECUTOR_CONFIG_TYPE
  config: encodedExecutorConfig,
};

// Send the transaction
async function sendTransaction() {
  try {
    const tx = await endpointContract.setConfig(
      oappAddress,
      sendLibAddress,
      [setConfigParamUln, setConfigParamExecutor] // Array of SetConfigParam structs
    );

    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction confirmed:", receipt.transactionHash);
  } catch (error) {
    console.error("Transaction failed:", error);
  }
}

sendTransaction();
