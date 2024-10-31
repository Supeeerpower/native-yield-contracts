const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  // Use private key for deployment
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("Please set PRIVATE_KEY in your environment variables");
  }

  // Deploy MainnetOApp to Holesky
  const deployer = new ethers.Wallet(privateKey, ethers.provider);
  console.log(
    "Deploying MainnetOApp to Holesky with account:",
    deployer.address
  );

  const MainnetOApp = await ethers.getContractFactory("MainnetOApp", deployer);
  const mainnetOApp = await MainnetOApp.deploy(
    process.env.HOLESKY_EA,
    deployer.address
  );

  await mainnetOApp.waitForDeployment();

  const mainnetOAppAddress = await mainnetOApp.getAddress();
  console.log("MainnetOApp deployed to:", mainnetOAppAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
