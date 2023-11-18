import { ContractReceipt } from "@ethersproject/contracts/lib.esm/index.d"
import { ethers, network } from "hardhat"
import { expect } from "chai"
import makeWETH from "../../scripts/utils/makeWETH"
import approveToken from "../../scripts/utils/approve"
import getBalanceOf from "../../scripts/utils/balance"
import { INonfungiblePositionManager, ISwapRouter02, ToasterZapTest } from "../../typechain"
import { BigNumber } from "ethers"
const WETH9 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
const POOL = "0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8"
const ROUTER = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"
const MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
const V3_MINT_EVENT_SIGNATURE = "0x7a53080ba414158be7ec69b987b5fb7d07dee101fe85488f0853ae16239d0bde"
function splitHash(hash: string): string[] {
    if (hash.slice(0, 2) !== "0x" || (hash.length - 2) % 64 > 0) return []
    hash = hash.slice(2)
    const numChunks = Math.ceil(hash.length / 64)
    const chunks = new Array(numChunks)
    for (let i = 0, o = 0; i < numChunks; ++i, o += 64) {
        chunks[i] = "0x" + hash.slice(o, o + 64)
    }
    return chunks
}
function getAddLiquidityAmountFromReceipt(receipt: ContractReceipt): bigint[] {
    const mintLogs = receipt.logs.filter((l) => l.topics[0] === V3_MINT_EVENT_SIGNATURE)
    const { data: mintData } = mintLogs[mintLogs.length - 1]
    // amount0, amount1, sqrtPriceX96, liquidity, tick
    const [sender, amount, amount0, amount1] = splitHash(mintData).map(BigInt)
    return [amount0, amount1]
}

describe("Test Toaster Zap", () => {
    let zap: ToasterZapTest
    let router: ISwapRouter02
    let manager: INonfungiblePositionManager
    before("Make enough USDC & ETH", async () => {
        // await network.provider.request({
        //     method: "hardhat_reset",
        //     params: [
        //         {
        //             forking: {
        //                 jsonRpcUrl: "https://arbitrum.llamarpc.com",
        //                 enabled: true,
        //                 ignoreUnknownTxType: true,
        //             },
        //         },
        //     ],
        // })

        const [owner] = await ethers.getSigners()
        await makeWETH("100", WETH9)
        await approveToken(WETH9, ROUTER)
        await approveToken(USDC, ROUTER)
        await approveToken(WETH9, MANAGER)
        await approveToken(USDC, MANAGER)
        router = await ethers.getContractAt("ISwapRouter02", ROUTER)
        manager = await ethers.getContractAt("INonfungiblePositionManager", MANAGER)
        await router.exactInputSingle({
            tokenIn: WETH9,
            tokenOut: USDC,
            fee: 3000,
            recipient: owner.address,
            amountIn: ethers.utils.parseEther("30"),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0,
        })

        expect(await getBalanceOf(WETH9, owner.address)).to.be.eq(ethers.utils.parseEther("70"))
        expect(await getBalanceOf(USDC, owner.address)).to.be.eq(BigNumber.from(53705841913))

        zap = await ethers
            .getContractFactory("ToasterZapTest")
            .then((f) => f.deploy())
            .then((c) => c.deployed())
    })

    it("Rebalancing Test", async () => {
        const [owner] = await ethers.getSigners()
        const pool = await ethers.getContractAt("IUniswapV3Pool", POOL)
        const currentTick = await pool.slot0().then((slot0) => slot0.tick)
        const upperTick = Math.floor((currentTick + 360) / 60) * 60
        const lowerTick = Math.floor((currentTick - 240) / 60) * 60
        let amount0Desired = ethers.utils.parseUnits("5000", 6)
        let amount1Desired = ethers.utils.parseEther("15")
        // USDC - 0, WETH - 1
        const { amountIn, amountOut, zeroForOne } = await zap.getOptimalSwap(
            POOL,
            lowerTick,
            upperTick,
            amount0Desired,
            amount1Desired
        )

        const [tokenIn, tokenOut] = zeroForOne ? [USDC, WETH9] : [WETH9, USDC]
        const before = await getBalanceOf(tokenOut, owner.address)
        await router.exactInputSingle({
            tokenIn,
            tokenOut,
            fee: 3000,
            recipient: owner.address,
            amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0,
        })
        expect(await getBalanceOf(USDC, owner.address)).to.be.eq(before.add(amountOut))

        amount0Desired = !zeroForOne ? amount0Desired.add(amountOut) : amount0Desired.sub(amountIn)
        amount1Desired = zeroForOne ? amount1Desired.add(amountOut) : amount1Desired.sub(amountIn)

        const mintParams: INonfungiblePositionManager.MintParamsStruct = {
            token0: USDC,
            token1: WETH9,
            fee: 3000,
            tickLower: lowerTick,
            tickUpper: upperTick,
            amount0Desired,
            amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: owner.address,
            deadline: ethers.constants.MaxUint256,
        }

        const [amount0, amount1] = await manager
            .mint(mintParams)
            .then((tx) => tx.wait())
            .then(getAddLiquidityAmountFromReceipt)
        amount0Desired = amount0Desired.sub(amount0)
        amount1Desired = amount1Desired.sub(amount1)
        expect(amount0Desired).to.be.eq(0)
        expect(ethers.utils.formatEther(amount1Desired)).to.be.eq("0.000000025329022223")
    })
})
