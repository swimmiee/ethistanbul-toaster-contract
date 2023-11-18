// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.7.5;

import {IUniswapV3Pool}from"@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
interface IToasterPool {
    
    struct PoolState {
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint128 totalShare;
    }
    function init(
        int24 tickLower,
        int24 tickUpper,
        uint amount0,
        uint amount1
    ) external;
    function increaseLiquidity(
        address user,
        uint amount0,
        uint amount1
    ) external;
    function decreaseLiqduidity(address user, uint128 decreasedShare)external;
    
    function reinvest() external;
    // function userShareOf(address user) external view returns (uint share, uint liquidity, uint amount0, uint amount1);
    function rebalance(int24 tickLower, int24 tickUpper) external;
    function pool() external view returns (IUniswapV3Pool);
    function lock() external;
    function locked() external view returns(bool);
    function isInRange() external view returns (bool inRange);
    
}