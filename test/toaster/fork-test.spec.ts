import { ethers, network } from "hardhat";
import { BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  impersonateAccount,
  setBalance,
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { deployToasterPool, deployZap } from "../../scripts/deploy";
import makeWETH from "../../scripts/utils/makeWETH";
import approveToken from "../../scripts/utils/approve";
import { IUniswapV3Pool, ToasterPool } from "../../typechain";

const { parseEther, formatEther, parseUnits, formatUnits } = ethers.utils;

// npx hardhat test test/fork-test.spePOLYGON.ts
describe("Arbitrum One Fork Test", () => {
  let signer: SignerWithAddress;
  let taker: SignerWithAddress;
  let toasterPool: ToasterPool;
  let pool: IUniswapV3Pool;
  const c = {
    WETH: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    USDC: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    USDC_WETH_POOL: "0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c",
    MANAGER: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
    ONE_INCH: "0x1111111254EEB25477B68fb85Ed929f73A960582",
    MATIC_ROUTER: "0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10",
    SWAP_ROUTER: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
  };

  const POLYGON = {
    WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
    POLY_USDC_WMATIC_POOL : "0x2DB87C4831B2fec2E35591221455834193b50D1B",
    ONE_INCH: "0x1111111254EEB25477B68fb85Ed929f73A960582",
    MANAGER: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
    MATIC_ROUTER: "0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10",//chainlink function router
    SWAP_ROUTER:"0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"
  }
  
  before("Deploy", async () => {
    
    const signers = await ethers.getSigners();
    signer = signers[0];
    taker = signers[1];

    await setBalance(signer.address, parseEther("10000"));
    pool = await ethers.getContractAt("IUniswapV3Pool", POLYGON.POLY_USDC_WMATIC_POOL);
    await makeWETH("100", POLYGON.WMATIC);
    const swap_router = await ethers.getContractAt(
      "IV3SwapRouter",
      POLYGON.SWAP_ROUTER
    );
    await approveToken(POLYGON.WMATIC, POLYGON.SWAP_ROUTER);
    await swap_router.exactInputSingle({
      tokenIn: POLYGON.WMATIC,
      tokenOut: POLYGON.USDC,
      fee: 3000,
      recipient: signer.address,
      amountIn: ethers.utils.parseEther("30"),
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0,
    });

    const zap = await deployZap();
    toasterPool = await deployToasterPool(
      zap.address,
      POLYGON.MANAGER,
      POLYGON.POLY_USDC_WMATIC_POOL,
      POLYGON.ONE_INCH,
      POLYGON.MATIC_ROUTER
    );

    await approveToken(POLYGON.WMATIC, toasterPool.address);
    await approveToken(POLYGON.USDC, toasterPool.address);
  });

  it("Init", async () => {
    const token0 = await ethers.getContractAt("IERC20", POLYGON.WMATIC);
    const token1 = await ethers.getContractAt("IERC20", POLYGON.USDC);

    console.log(await token0.balanceOf(signer.address));
    console.log(await token1.balanceOf(signer.address));

    const ethAmount = parseEther("0.000005");
    const usdcAmount = BigNumber.from(100);

    const ap1 = await token0.approve(
      toasterPool.address,
      ethers.constants.MaxUint256
    );
    const ap2 = await token1.approve(
      toasterPool.address,
      ethers.constants.MaxUint256
    );
    await ap1.wait();
    await ap2.wait();

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();
    const currentTick = Math.floor(slot0.tick / tickSpacing) * tickSpacing;

    const init = await toasterPool.init(
      currentTick - 3 * tickSpacing,
      currentTick + 3 * tickSpacing,
      ethAmount,
      usdcAmount
    );
    await init.wait();
    const state = await toasterPool.state();

    expect(state.tokenId).gt(0);
  });

  it.skip("Mock 1inch fillOrderPostInteraction", async () => {
    await impersonateAccount(POLYGON.ONE_INCH);
    const oneInch = await ethers.getSigner(POLYGON.ONE_INCH);
    await setBalance(oneInch.address, parseEther("1000000"));

    const beforeState = await toasterPool.state();
    const encoder = new ethers.utils.AbiCoder();

    // 유저가 10 USDC를 ETH로 스왑 요청한 상황
    // 첫 번째에는 스왑이 7 USDC만 됐다
    // 두 번째에서 나머지 스왑 다 이루어지는 상황 가정
    const interactionData = encoder.encode(
      ["address", "uint256"],
      [POLYGON.USDC, "1000"]
    );

    const mockOrderHash = ethers.utils.hexZeroPad("0x", 32);

    const r1 = await toasterPool
      .connect(oneInch)
      .fillOrderPostInteraction(
        mockOrderHash,
        signer.address,
        taker.address,
        "700",
        "200000",
        "300",
        interactionData
      )
      .then((t) => t.wait());

    const r1State = await toasterPool.state();
    const r1Balance = await toasterPool.balances(signer.address, POLYGON.WMATIC);
    expect(r1State.liquidity).eq(beforeState.liquidity);
    expect(r1Balance).eq("200000");

    const token0 = await ethers.getContractAt("IERC20", POLYGON.WMATIC);
    const token1 = await ethers.getContractAt("IERC20", POLYGON.USDC);

    const r2 = await toasterPool
      .connect(oneInch)
      .fillOrderPostInteraction(
        mockOrderHash,
        signer.address,
        taker.address,
        "300",
        "800",
        "0",
        interactionData
      )
      .then((t) => t.wait());

    const r2State = await toasterPool.state();
    const r2Balance = await toasterPool.balances(signer.address, POLYGON.WMATIC);

    console.log("USDC", await token0.balanceOf(signer.address));
    console.log("WETH", await token1.balanceOf(signer.address));
    expect(r2State.liquidity).gt(beforeState.liquidity);
    expect(r2Balance).eq("0");
  });
});
