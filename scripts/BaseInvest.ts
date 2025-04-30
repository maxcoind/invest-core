// Deplploy and test the BaseInvest contract
import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import {MaxUint256} from "ethers";

import { BaseInvest } from "../typechain-types";
import {deployUniswapWithPairs} from "./Uniswap";
import TransparentUpgradeableProxy from "../node_modules/@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json";
import { token } from "../typechain-types/@openzeppelin/contracts";



async function main() {
  console.log("Start Deploying BaseInvest...");
  const [deployer, manager, user] = await ethers.getSigners();

  //prepare uniswap pairs
  const uniswap = await deployUniswapWithPairs();
  console.log("Uniswap router to:", await uniswap.v2_router.getAddress());
  console.log("End deploying uniswap pairs");

  // deploy with transparent proxy
  const BaseInvestFactory = await ethers.getContractFactory("BaseInvest");
  const tokenA = (await uniswap.tokenA.getAddress());
  const tokenB = (await uniswap.tokenB.getAddress());
  const V2router = (await uniswap.v2_router.getAddress());
  const baseInvest = await BaseInvestFactory.deploy(tokenA, tokenB, V2router);
  console.log("BaseInvest deployed to:", await baseInvest.getAddress());
  const proxy_factory = await(new ContractFactory(
    TransparentUpgradeableProxy.abi, TransparentUpgradeableProxy.bytecode,
    deployer
  ));

  const initializeData = baseInvest.interface.encodeFunctionData("initialize", [deployer.address]);
  
  const proxy = await proxy_factory.deploy(await baseInvest.getAddress(), deployer.address,initializeData);
  
  const adminChangedEventFilter = proxy.filters.AdminChanged();
  await proxy.waitForDeployment();

  const adminChangedEvents = await proxy.queryFilter(adminChangedEventFilter);
  const adminProxyAddress = adminChangedEvents[0].args[1];

  console.log("Proxy Admin:", adminProxyAddress);
  const baseInvestProxy = new Contract(
    await proxy.getAddress(),
    BaseInvestFactory.interface,
    deployer
  );
  console.log("BaseInvest proxy deployed to:", await proxy.getAddress());
  console.log("BaseInvest tokenA address:", await baseInvestProxy.tokenA());
  // console.log("BaseInvest initialize");
  // await baseInvestProxy.initialize(deployer.address);

  await baseInvestProxy.grantRole(await baseInvestProxy.MANAGER_ROLE(), deployer.address);
  // await invest.grantRole(await invest.MANAGER_ROLE(), manager.address);
  await baseInvestProxy.grantRole(await baseInvestProxy.TRADER_ROLE(), deployer.address);
  await baseInvestProxy.grantRole(await baseInvestProxy.TRADER_ROLE(), manager.address);
  await baseInvestProxy.grantRole(await baseInvestProxy.EXCHANGER_ROLE(), deployer.address);
  
  
  await uniswap.tokenA.transfer(await baseInvestProxy.getAddress(), ethers.parseEther("1")); // TopUp some extra balance
  await uniswap.tokenA.connect(manager).approve(await baseInvestProxy.getAddress(), MaxUint256);


  const invest_amount = ethers.parseEther("85");
  console.log("Open trade");
  const tokenId = "0x7465737400000000000000000000000000000000000000000000000000000000";
  const deadline = Math.floor(Date.now() / 1000) + 10 * 60;
  const exchangePath = [await uniswap.tokenA.getAddress(), await uniswap.tokenC.getAddress(), await uniswap.tokenB.getAddress()];
  console.log("Open Path",exchangePath );
  await baseInvestProxy.connect(manager).openTrade(tokenId, exchangePath, user.address, invest_amount, 0, deadline);
  console.log("Trade opened");
  
  // Pass one year
  ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
  ethers.provider.send("evm_mine", []);
  console.log("Passed 1 year");
  const closeTradePath = [await uniswap.tokenB.getAddress(), await uniswap.tokenC.getAddress(), await uniswap.tokenA.getAddress()];

  const profit = await baseInvestProxy.viewPendingProfit(tokenId, closeTradePath); 
  console.log("Profit:", profit);

  await baseInvestProxy.closeTrade(tokenId, closeTradePath, deployer.address, 0, Math.floor(Date.now() / 1000) + 10 * 60 + 365 * 24 * 60 * 60); // plus 1 year from today
  console.log("Trade closed");
  await baseInvestProxy.burn(tokenId);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });