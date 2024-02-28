import "@nomiclabs/hardhat-ethers";

import { ethers } from "hardhat";
import { wethAddresses } from "./constants";
// import {TransparentUpgradeableProxy} from "../contracts/libraries/TransparentUpgradeableProxy.sol";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const chainId = network.chainId;
  console.log(network);
  console.log(`Deployer: ${deployer.address} (${ethers.utils.formatEther(await deployer.getBalance())} ETH)`);

  const factoryAddress = "0x2DB5e3707B2cdaAE26592bDF5F604b120ff8712E";
  const wrapperFactoryAddress = "0x9A2a89c376d77ebF747D229dA534FdEBf39BB6FA";
  // encode function data for initialize
  const iface = new ethers.utils.Interface(["function initialize(address, address) public"]);
  const data = iface.encodeFunctionData("initialize", [factoryAddress, wrapperFactoryAddress]);

  // deploy proxyAdmin
  const ProxyAdminFactory = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = await ProxyAdminFactory.deploy(deployer.address);
  await proxyAdmin.deployed();

  // deploy TestV1(Implementation Contrat)
  const LensFactory = await ethers.getContractFactory("JalaLens");
  const Lens = await LensFactory.deploy();
  await Lens.deployed();

  const ProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
  const proxy = await ProxyFactory.deploy(Lens.address, proxyAdmin.address, data);

  console.log("ProxyAdmin", proxyAdmin.address);
  console.log("Lens", Lens.address);
  console.log("Proxy", proxy.address);

  console.log(await proxy.factory());
  console.log(await proxyAdmin.owner());
  // console.log(`MasterRouter deployed to: ${MasterRouter.address}`);
}

main()
  .then(() => {
    console.log("Deployment completed successfully!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });

// npx hardhat run --network spicy scripts/DeployLens.s.ts
// npx hardhat run --network chliz scripts/DeployLens.s.ts
