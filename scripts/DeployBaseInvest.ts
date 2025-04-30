import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import TransparentUpgradeableProxy from "../node_modules/@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json";


async function deployBaseInvest(
  tokenA: string,
  tokenB: string,
  V2router: string
) {
    
    
    const [deployer] = await ethers.getSigners();
      // deploy with transparent proxy
  const BaseInvestFactory = await ethers.getContractFactory("BaseInvest");
  const baseInvest = await BaseInvestFactory.deploy(tokenA, tokenB, V2router);
    await baseInvest.waitForDeployment();
  console.log("BaseInvest deployed to:", await baseInvest.getAddress());
  const proxy_factory = await(new ContractFactory(
    TransparentUpgradeableProxy.abi, TransparentUpgradeableProxy.bytecode,
    deployer
  ));

  const initializeData = baseInvest.interface.encodeFunctionData("initialize", [deployer.address]);
  const proxy = await proxy_factory.deploy(await baseInvest.getAddress(), deployer.address, initializeData);
  console.log("Proxy deployed to:", await proxy.getAddress());
  const adminChangedEventFilter = proxy.filters.AdminChanged();
  await proxy.waitForDeployment();

  const adminChangedEvents = await proxy.queryFilter(adminChangedEventFilter);
  const adminProxyAddress = adminChangedEvents[0].args[1];


  const baseInvestProxy = new Contract(
    await proxy.getAddress(),
    BaseInvestFactory.interface,
    deployer
  );

  return {
    baseInvest,
    adminProxyAddress,
    baseInvestProxy
  }
}

async function main() {

    console.log("Deploying BaseInvest...");

    const tokenA = "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d"; 
    const tokenB = "0xca1262e77fb25c0a4112cfc9bad3ff54f617f2e6";
    const V2router = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    // const tokenA = "0x46b142DD1E924FAb83eCc3c08e4D46E82f005e0E"; 
    // const tokenB = "0xC9a43158891282A2B1475592D5719c001986Aaec";
    // const V2router = "0xfbC22278A96299D91d41C453234d97b4F5Eb9B2d";
    

    const { baseInvest, adminProxyAddress, baseInvestProxy } = await deployBaseInvest(tokenA, tokenB, V2router);
    console.log("BaseInvest deployed to:", await baseInvest.getAddress());
    console.log("Proxy Admin:", adminProxyAddress);
    console.log("BaseInvest proxy deployed to:", await baseInvestProxy.getAddress());
    console.log("Granting superadmin role...");
    await baseInvestProxy.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", "0x9aF4a85714637bF2c015263c556024213977B6E8");


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
