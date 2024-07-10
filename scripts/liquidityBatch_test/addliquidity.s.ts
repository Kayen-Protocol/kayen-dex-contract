import "@nomiclabs/hardhat-ethers";

import { ethers } from "hardhat";
import { wethAddresses } from "./constants";
import { assert } from "console";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const chainId = network.chainId;
  console.log(network);
  console.log(`Deployer: ${deployer.address} (${ethers.utils.formatEther(await deployer.getBalance())} ETH)`);

  // Mint New tokens
  const erc20MintableFactory = await ethers.getContractFactory(
    "contracts/mocks/ERC20Mintable_decimal.sol:ERC20Mintable"
  );

  const erc20MintableA;
  const erc20MintableB;
  // erc20MintableA = await erc20MintableFactory.attach("0x6b1736CA01FD8fbad0330f94D6323B167486d67e");
  // erc20MintableB = await erc20MintableFactory.attach("0xe0FDc63c229a76BE6Dfc785BbC7f6aE295eD12Ad");
  erc20MintableA = await erc20MintableFactory.deploy("BatchTokenA", "BTA", 18);
  await erc20MintableA.deployed();
  erc20MintableB = await erc20MintableFactory.deploy("BatchTokenB", "BTB", 18);
  await erc20MintableB.deployed();

  console.log(`Deployed erc20MintableA: ${erc20MintableA.address}`);
  console.log(`Deployed erc20MintableB: ${erc20MintableB.address}`);

  const mintAmount = ethers.utils.parseUnits("1000000", 18); // Example: 100,000 tokens with 18 decimal places
  const mint1tx = await erc20MintableA.mint(mintAmount, deployer.address);
  console.log(`Minted ${mintAmount} erc20MintableA to: ${deployer.address}`);
  const mint2tx = await erc20MintableB.mint(mintAmount, deployer.address);
  console.log(`Minted ${mintAmount} erc20MintableB to: ${deployer.address}`);
  await mint1tx.wait();
  await mint2tx.wait();

  // Create Pair
  const factoryAddress = "0xfc1924E20d64AD4daA3A4947b4bAE6cDE77d2dBC";
  const KayenFactoryFactory = await ethers.getContractFactory("KayenFactory");
  const KayenFactory = await KayenFactoryFactory.attach(factoryAddress);
  const feeTo = await KayenFactory.feeTo();

  console.log(`feeTo: ${feeTo}`);

  // Add Liquidity: Check LP Fee
  const routerAddress = "0xb82b0e988a1FcA39602c5079382D360C870b44c8";
  const KayenRouter02Factory = await ethers.getContractFactory("KayenRouter02");
  const KayenRouter02 = await KayenRouter02Factory.attach(routerAddress);

  console.log("=================================================");
  console.log("====Start Test===================================");
  console.log("=================================================");
  console.log(`Msg.sender Balance TokenA: ${await erc20MintableA.balanceOf(deployer.address)}`);
  console.log(`Msg.sender Balance TokenB: ${await erc20MintableB.balanceOf(deployer.address)}`);
  const approvetx1 = await erc20MintableA.connect(deployer).approve(routerAddress, ethers.constants.MaxUint256);
  const approvetx2 = await erc20MintableB.connect(deployer).approve(routerAddress, ethers.constants.MaxUint256);
  await approvetx1.wait();
  await approvetx2.wait();

  const pairAddress = await KayenFactory.getPair(erc20MintableA.address, erc20MintableB.address);
  const KayenPairFactory = await ethers.getContractFactory("KayenPair");
  const KayenPair = await KayenPairFactory.attach(pairAddress);

  console.log(`kLast: ${await KayenPair.kLast()}`);
  const swapTx = await KayenRouter02.connect(deployer).swapExactTokensForTokens(
    100000,
    0,
    [erc20MintableA.address, erc20MintableB.address],
    deployer.address,
    2720361379,
    { gasLimit: 5000000 } // Manually set gas limit
  );
  await swapTx.wait();
  const a = await KayenPair.getReserves();
  console.log(`Reserves: ${a}`);
  const addliquiditytx1 = await KayenRouter02.connect(deployer).addLiquidity(
    erc20MintableA.address.toString(),
    erc20MintableB.address.toString(),
    ethers.utils.parseEther("10000"),
    ethers.utils.parseEther("10000"),
    0,
    0,
    deployer.address,
    2720361379,
    { gasLimit: 5000000 } // Manually set gas limit
  );
  console.log("First Batch Done...");
  await addliquiditytx1.wait();

  const LPbalanceBefore = await KayenPair.balanceOf(feeTo);

  const addliquiditytx2 = await KayenRouter02.connect(deployer).addLiquidity(
    erc20MintableA.address.toString(),
    erc20MintableB.address.toString(),
    ethers.utils.parseEther("90000"),
    ethers.utils.parseEther("90000"),
    0,
    0,
    deployer.address,
    2720361379,
    { gasLimit: 5000000 } // Manually set gas limit
  );
  console.log("Second Batch Done...");
  await addliquiditytx2.wait();

  const LPbalanceAfter = await KayenPair.balanceOf(feeTo);

  console.log("=================================================");
  console.log("====Result Test==================================");
  console.log("=================================================");
  console.log(`LP Fee After First addliquidity: ${LPbalanceBefore}`);
  console.log(`LP Fee After Second addliquidity: ${LPbalanceAfter}`);
  console.log(`LP Fee Difference: ${LPbalanceAfter.sub(LPbalanceBefore)}`);
  console.log(`kLast: ${await KayenPair.kLast()}`);
}

main()
  .then(() => {
    console.log("DONE!!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });

// npx hardhat run --network spicy scripts/liquidityBatch_test/addliquidity.s.ts
