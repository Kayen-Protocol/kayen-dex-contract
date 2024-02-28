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
  const factoryAddr = "0x2DB5e3707B2cdaAE26592bDF5F604b120ff8712E";
  const ACMilan = "0xf9c0f80a6c67b1b39bddf00ecd57f2533ef5b688";
  const FCBarcelona = "0xfd3c73b3b09d418841dd6aff341b2d6e3aba433b";
  const OG = "0x19ca0f4adb29e2130a56b9c9422150b5dc07f294";
  const PSG = "0xc2661815c69c2b3924d3dd0c2c1358a1e38a3105";
  const WETH = "0x677F7e16C7Dd57be1D4C8aD1244883214953DC47";

  const jalaFactoryFactory = await ethers.getContractFactory("JalaFactory");
  const jalaFactory = await jalaFactoryFactory.attach(factoryAddr);
  await jalaFactory.createPair(ACMilan, OG);
  // await jalaFactory.createPair(ACMilan, PSG);

  //   createPair
}

main()
  .then(() => {
    console.log("Created Pair!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });

// npx hardhat run --network chiliz scripts/addliquidity.s.ts
