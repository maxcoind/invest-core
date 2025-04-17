
import { ethers } from "hardhat";
import { ContractFactory} from "ethers";

import UniswapV2Factory from '@uniswap/v2-core/build/UniswapV2Factory.json';
import UniswapV2Router02 from '@uniswap/v2-periphery/build/UniswapV2Router02.json'; 

import { uniswap } from "../../typechain-types";




// src/util/WETH9.json


export async function UniswapV2deploy(weth9 : string ) {
    const [owner] = await ethers.getSigners();
  
    // DEPLOY_V2_CORE_FACTORY
    const v2_core_factory = await(new ContractFactory(
      UniswapV2Factory.abi, UniswapV2Factory.bytecode,
      owner
    )).deploy(owner.address) as uniswap.v2Core.contracts.interfaces.IUniswapV2Factory;
  
    // DEPLOY V2 ROUTER
    const v2_router = await(new ContractFactory(
      UniswapV2Router02.abi, UniswapV2Router02.bytecode,
      owner
    )).deploy(
      await v2_core_factory.getAddress(),
      weth9
    ) as uniswap.v2Periphery.contracts.interfaces.IUniswapV2Router02;
  
    return {v2_core_factory, v2_router}
  }
  