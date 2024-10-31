const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Constructor arguments
  const YieldManager = "0xB03222216e9BBc16298fb7cf75ad1e06B7424654";

  // Get the contract factory
  const LidoYieldProvider = await ethers.getContractFactory(
    "LidoYieldProvider"
  );

  // Deploy using the upgrades plugin
  console.log("Deploying LidoYieldProvider...");
  const lidoYieldProvider = await LidoYieldProvider.deploy(YieldManager);
  await lidoYieldProvider.waitForDeployment();

  const lidoYieldProviderAddress = await lidoYieldProvider.getAddress();
  console.log("LidoYieldProvider deployed to:", lidoYieldProviderAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
