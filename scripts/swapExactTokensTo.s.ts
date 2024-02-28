import "@nomiclabs/hardhat-ethers";

import { ethers } from "hardhat";
import { wethAddresses } from "./constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const chainId = network.chainId;
  console.log(network);
  console.log(`Deployer: ${deployer.address} (${ethers.utils.formatEther(await deployer.getBalance())} ETH)`);

  const account = "0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897";
  const wrapperFactoryAddress = "0x9A2a89c376d77ebF747D229dA534FdEBf39BB6FA";
  const masterRouterAddress = "0xce37E1b6CA28F679693a4831006CAEfa8a520D97";
  const token0 = "0xF9C0F80a6c67b1B39bdDF00ecD57f2533ef5b688";
  const token1 = "0xFD3C73b3B09D418841dd6Aff341b2d6e3abA433b";
  const token2 = "0x19cA0F4aDb29e2130A56b9C9422150B5dc07f294";
  const token3 = "0xc2661815C69c2B3924D3dd0c2C1358A1E38A3105";

  const MasterRouterF = await ethers.getContractFactory("JalaMasterRouter");
  const ERC20Factory = await ethers.getContractFactory("contracts/mocks/ERC20Mintable.sol:ERC20Mintable");
  const MasterRouter = MasterRouterF.attach(masterRouterAddress);
  const ERC20Token0 = ERC20Factory.attach(token0);
  const ERC20Token1 = ERC20Factory.attach(token1);

  //   ERC20Token0.approve(masterRouterAddress, 1);
  //   ERC20Token1.approve(masterRouterAddress, 2);

  const path = ["0xb167645aF1bCc5098Bf9aeD803f51aC851Def98a", "0xaA6E14da5cd99f20552F23b23ceD9c026b5164F0"];

  const a = await MasterRouter.factory();
  console.log(a);
  const b = await MasterRouter.swapExactTokensForTokens(
    token1,
    1,
    0,
    path,
    "0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897",
    2708508532
  );
  console.log(b);
}

main()
  .then(() => {
    console.log("SwapE completed successfully!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });

// npx hardhat run --network chiliz scripts/swapExactTokensTo.s.ts
