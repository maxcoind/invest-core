import {ethers} from "hardhat";
import WETH9 from '@uniswap/hardhat-v3-deploy/dist/util/WETH9.json';
import { ContractFactory, Contract } from "ethers";
import { Investor__factory, Investor } from "../typechain-types";
import { IERC20 } from "../typechain-types";
import ERC20FakeFactory from  "hardhat-deploy-fake-erc20/dist/artifacts/contracts/ERC20FakeFactory.sol/ERC20FakeFactory.json"
import { uniswap, InrInvestor } from "../typechain-types";
import IUniswapV2Pair from '@uniswap/v2-periphery/build/IUniswapV2Pair.json';

import {UniswapV2deploy} from "./lib/UniswapV2deploy";
import {MaxUint256} from "ethers";

async function deployWETH9(): Promise<IERC20> {
    const [owner] = await ethers.getSigners();
    const weth9_factory = await(new ContractFactory(
      WETH9.abi, WETH9.bytecode,
      owner
    ));
    const weth9 = await weth9_factory.deploy() as IERC20;
    return weth9;
  }



  async function main() {
    const [owner, user, admin, manager ] = await ethers.getSigners();
    console.log("Owner address:", owner.address);
    console.log("User address:", user.address);
    console.log("Admin address:", admin.address);
    console.log("Manager address:", manager.address);

      const weth9 = await deployWETH9();
      console.log("WETH9 deployed to:", await weth9.getAddress());
      // balance of owner
      console.log("Balance of owner:", await weth9.balanceOf(owner.address));

      const uniswapV2 = await UniswapV2deploy(await weth9.getAddress());

      const tokenA = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        owner
      )).deploy("TokenA(INR)", "TA", [
        [ owner.address, ethers.parseEther("1000")],
        [ manager.address, ethers.parseEther("1000")],
    ] ) as IERC20;
  

    const tokenB = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        owner
      )).deploy("TokenB(JXN)", "TB", [[ owner.address, ethers.parseEther("1000")]] ) as IERC20;

    const tokenC = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        owner
      )).deploy("TokenB(JXN)", "TB", [[ owner.address, ethers.parseEther("1000")]] ) as IERC20;

      
    console.log("TokenA address:", await tokenA.getAddress());
    console.log("TokenB address:", await tokenB.getAddress());
    console.log("TokenC address:", await tokenC.getAddress());
    
    const tokenAOwnerBalance = await tokenA.balanceOf(owner.address);
    console.log("Token A balance:", ethers.formatEther(tokenAOwnerBalance));
    const tokenBOwnerBalance = await tokenB.balanceOf(owner.address);
    console.log("TokenB  balance:", ethers.formatEther(tokenBOwnerBalance));
    const tokenCOwnerBalance = await tokenB.balanceOf(owner.address);
    console.log("TokenC  balance:", ethers.formatEther(tokenCOwnerBalance));

        // Uniswap v2
        await( await tokenA.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();
        await( await tokenB.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();
        await( await tokenC.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();

        // Create pair TokenA -> TokenC
        await (await uniswapV2.v2_core_factory.createPair(tokenA.target, tokenC.target)).wait();
        const V2pairA2CAddress = await uniswapV2.v2_core_factory.getPair(tokenA.target, tokenC.target);
        console.log(`TokenA -> TokenC Pair deployed to ${V2pairA2CAddress}`);
        const V2pairA2C = new Contract(V2pairA2CAddress, IUniswapV2Pair.abi, owner);
        console.log(`Total liquidity: ${await V2pairA2C.totalSupply()}`);
          
      
        console.log("===> Adding liquidity to the pool TokenA -> TokenC ");
      
        const deadline = Math.floor(Date.now() / 1000) + 10 * 60;
        const addLiquidityTx = await uniswapV2.v2_router
          .addLiquidity(
            await tokenA.getAddress(),
            await tokenC.getAddress(),
            ethers.parseEther("10"),
            ethers.parseEther("20"),
            0,
            0,
            owner,
            deadline
          );
        await addLiquidityTx.wait();
        const reserves = await V2pairA2C.getReserves();
        console.log(`Reserves TokenA -> TokenC: ${reserves[0].toString()}, ${reserves[1].toString()}`);
        console.log(`Total liquidity TokenA -> TokenC: ${await V2pairA2C.totalSupply()}`);

        // Create pair TokenB -> TokenC
        await (await uniswapV2.v2_core_factory.createPair(tokenB.target, tokenC.target)).wait();
        const V2pairB2CAddress = await uniswapV2.v2_core_factory.getPair(tokenB.target, tokenC.target);
        console.log(`TokenB -> TokenC Pair deployed to ${V2pairB2CAddress}`);
        const V2pairB2C = new Contract(V2pairB2CAddress, IUniswapV2Pair.abi, owner);
        console.log(`Total liquidity: ${await V2pairB2C.totalSupply()}`);
        console.log("===> Adding liquidity to the pool TokenB -> TokenC ");
      
        const addLiquidityTxB = await uniswapV2.v2_router
          .addLiquidity(
            await tokenB.getAddress(),
            await tokenC.getAddress(),
            ethers.parseEther("10"),
            ethers.parseEther("20"),
            0,
            0,
            owner,
            deadline
          );
        await addLiquidityTxB.wait();
        const reservesB = await V2pairB2C.getReserves();
        console.log(`Reserves TokenB -> TokenC: ${reservesB[0].toString()}, ${reservesB[1].toString()}`);
        console.log(`Total liquidity TokenB -> TokenC: ${await V2pairB2C.totalSupply()}`);
    

// Invest
const Invest_factory = await ethers.getContractFactory("InrInvestor");
const invest = await Invest_factory.deploy(
  tokenA.target,
  tokenB.target,
  await uniswapV2.v2_router.getAddress(),
  owner.address
 ) as InrInvestor;
await invest.waitForDeployment();
const investAddress = await invest.getAddress();
console.log("InrInvest address:", investAddress);

await tokenA.approve(investAddress, ethers.parseEther("1"));


await invest.grantRole(await invest.MANAGER_ROLE(), owner.address);
// await invest.grantRole(await invest.MANAGER_ROLE(), manager.address);


console.log("Token A balance of user:", ethers.formatEther(await tokenA.balanceOf(user.address)));
console.log("Token B balance of user:", ethers.formatEther(await tokenB.balanceOf(user.address)));

console.log("Token A balance in InrInvest:", ethers.formatEther(await tokenA.balanceOf(investAddress)));
console.log("Token B balance in InrInvest:", ethers.formatEther(await tokenB.balanceOf(investAddress)));


await tokenA.transfer(investAddress, ethers.parseEther("1")); // TopUp some extra balance
await invest.grantRole(await invest.TRADER_ROLE(), owner.address);
await invest.grantRole(await invest.TRADER_ROLE(), manager.address);
console.log("Token A balance in InrInvest:", ethers.formatEther(await tokenA.balanceOf(investAddress)));

await tokenA.connect(manager).approve(investAddress, MaxUint256);
const invest_amount = ethers.parseEther("85");
await invest.setInrRate(850_000n);
// await invest.openTrade(user.address, ethers.formatEther("1"), 0, deadline, 0);
// function openTrade(address to, uint256 inr, uint256 amountBOutMin, uint deadline, bytes32 _hash) onlyRole(TRADER_ROLE) external payable returns(uint[] memory amounts) {
console.log("Token A balance in Manager:", ethers.formatEther(await tokenA.balanceOf(manager.address)));
console.log("Open trade");
const exchangePath = [await tokenA.getAddress(), await tokenC.getAddress(), await tokenB.getAddress()];
console.log("Open Path",exchangePath );
await invest.connect(manager).openTrade(exchangePath, user.address, invest_amount, 0, deadline, "0x7465737400000000000000000000000000000000000000000000000000000000");

console.log("Trade opened");
console.log("Token A balance in Manager:", ethers.formatEther(await tokenA.balanceOf(manager.address)));

console.log("Token A balance of user:", ethers.formatEther(await tokenA.balanceOf(user.address)));
console.log("Token B balance of user:", ethers.formatEther(await tokenB.balanceOf(user.address)));
console.log("Token A balance in InrInvest:", ethers.formatEther(await tokenA.balanceOf(investAddress)));
console.log("Token B balance in InrInvest:", ethers.formatEther(await tokenB.balanceOf(investAddress)));

// Pass one year
ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
ethers.provider.send("evm_mine", []);
console.log("Passed 1 year");

// log fee
// console.log("Fee:", await invest.fee(0));
// function closeTrade(uint256 tokenId, address to, uint256 amountOutMin, uint deadline)
await invest.grantRole(await invest.EXCHANGER_ROLE(), owner.address);
const closeTradePath = [await tokenB.getAddress(), await tokenC.getAddress(), await tokenA.getAddress()];
console.log("Close Path",closeTradePath );

await invest.closeTrade(closeTradePath, 0n, owner.address, 0, Math.floor(Date.now() / 1000) + 10 * 60 + 365 * 24 * 60 * 60); // plus 1 year from today
console.log("Trade closed");


// await nftInvest.burn(0, owner.address);s
console.log("Token A balance of user:", ethers.formatEther(await tokenA.balanceOf(user.address)));
console.log("Token B balance of user:", ethers.formatEther(await tokenB.balanceOf(user.address)));

console.log("Token A balance in InrInvest:", ethers.formatEther(await tokenA.balanceOf(investAddress)));
console.log("Token B balance in InrInvest:", ethers.formatEther(await tokenB.balanceOf(investAddress)));


    }
    
    main().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
    


  