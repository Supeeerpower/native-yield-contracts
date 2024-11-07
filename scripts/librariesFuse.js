const { ethers } = require("ethers");
require("dotenv").config();

// Replace with your actual values
const YOUR_OAPP_ADDRESS = "0x610E0Dc451159339b0bb8216A423C8932F92558A";
const YOUR_SEND_LIB_ADDRESS = process.env.FUSE_SEND_LIB;
const YOUR_RECEIVE_LIB_ADDRESS = process.env.FUSE_RECEIVE_LIB;
const YOUR_ENDPOINT_CONTRACT_ADDRESS = process.env.FUSE_EA;
const YOUR_RPC_URL = process.env.FUSE_RPC_URL;
const YOUR_PRIVATE_KEY = process.env.PRIVATE_KEY;

// Define the remote EID
const remoteEid = process.env.MAINNET_EID; // Replace with your actual EID

// Set up the provider and signer
const provider = new ethers.JsonRpcProvider(YOUR_RPC_URL);
const signer = new ethers.Wallet(YOUR_PRIVATE_KEY, provider);

// Set up the endpoint contract
const endpointAbi = [
  "function setSendLibrary(address oapp, uint32 eid, address sendLib) external",
  "function setReceiveLibrary(address oapp, uint32 eid, address receiveLib) external",
];
const endpointContract = new ethers.Contract(
  YOUR_ENDPOINT_CONTRACT_ADDRESS,
  endpointAbi,
  signer
);

async function setLibraries() {
  try {
    // Set the send library
    const sendTx = await endpointContract.setSendLibrary(
      YOUR_OAPP_ADDRESS,
      remoteEid,
      YOUR_SEND_LIB_ADDRESS
    );
    console.log("Send library transaction sent:", sendTx.hash);
    await sendTx.wait();
    console.log("Send library set successfully.");

    // Set the receive library
    const receiveTx = await endpointContract.setReceiveLibrary(
      YOUR_OAPP_ADDRESS,
      remoteEid,
      YOUR_RECEIVE_LIB_ADDRESS
    );
    console.log("Receive library transaction sent:", receiveTx.hash);
    await receiveTx.wait();
    console.log("Receive library set successfully.");
  } catch (error) {
    console.error("Transaction failed:", error);
  }
}

setLibraries();
