require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
const dotenv = require("dotenv");
const { HardhatUserConfig } = require("hardhat/config");
dotenv.config();
const { PRIVATE_KEY } = process.env;
const config = {
  solidity: {
    version: "0.8.27",
    settings: {
      viaIR: false,
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  },
  mocha: {
    timeout: 3600000,
  },
  networks: {
    holesky: {
      url: process.env.HOLESKY_RPC_URL,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
    fusespark: {
      url: process.env.FUSESPARK_RPC_URL,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
    fuse: {
      url: process.env.FUSE_RPC_URL,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      holesky: process.env.ETHERSCAN_API_KEY || "",
      fusespark: process.env.FUSESPARK_API_KEY || "",
      fuse: process.env.FUSE_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "fusespark",
        chainId: 123,
        urls: {
          apiURL: "https://explorer.fusespark.io/api",
          browserURL: "https://explorer.fusespark.io/",
        },
      },
      {
        network: "fuse",
        chainId: 122,
        urls: {
          apiURL: "https://explorer.fuse.io/api",
          browserURL: "https://explorer.fuse.io/",
        },
      },
    ],
  },
};
module.exports = config;
