import "@nomiclabs/hardhat-ethers";

import { ethers } from "hardhat";
import { wethAddresses } from "./constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const chainId = network.chainId;
  console.log(network);
  console.log(`Deployer: ${deployer.address} (${ethers.utils.formatEther(await deployer.getBalance())} ETH)`);

  // Deploy CAPOFactory with the address of the CAPO token
  const feeSetter = deployer.address;
  const jalaFactoryFactory = await ethers.getContractFactory("JalaFactory");
  const jalaFactory = await jalaFactoryFactory.deploy(feeSetter);
  await jalaFactory.deployed();
  console.log(`JALA Factory deployed to: ${jalaFactory.address}`);

  // // Deploy CAPORouter02 with the address of the CAPO factory and WETH token
  const WETH = "0x677F7e16C7Dd57be1D4C8aD1244883214953DC47";
  const CAPORouter02 = await ethers.getContractFactory("JalaRouter02");
  const capoRouter = await CAPORouter02.deploy(jalaFactory.address, WETH);
  await capoRouter.deployed();
  console.log(`Jala Router deployed to: ${capoRouter.address}`);

  const WrapperFactoryF = await ethers.getContractFactory("ChilizWrapperFactory");
  const wrapperFactory = await WrapperFactoryF.deploy();
  await wrapperFactory.deployed();
  console.log(`WrapperFactory deployed to: ${wrapperFactory.address}`);

  const MasterRouterFactory = await ethers.getContractFactory("JalaMasterRouter");
  const MasterRouter = await MasterRouterFactory.deploy(
    jalaFactory.address,
    wrapperFactory.address,
    capoRouter.address,
    WETH
  );
  await MasterRouter.deployed();
  console.log(`MasterRouter deployed to: ${MasterRouter.address}`);
}

main()
  .then(() => {
    console.log("Deployment completed successfully!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });

// npx hardhat run --network chiliz scripts/deployment.s.ts
