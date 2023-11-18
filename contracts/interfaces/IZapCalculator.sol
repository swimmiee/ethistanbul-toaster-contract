import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface IZapCalculator {
    function zap(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint amount0Desired,
        uint amount1Desired
    ) external view returns (uint256 amountIn, uint256 amountOut, bool zeroForOne, uint160 sqrtPriceX96);
}
