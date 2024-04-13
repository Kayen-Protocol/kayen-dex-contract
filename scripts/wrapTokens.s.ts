import "@nomiclabs/hardhat-ethers";

import { ethers } from "hardhat";
import { wethAddresses } from "./constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  // const chainId = network.chainId;
  console.log(network);
  console.log(`Deployer: ${deployer.address} (${ethers.utils.formatEther(await deployer.getBalance())} ETH)`);

  const account = "0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897";
  const wrapperFactoryAddress = "0x9A2a89c376d77ebF747D229dA534FdEBf39BB6FA";
  const token3 = "0xc2661815C69c2B3924D3dd0c2C1358A1E38A3105";

  const WrapperFactoryF = await ethers.getContractFactory("ChilizWrapperFactory");
  const wrapperFactory = WrapperFactoryF.attach(wrapperFactoryAddress);

  //   await wrapperFactory.wrap(account, token0, 1);
  //   await wrapperFactory.wrap(account, token1, 1);
  //   await wrapperFactory.wrap(account, token2, 1);
  await wrapperFactory.wrap(account, token3, 1);
}

main()
  .then(() => {
    console.log("Deployment completed successfully!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });

// npx hardhat run --network chiliz scripts/wrapTokens.s.ts
