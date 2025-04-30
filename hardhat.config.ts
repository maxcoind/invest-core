import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";


const config: HardhatUserConfig = {
  
  networks: {
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [vars.get("PRIVATE_KEY")],
    },
    bscmain: {
      url: "https://side-blissful-general.bsc.quiknode.pro/" + vars.get("QUICKNODE_TOKEN") ,
      chainId: 56,
      accounts: [vars.get("PRIVATE_KEY")],
    },
    anvil: {
      url: "http://127.0.0.1:8545/",
      chainId: 31337,
      accounts: [vars.get("LOCAL_KEY"), vars.get("LOCAL_KEY_1"), vars.get("LOCAL_KEY_2")],
    }

  
  },
  etherscan: {
    apiKey: {
       bsc: vars.get("BSCSCAN_KEY"),
    }
  },
  sourcify: {
    enabled: true
  },

  solidity: {
    compilers: [
      {
        version: "0.8.29",
        settings: {
          optimizer: {
            enabled: true,
            runs: 20_000,
          },
        },
      },
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  }
};



export default config;
