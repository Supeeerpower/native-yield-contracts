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

  const MainnetOApp = await ethers.getContractFactory("MainnetOApp", deployer);
  const mainnetOApp = await MainnetOApp.deploy(
    process.env.MAINNET_EA,
    deployer.address
  );
  await mainnetOApp.waitForDeployment();
  const mainnetOAppAddress = await mainnetOApp.getAddress();
  console.log("MainnetOApp deployed to:", mainnetOAppAddress);

  const Portal = await ethers.getContractFactory("Portal", deployer);
  const _guardian = "0xb56BAce93EC5a92AC166f6966f28e650313B6AA1";
  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const portal = await upgrades.deployProxy(
    Portal,
    [_guardian, false, ZERO_ADDRESS, mainnetOAppAddress],
    {
      initializer: "initialize",
      unsafeAllow: ["constructor"],
      constructorArgs: [],
    }
  );
  await portal.waitForDeployment();
  const portalAddress = await portal.getAddress();
  console.log("Portal deployed to:", portalAddress);

  const ETHYieldManager = await ethers.getContractFactory("ETHYieldManager");
  const ethYieldManager = await upgrades.deployProxy(
    ETHYieldManager,
    [portalAddress, deployer.address],
    {
      initializer: "initialize",
      unsafeAllow: ["constructor", "delegatecall", "state-variable-immutable"],
      constructorArgs: [],
    }
  );
  await ethYieldManager.waitForDeployment();
  const ethYieldManagerAddress = await ethYieldManager.getAddress();
  console.log("ETHYieldManager deployed to:", ethYieldManagerAddress);

  const LidoYieldProvider = await ethers.getContractFactory(
    "LidoYieldProvider"
  );
  const lidoYieldProvider = await LidoYieldProvider.deploy(
    ethYieldManagerAddress
  );
  await lidoYieldProvider.waitForDeployment();
  const lidoYieldProviderAddress = await lidoYieldProvider.getAddress();
  console.log("LidoYieldProvider deployed to:", lidoYieldProviderAddress);

  // Add LidoYieldProvider to ETHYieldManager
  const addProviderTx = await ethYieldManager.addProvider(
    lidoYieldProviderAddress
  );
  await addProviderTx.wait();
  console.log("Added LidoYieldProvider to ETHYieldManager");

  // Set ETHYieldManager in Portal
  const setYieldManagerTx = await portal.setETHYieldManager(
    ethYieldManagerAddress
  );
  await setYieldManagerTx.wait();
  console.log("Set ETHYieldManager in Portal");

  // Set admin in ETHYieldManager
  const setAdminTx = await ethYieldManager.setAdmin(deployer.address);
  await setAdminTx.wait();
  console.log("Set admin in ETHYieldManager");

  // Set Portal address in MainnetOApp
  const setPortalTx = await mainnetOApp.setPortalAddress(portalAddress);
  await setPortalTx.wait();
  console.log("Set Portal address in MainnetOApp");

  // Verify MainnetOApp
  await hre.run("verify:verify", {
    address: mainnetOAppAddress,
    constructorArguments: [process.env.MAINNET_EA, deployer.address],
  });
  console.log("MainnetOApp verified");

  // Verify LidoYieldProvider
  await hre.run("verify:verify", {
    address: lidoYieldProviderAddress,
    constructorArguments: [ethYieldManagerAddress],
  });
  console.log("LidoYieldProvider verified");

  // Verify Portal
  await hre.run("verify:verify", {
    address: portalAddress,
    constructorArguments: [],
  });
  console.log("Portal verified");

  await hre.run("verify:verify", {
    address: ethYieldManagerAddress,
    constructorArguments: [],
  });
  console.log("ETHYieldManager verified");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
