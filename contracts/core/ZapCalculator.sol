// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.7.5;
import {ToasterZap, IUniswapV3Pool} from "../library/ToasterZap.sol";
import {IZapCalculator} from "../interfaces/IZapCalculator.sol";


contract ZapCalculator is IZapCalculator {
    // TODO: swap token0 -> token1 or vice versa
    // to meet exact ratio required by uniswap v3
    function zap(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint amount0Desired,
        uint amount1Desired
    ) external view override returns (uint256 amountIn, uint256 amountOut, bool zeroForOne, uint160 sqrtPriceX96) {
        return ToasterZap
            .getOptimalSwap(
                pool,
                tickLower,
                tickUpper,
                amount0Desired,
                amount1Desired
            );
        // (uint amountIn, uint amountOut, bool zeroForOne, ) = ToasterZap
        //     .getOptimalSwap(
        //         pool,
        //         tickLower,
        //         tickUpper,
        //         amount0Desired,
        //         amount1Desired
        //     );

        // if (zeroForOne) {
        //     (newAmount0, newAmount1) = (
        //         amount0Desired - amountIn,
        //         amount1Desired + amountOut
        //     );
        // } else {
        //     (newAmount0, newAmount1) = (
        //         amount0Desired + amountOut,
        //         amount1Desired - amountIn
        //     );
        // }
    }
}
