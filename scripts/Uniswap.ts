import {ethers} from "hardhat";
import WETH9 from '@uniswap/hardhat-v3-deploy/dist/util/WETH9.json';
import { ContractFactory, Contract } from "ethers";
import { IERC20 } from "../typechain-types";
import ERC20FakeFactory from  "hardhat-deploy-fake-erc20/dist/artifacts/contracts/ERC20FakeFactory.sol/ERC20FakeFactory.json"
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

export async function deployUniswapWithPairs() {
    const [deployer, manager, ] = await ethers.getSigners();
    console.log("Deployer address:", deployer.address);
    console.log("Deployer balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

    const weth9 = await deployWETH9();
    console.log("WETH9 deployed to:", await weth9.getAddress());
    const uniswapV2 = await UniswapV2deploy(await weth9.getAddress());


    const tokenA = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        deployer
      )).deploy("TokenA(INR)", "TA", [
        [ deployer.address, ethers.parseEther("1000")],
        [ manager.address, ethers.parseEther("1000")],
    ] ) as IERC20;
  

    const tokenB = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        deployer
      )).deploy("TokenB(JXN)", "TB", [[ deployer.address, ethers.parseEther("1000")]] ) as IERC20;

    const tokenC = await(new ethers.ContractFactory(
        ERC20FakeFactory.abi, ERC20FakeFactory.bytecode,
        deployer
      )).deploy("TokenB(JXN)", "TB", [[ deployer.address, ethers.parseEther("1000")]] ) as IERC20;

      
    console.log("TokenA address:", await tokenA.getAddress());
    console.log("TokenB address:", await tokenB.getAddress());
    console.log("TokenC address:", await tokenC.getAddress());
    
    const tokenAOwnerBalance = await tokenA.balanceOf(deployer.address);
    console.log("Token A balance:", ethers.formatEther(tokenAOwnerBalance));
    const tokenBOwnerBalance = await tokenB.balanceOf(deployer.address);
    console.log("TokenB  balance:", ethers.formatEther(tokenBOwnerBalance));
    const tokenCOwnerBalance = await tokenB.balanceOf(deployer.address);
    console.log("TokenC  balance:", ethers.formatEther(tokenCOwnerBalance));

        await( await tokenA.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();
        await( await tokenB.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();
        await( await tokenC.approve(await uniswapV2.v2_router.getAddress(), MaxUint256)).wait();

        // Create pair TokenA -> TokenC
        await (await uniswapV2.v2_core_factory.createPair(tokenA.target, tokenC.target)).wait();
        const V2pairA2CAddress = await uniswapV2.v2_core_factory.getPair(tokenA.target, tokenC.target);
        console.log(`TokenA -> TokenC Pair deployed to ${V2pairA2CAddress}`);
        const V2pairA2C = new Contract(V2pairA2CAddress, IUniswapV2Pair.abi, deployer);
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
            deployer,
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
        const V2pairB2C = new Contract(V2pairB2CAddress, IUniswapV2Pair.abi, deployer);
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
            deployer,
            deadline
          );
        await addLiquidityTxB.wait();
        const reservesB = await V2pairB2C.getReserves();
        console.log(`Reserves TokenB -> TokenC: ${reservesB[0].toString()}, ${reservesB[1].toString()}`);
        console.log(`Total liquidity TokenB -> TokenC: ${await V2pairB2C.totalSupply()}`);

    
    return  {
        weth9,
        ...uniswapV2,
        tokenA,
        tokenB,
        tokenC,
        V2pairA2C,
        V2pairB2C
    }
}



    


  