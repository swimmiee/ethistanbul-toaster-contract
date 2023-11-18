
import { ethers, network } from "hardhat";
import { updateConfig } from "./utils/updateConfig";
import { ZapCalculator,ToasterPool__factory, ToasterStrategy__factory, ZapCalculator__factory, ToasterPool } from "../typechain";
import { BigNumber } from "ethers";

const MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"; //
const ARBI_USDC_WETH_POOL = "0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c"; //arbitrum pool
const ONE_INCH = "0x1111111254EEB25477B68fb85Ed929f73A960582";

const POLYGON = {
  WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
  USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
  USDC_WMATIC_POOL : "0x2DB87C4831B2fec2E35591221455834193b50D1B",
  ONE_INCH: "0x1111111254EEB25477B68fb85Ed929f73A960582",
  MANAGER: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
  LINK_ROUTER: "0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10",//chainlink function router
  ZAP: "0x898cA87e088fd4c8F83C17a8a2c6AFc1D4aFDE6a",
  STRATEGY:"0xBd770416a3345F91E4B34576cb804a576fa48EB1"
}

const LINEA = {
  WETH: "0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f",
  USDC: "0x176211869ca2b568f2a7d4ee941e073a821ee1ff",
  USDC_WETH_POOL: "0x86f3336AD51501bd3187771E05B08Bd58c346644",
  ONE_INCH: "0x1111111254EEB25477B68fb85Ed929f73A960582",//not valid
  MANAGER: ethers.constants.AddressZero, // pancakeswap
  LINK_ROUTER:ethers.constants.AddressZero
}
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

export const init = async (toasterPool: string, pool:string) => {
  const [signer] = await ethers.getSigners();

  const token0 = await ethers.getContractAt("IERC20", POLYGON.WMATIC);
  const token1 = await ethers.getContractAt("IERC20", POLYGON.USDC);

  console.log(await token0.balanceOf(signer.address));
  console.log(await token1.balanceOf(signer.address));

  const ethAmount = ethers.utils.parseEther("0.0000001");
  const usdcAmount = BigNumber.from(100);

  const ap1 = await token0.approve(
    toasterPool,
    ethers.constants.MaxUint256
  );
  const ap2 = await token1.approve(
    toasterPool,
    ethers.constants.MaxUint256
  );
  await ap1.wait();
  await ap2.wait();
  const p = await ethers.getContractAt("IUniswapV3Pool", pool);
  const slot0 = await p.slot0();
  const tickSpacing = await p.tickSpacing();
  const currentTick = Math.floor(slot0.tick / tickSpacing) * tickSpacing;
  const toaster:ToasterPool= await ethers.getContractAt("ToasterPool", toasterPool);
  const init = await toaster.init(
    currentTick - 3 * tickSpacing,
    currentTick + 3 * tickSpacing,
    ethAmount,
    usdcAmount
  );
  await init.wait();

  console.log(await toaster.state())
}
async function main() {
  const zap = await deployZap();
  updateConfig(
    `./config/${network.name}.json`,
    "TOASTER_ZAP",
    zap.address,
    false
  );
  const strategy = await deployStrategy(POLYGON.LINK_ROUTER);
  updateConfig(
    `./config/${network.name}.json`,
    "TOASTER_STRATEGY",
    strategy.address,
    false
  );
  
  const toaster = await deployToasterPool(
    POLYGON.ZAP,
    POLYGON.MANAGER,
    POLYGON.USDC_WMATIC_POOL,
    POLYGON.ONE_INCH,
    POLYGON.STRATEGY
  )
  updateConfig(
    `./config/${network.name}.json`,
    "TOASTER_USDC_WETH_POOL",
    toaster.address,
    false
  );
  
  await init(toaster.address, POLYGON.USDC_WMATIC_POOL);
  
}

main();
// npx hardhat run scripts/deploy.ts
