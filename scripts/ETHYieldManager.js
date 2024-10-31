const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Constructor arguments
  const PORTAL_ADDRESS = "0xDF6ee06A422048de8170225C2CF1570962D4c7bA";
  const OWNER_ADDRESS = deployer.address;

  // Get the contract factory
  const ETHYieldManager = await ethers.getContractFactory("ETHYieldManager");

  // Deploy using the upgrades plugin
  console.log("Deploying ETHYieldManager...");
  const ethYieldManager = await upgrades.deployProxy(
    ETHYieldManager,
    [PORTAL_ADDRESS, OWNER_ADDRESS],
    {
      initializer: "initialize",
      unsafeAllow: ["constructor", "delegatecall", "state-variable-immutable"],
      constructorArgs: [],
    }
  );
  await ethYieldManager.waitForDeployment();

  const ethYieldManagerAddress = await ethYieldManager.getAddress();
  console.log("ETHYieldManager deployed to:", ethYieldManagerAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
