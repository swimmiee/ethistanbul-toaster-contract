import { ethers, network } from "hardhat";
import { updateConfig } from "./utils/updateConfig";

const MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"; //
const ARBI_USDC_WETH_POOL = "0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c"; //arbitrum pool
const ONE_INCH = "0x1111111254EEB25477B68fb85Ed929f73A960582";

// TODO: 이거 뭐지요?
const MATIC_ROUTER = "0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10";

export const deployZap = async () => {
  const zap_f = await ethers.getContractFactory("ZapCalculator");
  return zap_f.deploy().then((tx) => tx.deployed());
};

export const deployToasterPool = async (
  zap: string,
  manager: string,
  pool: string,
  _1inch: string,
  router: string
) => {
  const toaster_f = await ethers.getContractFactory("ToasterPool");
  const toaster = await toaster_f
    .deploy(zap, manager, pool, _1inch, router)
    .then((tx) => tx.deployed());

  return toaster;
};

async function main() {
  const zap = await deployZap();
  updateConfig(
    `./config/${network.name}.json`,
    "TOASTER_ZAP",
    zap.address,
    false
  );

  const toaster = await deployToasterPool(
    zap.address,
    MANAGER,
    ARBI_USDC_WETH_POOL,
    ONE_INCH,
    MATIC_ROUTER
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
