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

  const Portal = await ethers.getContractFactory("Portal", deployer);
  const _guardian = "0xb56BAce93EC5a92AC166f6966f28e650313B6AA1";
  const ETHYieldManager = "0x0000000000000000000000000000000000000000";

  const portal = await upgrades.deployProxy(
    Portal,
    [_guardian, false, ETHYieldManager],
    {
      initializer: "initialize",
      unsafeAllow: ["constructor"],
      constructorArgs: [], // Constructor arguments go here
    }
  );
  await portal.waitForDeployment();

  console.log("Portal deployed to:", await portal.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
