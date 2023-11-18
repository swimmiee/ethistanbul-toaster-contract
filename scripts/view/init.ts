import { ethers } from "hardhat";
import { BigNumber } from "ethers";

async function init() {
  const toasterPool = await ethers.getContractAt(
    "ToasterPool",
    "0x7f9d5575843a4B8Ef84818ec6bf02C6eda5807AE"
  );

  const poolAddress = await toasterPool.pool();
  const pool = await ethers.getContractAt("IUniswapV3Pool", poolAddress);

  const [signer] = await ethers.getSigners();

  const token0 = await ethers.getContractAt(
    "IERC20",
    "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
  );

  // USDC
  const token1 = await ethers.getContractAt(
    "IERC20",
    "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
  );

  const ethAmount = ethers.utils.parseEther("0.000005");
  const usdcAmount = BigNumber.from(10);
  console.log(await token0.balanceOf(signer.address));
  console.log(ethAmount);
  console.log(await token1.balanceOf(signer.address));
  console.log(usdcAmount);

  const ap1 = await token0.approve(toasterPool.address, ethers.constants.MaxUint256);
  const ap2 = await token1.approve(toasterPool.address, ethers.constants.MaxUint256);
  await ap1.wait();
  await ap2.wait();
  //   console.log("approved");

  console.log("Before", await toasterPool.state());

  const slot0 = await pool.slot0();
  const tickSpacing = await pool.tickSpacing();

  const currentTick = Math.floor(slot0.tick / tickSpacing) * tickSpacing;

  console.log(currentTick - 3 * tickSpacing, currentTick + 3 * tickSpacing);
  const init = await toasterPool.init(
    currentTick - 3 * tickSpacing,
    currentTick + 3 * tickSpacing,
    ethAmount,
    usdcAmount
  );
  await init.wait();
  console.log("init");

  console.log("After", await toasterPool.state());

  // await signer.getBalance()
  // console.log(await pool.slot0())

  // console.log(await toasterPool.isInRange())

  // toasterPool.init(

  // )
}

init();

// npx hardhat run scripts/view/init.ts --network=arbitrum
