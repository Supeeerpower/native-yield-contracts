const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

async function main() {
  // Use the private key from the environment variable
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY not set in environment");
  }

  const deployer = new ethers.Wallet(privateKey, ethers.provider);
  console.log("Deploying contracts with the account:", deployer.address);

  const FuseOApp = await ethers.getContractFactory("FuseOApp", deployer);
  const fuseOApp = await FuseOApp.deploy(process.env.FUSE_EA, deployer.address);
  await fuseOApp.waitForDeployment();
  const fuseOAppAddress = await fuseOApp.getAddress();
  console.log("FuseOApp deployed to:", fuseOAppAddress);

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const vETH = await ethers.getContractFactory("vETH", deployer);
  const veth = await upgrades.deployProxy(vETH, [], {
    initializer: "initialize",
    unsafeAllow: ["constructor", "state-variable-immutable"],
    constructorArgs: [fuseOAppAddress, ZERO_ADDRESS],
    timeout: 120000,
  });
  await veth.waitForDeployment();
  const vethAddress = await veth.getAddress();
  console.log("vETH deployed to:", vethAddress);

  const setVETHAddressTx = await fuseOApp.setVETHAddress(vethAddress);
  await setVETHAddressTx.wait();
  console.log("vETH address set in FuseOApp");

  // Verify FuseOApp
  await hre.run("verify:verify", {
    address: fuseOAppAddress,
    constructorArguments: [process.env.FUSE_EA, deployer.address],
  });
  console.log("FuseOApp verified");

  // Verify vETH implementation
  await hre.run("verify:verify", {
    address: vethAddress,
    constructorArguments: [fuseOAppAddress, ZERO_ADDRESS],
  });
  console.log("vETH implementation verified");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
