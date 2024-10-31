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

  const vETH = await ethers.getContractFactory("vETH", deployer);
  const _reporter = "0xb56BAce93EC5a92AC166f6966f28e650313B6AA1";
  const _remoteToken = "0x0000000000000000000000000000000000000000";

  const veth = await upgrades.deployProxy(vETH, [], {
    initializer: "initialize",
    unsafeAllow: ["constructor", "state-variable-immutable"],
    constructorArgs: [_reporter, _remoteToken],
    timeout: 120000,
  });
  await veth.waitForDeployment();

  console.log("vETH deployed to:", await veth.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
