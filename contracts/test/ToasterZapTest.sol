// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.7.5;
import {ToasterZap,IUniswapV3Pool} from "../library/ToasterZap.sol";
contract ToasterZapTest {
    function getOptimalSwap(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external view returns (uint256 amountIn, uint256 amountOut, bool zeroForOne, uint160 sqrtPriceX96) {
        return ToasterZap.getOptimalSwap(pool, tickLower, tickUpper, amount0Desired, amount1Desired);
    }
}