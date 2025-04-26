import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";


const config: HardhatUserConfig = {
  
  networks: {
    hardhat: {
      chainId: 1337,
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/your-alchemy-key",
        blockNumber: 12345678,
      },
    },
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/your-alchemy-key",
      accounts: [vars.get("PRIVATE_KEY")],
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
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
