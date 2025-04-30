import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import TransparentUpgradeableProxy from "../node_modules/@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json";


async function main() {
    const [deployer] = await ethers.getSigners();
    const BaseInvestAddress = "0x9ead68b8Cc8e3b9B6A262E3cCE90Bc44c7B450f7";
    const ProxyAddress = "0x6C506489a782C12D018838cBD204aE8Ba1816cB8";



    const baseInvest = await ethers.getContractAt("BaseInvest", BaseInvestAddress);  
    const proxy = new Contract(ProxyAddress, TransparentUpgradeableProxy.abi)
      const initializeData = baseInvest.interface.encodeFunctionData("initialize", [deployer.address]);
    //   const proxy = await proxy_factory.deploy(await baseInvest.getAddress(), deployer.address, initializeData);
    console.log("Data:", initializeData);
    // console.log("Constructor parameters:", baseInvest.interface.encodeFunctionData("constructor", initializeData));

    const abiEncoder = new ethers.AbiCoder();
    const encodedArgs = abiEncoder.encode(
        ['address','address','bytes'],
        [BaseInvestAddress, deployer.address, initializeData]);

    console.log("Encoded Constructor Arguments:", encodedArgs);

    


}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }
    );