import {ethers} from "hardhat";
import  IERC20  from "@openzeppelin/contracts/build/contracts/IERC20.json";
import ERC20FakeFactory from  "hardhat-deploy-fake-erc20/dist/artifacts/contracts/ERC20FakeFactory.sol/ERC20FakeFactory.json"
import {UniswapV2deploy} from "./lib/UniswapV2deploy"
import WETH9 from '@uniswap/hardhat-v3-deploy/dist/util/WETH9.json';
import { ContractFactory, Contract } from "ethers";
import IUniswapV2Pair from '@uniswap/v2-periphery/build/IUniswapV2Pair.json';
import {MaxUint256} from "ethers";




async function deployWETH9() {
  const [owner] = await ethers.getSigners();
  const weth9 = await(new ContractFactory(
    WETH9.abi, WETH9.bytecode,
    owner
  )).deploy();
  return weth9;
}





async function main() {
    const [owner, user, admin, manager ] = await ethers.getSigners();
    console.log("Owner address:", owner.address);
    console.log("User address:", user.address);
    console.log("Admin address:", admin.address);
    console.log("Manager address:", manager.address);
    

    const balance = await ethers.provider.getBalance(owner.address);
    console.log("Owner balance:", ethers.formatEther(balance));

    const eth9 = await deployWETH9();
    console.log("WETH9 address:", eth9.target);
    
    const uniswapV2 = await UniswapV2deploy(await eth9.getAddress());

    const tokenA = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        owner
      )).deploy("TokenA(INR)", "TA", [
        [ owner.address, ethers.parseEther("1000")],
        [ manager.address, ethers.parseEther("1000")],
    ] );
  
    const tokenB = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        owner
      )).deploy("TokenB(JXN)", "TB", [[ owner.address, ethers.parseEther("1000")]] );
  
    console.log("TokenA address:", tokenA.target);
    console.log("TokenB address:", tokenB.target);
    
    const tokenAOwnerBalance = await tokenA.balanceOf(owner.address);
    console.log("Token A balance:", ethers.formatEther(tokenAOwnerBalance));
    const tokenBOwnerBalance = await tokenB.balanceOf(owner.address);
    console.log("TokenB  balance:", ethers.formatEther(tokenBOwnerBalance));
        

    // Uniswap v2

    await (await uniswapV2.v2_core_factory.createPair(tokenA.target, tokenB.target)).wait();
    const V2pairAddress = await uniswapV2.v2_core_factory.getPair(tokenA.target, tokenB.target);
    console.log(`JINR - WJXN Pair deployed to ${V2pairAddress}`);
    const V2pair = new Contract(V2pairAddress, IUniswapV2Pair.abi, owner);
    console.log(`Total liquidity: ${await V2pair.totalSupply()}`);
  

    await( await tokenA.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();
    await( await tokenB.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();
  
    console.log("===> Adding liquidity to the pool");
  
    const deadline = Math.floor(Date.now() / 1000) + 10 * 60;
    const addLiquidityTx = await uniswapV2.v2_router
      .addLiquidity(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        ethers.parseEther("10"),
        ethers.parseEther("10"),
        0,
        0,
        owner,
        deadline
      );
    await addLiquidityTx.wait();
    const reserves = await V2pair.getReserves();
    console.log(`Reserves: ${reserves[0].toString()}, ${reserves[1].toString()}`);
    console.log(`Total liquidity: ${await V2pair.totalSupply()}`);
  


    // Deploy TokenOcean contract
    const TokenOcean = await ethers.getContractFactory("TokenOcean");
    const tokenOcean = await TokenOcean.deploy( owner.address, tokenA.target);
    await tokenOcean.waitForDeployment();
    console.log("TokenOcean address:", await tokenOcean.getAddress());

    const NftInvest_factory = await ethers.getContractFactory("NftInvest");
    const nftInvest = await NftInvest_factory.deploy(
      owner.address,
      tokenA.target,
      tokenB.target,
      100, // APY 10% 0.1 * 1000,
      await uniswapV2.v2_router.getAddress()
     );
    await nftInvest.waitForDeployment();
    const nftInvestAddress = await nftInvest.getAddress();
    console.log("NftInvest address:", nftInvestAddress);
    await tokenA.approve(nftInvestAddress, ethers.parseEther("1"));
    
   
    await nftInvest.grantRole(await nftInvest.MANAGER_ROLE(), owner.address);
   
    
    await nftInvest.safeMint(user.address, ethers.parseEther("1"), true);
    console.log("Token A balance:", ethers.formatEther(await tokenA.balanceOf(owner.address)));
    console.log("Token A balance in NftInvest:", ethers.formatEther(await tokenA.balanceOf(nftInvestAddress)));


    await tokenA.transfer(nftInvestAddress, ethers.parseEther("1")); // TopUp some extra balance

    await nftInvest.grantRole(await nftInvest.TRADER_ROLE(), owner.address);
    await nftInvest.openTrade(0, 0, deadline);

    console.log("Trade opened");
    // Pass one year
    ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
    ethers.provider.send("evm_mine", []);
    console.log("Passed 1 year");

    // log fee
    console.log("Fee:", await nftInvest.fee(0));
    await nftInvest.closeTrade(0, 0, Math.floor(Date.now() / 1000) + 10 * 60 + 365 * 24 * 60 * 60); // plus 1 year from today
    console.log("Trade closed");


    await nftInvest.unlock(0);
    await nftInvest.connect(user).burn(0, user.address);
    // await nftInvest.burn(0, owner.address);
    console.log("Token A balance of user:", ethers.formatEther(await tokenA.balanceOf(user.address)));


    
    
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
