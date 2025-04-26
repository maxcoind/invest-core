import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";


const config: HardhatUserConfig = {
  
  networks: {
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [vars.get("PRIVATE_KEY")],
    }
  
  },
  etherscan: {
    apiKey: {
      bsc: 'vars.get("ETHERSCAN_KEY")'
    }
  },
  sourcify: {
    enabled: true
  },
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20_000,
      },
    }
  },
};



export default config;
