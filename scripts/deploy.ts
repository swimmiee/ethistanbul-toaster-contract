
import { ethers, network } from "hardhat";
import { updateConfig } from "./utils/updateConfig";
import { ZapCalculator,ToasterPool__factory, ToasterStrategy__factory, ZapCalculator__factory } from "../typechain";

const MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"; //
const ARBI_USDC_WETH_POOL = "0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c"; //arbitrum pool
const ONE_INCH = "0x1111111254EEB25477B68fb85Ed929f73A960582";
const SEPOLIA_ROUTER = "0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10";//chainlink function router

export const deployZap = async () : ZapCalculator => {
  const zap_f:ZapCalculator__factory = await ethers.getContractFactory("ZapCalculator");
  return zap_f.deploy().then((tx) => tx.deployed());
};

export const deployToasterPool = async (
  zap: string,
  manager: string,
  pool: string,
  _1inch: string,
  strategy:string
) => {
  const toaster_f:ToasterPool__factory = await ethers.getContractFactory("ToasterPool");
  const toaster = await toaster_f
    .deploy(zap, manager, pool, _1inch, strategy)
    .then((tx) => tx.deployed());

  return toaster;
};

export const deployStrategy = async (router:string) => {
  const strategy_f: ToasterStrategy__factory = await ethers.getContractFactory("ToasterStrategy");
  const strategy = await strategy_f.deploy(router);
  return strategy;
}

async function main() {
  // const zap = await deployZap();
  // updateConfig(
  //   `./config/${network.name}.json`,
  //   "TOASTER_ZAP",
  //   zap.address,
  //   false
  // );
  // const strategy = await deployStrategy(SEPOLIA_ROUTER);
  // updateConfig(
  //   `./config/${network.name}.json`,
  //   "TOASTER_STRATEGY",
  //   strategy.address,
  //   false
  // );
  // const toaster = await deployToasterPool(
  //   zap.address,
  //   MANAGER,
  //   ARBI_USDC_WETH_POOL,
  //   ONE_INCH,
  //   strategy.address
  // );
  const toaster = await deployToasterPool(
    "0x9C89B69CfAef1DfA1DECEFe8f7F949D87A465df2",
    MANAGER,
    ARBI_USDC_WETH_POOL,
    ONE_INCH,
    "0xc0e918b2e9067B80ecD6522B2dd18Dc0586Fe873"
  );

  updateConfig(
    `./config/${network.name}.json`,
    "TOASTER_USDC_WETH_POOL",
    toaster.address,
    false
  );
}

main();
// npx hardhat run scripts/deploy.ts
