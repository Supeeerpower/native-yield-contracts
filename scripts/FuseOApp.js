const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  // Use private key for deployment
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("Please set PRIVATE_KEY in your environment variables");
  }

  // Deploy FuseOApp to FuseSpark
  const deployer = new ethers.Wallet(privateKey, ethers.provider);
  console.log(
    "Deploying FuseOApp to FuseSpark with account:",
    deployer.address
  );

  const FuseOApp = await ethers.getContractFactory("FuseOApp", deployer);
  const fuseOApp = await FuseOApp.deploy(
    process.env.FUSESPARK_EA,
    deployer.address
  );
  await fuseOApp.waitForDeployment();

  console.log(
    "FuseOApp deployed to FuseSpark at:",
    await fuseOApp.getAddress()
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
