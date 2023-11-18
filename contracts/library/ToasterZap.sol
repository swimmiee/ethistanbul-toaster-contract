// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity  0.7.5;
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {UnsafeMath} from "@uniswap/v3-core/contracts/libraries/UnsafeMath.sol";
import {TickBitmap} from "@uniswap/v3-core/contracts/libraries/TickBitmap.sol";
import {SqrtPriceMath} from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import {LowGasSafeMath} from "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import {SwapMath} from "@uniswap/v3-core/contracts/libraries/SwapMath.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {SafeCast} from "@uniswap/v3-core/contracts/libraries/SafeCast.sol";
import {BitMath} from "@uniswap/v3-core/contracts/libraries/BitMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

library ToasterZap {
    using TickMath for int24;
    using FullMath for uint256;
    using UnsafeMath for uint256;
    using LowGasSafeMath for uint256;
    using SafeCast for uint256;
    uint256 internal constant MAX_FEE_PIPS = 1e6;

    struct SwapState {
        // liquidity in range after swap, accessible by `mload(state)`
        uint128 liquidity;
        // sqrt(price) after swap, accessible by `mload(add(state, 0x20))`
        uint256 sqrtPriceX96;
        // tick after swap, accessible by `mload(add(state, 0x40))`
        int24 tick;
        // The desired amount of token0 to add liquidity, `mload(add(state, 0x60))`
        uint256 amount0Desired;
        // The desired amount of token1 to add liquidity, `mload(add(state, 0x80))`
        uint256 amount1Desired;
        // sqrt(price) at the lower tick, `mload(add(state, 0xa0))`
        uint256 sqrtRatioLowerX96;
        // sqrt(price) at the upper tick, `mload(add(state, 0xc0))`
        uint256 sqrtRatioUpperX96;
        // the fee taken from the input amount, expressed in hundredths of a bip
        // accessible by `mload(add(state, 0xe0))`
        uint256 feePips;
        // the tick spacing of the pool, accessible by `mload(add(state, 0x100))`
        int24 tickSpacing;
    }

    /// @notice Get swap amount, output amount, swap direction for double-sided optimal deposit
    /// @dev Given the elegant analytic solution and custom optimizations to Uniswap libraries,
    /// the amount of gas is at the order of 10k depending on the swap amount and the number of ticks crossed,
    /// an order of magnitude less than that achieved by binary search, which can be calculated on-chain.
    /// @param pool Uniswap v3 pool
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount0Desired The desired amount of token0 to be spent
    /// @param amount1Desired The desired amount of token1 to be spent
    /// @return amountIn The optimal swap amount
    /// @return amountOut Expected output amount
    /// @return zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @return sqrtPriceX96 The sqrt(price) after the swap
    function getOptimalSwap(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal view returns (uint256 amountIn, uint256 amountOut, bool zeroForOne, uint160 sqrtPriceX96) {
        if (amount0Desired == 0 && amount1Desired == 0) return (0, 0, false, 0);
        if (tickLower >= tickUpper || tickLower < TickMath.MIN_TICK || tickUpper > TickMath.MAX_TICK) revert("Invalid Range");
            
        {
            // Ensure the pool exists.
            uint256 poolCodeSize;
            assembly {
                poolCodeSize := extcodesize(pool)
            }
            if (poolCodeSize == 0) revert("Invalid Pool");
        }
        // intermediate state cache
        SwapState memory state;
        // Populate `SwapState` with hardcoded offsets.
        (sqrtPriceX96, state.tick,,,,,) = pool.slot0();
        {
            uint128 liquidity = pool.liquidity();
            uint256 feePips = pool.fee();
            int24 tickSpacing = pool.tickSpacing();
            
            state.liquidity = liquidity;
            
            state.sqrtPriceX96 = sqrtPriceX96;
            
            state.amount0Desired = amount0Desired;
            
            state.amount1Desired = amount1Desired;
            
            state.feePips = feePips;
            
            state.tickSpacing = tickSpacing;
                
            
        }
        uint160 sqrtRatioLowerX96 = tickLower.getSqrtRatioAtTick();
        uint160 sqrtRatioUpperX96 = tickUpper.getSqrtRatioAtTick();
        
        state.sqrtRatioLowerX96 = sqrtRatioLowerX96;
        
        state.sqrtRatioUpperX96 = sqrtRatioUpperX96;
            
        
        zeroForOne = isZeroForOne(amount0Desired, amount1Desired, sqrtPriceX96, sqrtRatioLowerX96, sqrtRatioUpperX96);
        // Simulate optimal swap by crossing ticks until the direction reverses.
        crossTicks(pool, state, sqrtPriceX96, zeroForOne);
        // Active liquidity at the last tick of optimal swap
        uint128 liquidityLast;
        // sqrt(price) at the last tick of optimal swap
        uint160 sqrtPriceLastTickX96;
        // Remaining amount of token0 to add liquidity at the last tick
        uint256 amount0LastTick;
        // Remaining amount of token1 to add liquidity at the last tick
        uint256 amount1LastTick;
       
        liquidityLast = state.liquidity;
        
        sqrtPriceLastTickX96 = state.sqrtPriceX96.toUint160();
        amount0LastTick = state.amount0Desired;
        
        amount1LastTick = state.amount1Desired;
            
        
        {
            if (zeroForOne) {
                // The final price is in range. Use the closed form solution.
                if (sqrtPriceLastTickX96 <= sqrtRatioUpperX96) {
                    sqrtPriceX96 = solveOptimalZeroForOne(state);
                    amountIn =
                        amount0Desired -
                        amount0LastTick +
                        (SqrtPriceMath.getAmount0Delta(sqrtPriceX96, sqrtPriceLastTickX96, liquidityLast, true) *
                            MAX_FEE_PIPS).divRoundingUp(MAX_FEE_PIPS - state.feePips);
                }
                // The final price is out of range. Simply consume all token0.
                else {
                    amountIn = amount0Desired;
                    sqrtPriceX96 = SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(
                        sqrtPriceLastTickX96,
                        liquidityLast,
                        FullMath.mulDiv(amount0LastTick, MAX_FEE_PIPS - state.feePips, MAX_FEE_PIPS),
                        true
                    );
                }
                amountOut =
                    amount1LastTick -
                    amount1Desired +
                    SqrtPriceMath.getAmount1Delta(sqrtPriceX96, sqrtPriceLastTickX96, liquidityLast, false);
            } else {
                // The final price is in range. Use the closed form solution.
                if (sqrtPriceLastTickX96 >= sqrtRatioLowerX96) {
                    sqrtPriceX96 = solveOptimalOneForZero(state);
                    amountIn =
                        amount1Desired -
                        amount1LastTick +
                        (SqrtPriceMath.getAmount1Delta(sqrtPriceLastTickX96, sqrtPriceX96, liquidityLast, true) *
                            MAX_FEE_PIPS).divRoundingUp(MAX_FEE_PIPS - state.feePips);
                }
                // The final price is out of range. Simply consume all token1.
                else {
                    amountIn = amount1Desired;
                    sqrtPriceX96 = SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(
                        sqrtPriceLastTickX96,
                        liquidityLast,
                        FullMath.mulDiv(amount1LastTick, MAX_FEE_PIPS - state.feePips, MAX_FEE_PIPS),
                        true
                    );
                }
                amountOut =
                    amount0LastTick -
                    amount0Desired +
                    SqrtPriceMath.getAmount0Delta(sqrtPriceLastTickX96, sqrtPriceX96, liquidityLast, false);
            }
        }
    }

    /// @dev Check if the remaining amount is enough to cross the next initialized tick.
    // If so, check whether the swap direction changes for optimal deposit. If so, we swap too much and the final sqrt
    // price must be between the current tick and the next tick. Otherwise the next tick must be crossed.
    function crossTicks(IUniswapV3Pool pool, SwapState memory state, uint160 sqrtPriceX96, bool zeroForOne) private view {
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // Ensure the initial `wordPos` doesn't coincide with the starting tick's.
        int16 wordPos = type(int16).min;
        // a word in `pool.tickBitmap`
        uint256 tickWord;

        do {
            (tickNext, wordPos, tickWord) = nextInitializedTick(
                pool,
                state.tick,
                state.tickSpacing,
                zeroForOne,
                wordPos,
                tickWord
            );
            // sqrt(price) for the next tick (1/0)
            uint160 sqrtPriceNextX96 = tickNext.getSqrtRatioAtTick();
            // The desired amount of token0 to add liquidity after swap
            uint256 amount0Desired;
            // The desired amount of token1 to add liquidity after swap
            uint256 amount1Desired;

            {
                if (zeroForOne) {
                    // Abuse `amount0Desired` to store `amountIn` to avoid stack too deep errors.
                    (sqrtPriceX96, amount0Desired, amount1Desired) = computeSwapStepExactIn(
                        uint160(state.sqrtPriceX96),
                        sqrtPriceNextX96,
                        state.liquidity,
                        state.amount0Desired,
                        state.feePips
                    );
                    amount0Desired = state.amount0Desired - amount0Desired;
                    amount1Desired = state.amount1Desired + amount1Desired;
                } else {
                    // Abuse `amount1Desired` to store `amountIn` to avoid stack too deep errors.
                    (sqrtPriceX96, amount1Desired, amount0Desired) = computeSwapStepExactIn(
                        uint160(state.sqrtPriceX96),
                        sqrtPriceNextX96,
                        state.liquidity,
                        state.amount1Desired,
                        state.feePips
                    );
                    amount0Desired = state.amount0Desired + amount0Desired;
                    amount1Desired = state.amount1Desired - amount1Desired;
                }
            }

            // If the remaining amount is large enough to consume the current tick and the optimal swap direction
            // doesn't change, continue crossing ticks.
            if (sqrtPriceX96 != sqrtPriceNextX96) break;
            if (
                isZeroForOne(
                    amount0Desired,
                    amount1Desired,
                    sqrtPriceX96,
                    state.sqrtRatioLowerX96,
                    state.sqrtRatioUpperX96
                ) == zeroForOne
            ) {
                (,int128 liquidityNet,,,,,,) = pool.ticks(tickNext);
                    assembly {
                        liquidityNet := add(zeroForOne, xor(sub(0, zeroForOne), liquidityNet))
                    }
                    
                    state.sqrtPriceX96 = sqrtPriceX96;
                    
                    state.tick = zeroForOne ? tickNext - 1 : tickNext;
                    
                    state.amount0Desired = amount0Desired;
                    
                    state.amount1Desired = amount1Desired;
                    
                
            } else break;
        } while (true);
    }

    /// @dev Analytic solution for optimal swap between two nearest initialized ticks swapping token0 to token1
    /// @param state Pool state at the last tick of optimal swap
    /// @return sqrtPriceFinalX96 sqrt(price) after optimal swap
    function solveOptimalZeroForOne(SwapState memory state) private pure returns (uint160 sqrtPriceFinalX96) {
    
        uint256 quadratic;
        uint256 firstOrder;
        uint256 constTerm;
        uint256 sqrtPriceX96;
        {
            uint256 liquidity;
            uint256 sqrtRatioLowerX96;
            uint256 sqrtRatioUpperX96;
            uint256 feePips;
            uint256 FEE_COMPLEMENT;

                liquidity = state.liquidity;
                
                sqrtPriceX96 = state.sqrtPriceX96;
                
                sqrtRatioLowerX96 = state.sqrtRatioLowerX96;
                
                sqrtRatioUpperX96 = state.sqrtRatioUpperX96;
                
                feePips = state.feePips;
                
                FEE_COMPLEMENT = MAX_FEE_PIPS - feePips;
                
            
            {
                uint256 a0;
                uint256 amount0Desired = state.amount0Desired;
                // a = amount0Desired + liquidity / ((1 - f) * sqrtPrice) - liquidity / sqrtRatioUpper
                a0 = amount0Desired + (MAX_FEE_PIPS * (liquidity << 96) / (FEE_COMPLEMENT * sqrtPriceX96));
                quadratic = a0 - (liquidity << 96) / sqrtRatioUpperX96;
                if (quadratic  < amount0Desired) {
                    revert("Math Overflow");
                }
                firstOrder = a0.mulDiv(sqrtRatioLowerX96, FixedPoint96.Q96) + liquidity.mulDiv(feePips,FEE_COMPLEMENT);
            }
            {
                uint256 c0 = liquidity.mulDiv(sqrtPriceX96,FixedPoint96.Q96) + state.amount1Desired;
                constTerm = c0 - liquidity.mulDiv((MAX_FEE_PIPS * sqrtRatioLowerX96) / FEE_COMPLEMENT, FixedPoint96.Q96);
                firstOrder -= c0.mulDiv(FixedPoint96.Q96, sqrtRatioUpperX96);
            }
            quadratic = quadratic << 1;
            constTerm = constTerm << 1;
        }
    
        // Given a root exists, the following calculations cannot realistically overflow/underflow.
        {
            uint256 numerator = sqrt(firstOrder * firstOrder + quadratic * constTerm) + firstOrder;
            sqrtPriceFinalX96 = ((numerator << 96) / quadratic).toUint160();
        }
        // The final price must be less than or equal to the price at the last tick.
        // However the calculated price may increase if the ratio is close to optimal.
        sqrtPriceFinalX96 = (sqrtPriceFinalX96 < sqrtPriceX96 ? sqrtPriceFinalX96 : sqrtPriceX96).toUint160();
    }

    /// @dev Analytic solution for optimal swap between two nearest initialized ticks swapping token1 to token0
    /// @param state Pool state at the last tick of optimal swap
    /// @return sqrtPriceFinalX96 sqrt(price) after optimal swap
        /**
         * root = (sqrt(b^2 + 4ac) + b) / 2a
         * `a` is in the order of `amount0Desired`. `b` is in the order of `liquidity`.
         * `c` is in the order of `amount1Desired`.
         * `a`, `b`, `c` are signed integers in two's complement but typed as unsigned to avoid unnecessary casting.
         */
    function solveOptimalOneForZero(SwapState memory state) private pure returns (uint160 sqrtPriceFinalX96) {
        uint256 a;
        uint256 b;
        uint256 c;
        uint256 sqrtPriceX96;
        {
            uint256 liquidity;
            uint256 sqrtRatioLowerX96;
            uint256 sqrtRatioUpperX96;
            uint256 feePips;
            uint256 FEE_COMPLEMENT;
            
            liquidity = state.liquidity;
            
            sqrtPriceX96 = state.sqrtPriceX96;
            
            sqrtRatioLowerX96 = state.sqrtRatioLowerX96;
            
            sqrtRatioUpperX96 = state.sqrtRatioUpperX96;
            
            feePips = state.feePips;
            
            FEE_COMPLEMENT = MAX_FEE_PIPS - feePips;
                
            
            
            uint256 a0;
            a0 = state.amount0Desired + (liquidity <<96) / sqrtPriceX96;
            a = a0 - (MAX_FEE_PIPS * (liquidity<<96)) / (FEE_COMPLEMENT * sqrtRatioUpperX96);
            b = a0.mulDiv(sqrtRatioLowerX96,FixedPoint96.Q96) - (feePips * liquidity / FEE_COMPLEMENT );
                
            
            {
                // c = amount1Desired + liquidity * sqrtPrice / (1 - f) - liquidity * sqrtRatioLower
                uint256 c0 = liquidity.mulDiv((MAX_FEE_PIPS * sqrtPriceX96) / FEE_COMPLEMENT,FixedPoint96.Q96);
                uint256 amount1Desired;
                amount1Desired = state.amount1Desired;
                // c0 = amount1Desired + liquidity * sqrtPrice / (1 - f)
                c0 += amount1Desired;
                c = c0 - liquidity.mulDiv(sqrtRatioLowerX96,FixedPoint96.Q96);
                // `c` is always positive and greater than `amount1Desired`.
                
                if (c < amount1Desired) {
                    revert("Math Overflow");   
                }
                b -= c0.mulDiv(FixedPoint96.Q96, state.sqrtRatioUpperX96);
            }
            a = a << 1;
            c = c << 1;
        }
        // Given a root exists, the following calculations cannot realistically overflow/underflow.
        {
            uint256 numerator = sqrt(b * b + a * c) + b;
            assembly {
                // `numerator` and `a` may be negative so use `sdiv`.
                sqrtPriceFinalX96 := sdiv(shl(96, numerator), a)
            }
        }
        // The final price must be greater than or equal to the price at the last tick.
        // However the calculated price may decrease if the ratio is close to optimal.
        sqrtPriceFinalX96 = (sqrtPriceFinalX96 > sqrtPriceX96 ? sqrtPriceFinalX96 : sqrtPriceX96).toUint160();
    }

    /// @dev Swap direction to achieve optimal deposit when the current price is in range
    /// @param amount0Desired The desired amount of token0 to be spent
    /// @param amount1Desired The desired amount of token1 to be spent
    /// @param sqrtPriceX96 sqrt(price) at the last tick of optimal swap
    /// @param sqrtRatioLowerX96 The lower sqrt(price) of the position in which to add liquidity
    /// @param sqrtRatioUpperX96 The upper sqrt(price) of the position in which to add liquidity
    /// @return The direction of the swap, true for token0 to token1, false for token1 to token0
    function isZeroForOneInRange(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 sqrtPriceX96,
        uint256 sqrtRatioLowerX96,
        uint256 sqrtRatioUpperX96
    ) private pure returns (bool) {
        // amount0 = liquidity * (sqrt(upper) - sqrt(current)) / (sqrt(upper) * sqrt(current))
        // amount1 = liquidity * (sqrt(current) - sqrt(lower))
        // amount0 * amount1 = liquidity * (sqrt(upper) - sqrt(current)) / (sqrt(upper) * sqrt(current)) * amount1
        //     = liquidity * (sqrt(current) - sqrt(lower)) * amount0
        
            return
                amount0Desired.mulDiv(sqrtPriceX96,FixedPoint96.Q96).mulDiv(sqrtPriceX96 - sqrtRatioLowerX96,FixedPoint96.Q96) >
                amount1Desired.mulDiv(sqrtRatioUpperX96 - sqrtPriceX96, sqrtRatioUpperX96);
        
    }

    /// @dev Swap direction to achieve optimal deposit
    /// @param amount0Desired The desired amount of token0 to be spent
    /// @param amount1Desired The desired amount of token1 to be spent
    /// @param sqrtPriceX96 sqrt(price) at the last tick of optimal swap
    /// @param sqrtRatioLowerX96 The lower sqrt(price) of the position in which to add liquidity
    /// @param sqrtRatioUpperX96 The upper sqrt(price) of the position in which to add liquidity
    /// @return The direction of the swap, true for token0 to token1, false for token1 to token0
    function isZeroForOne(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 sqrtPriceX96,
        uint256 sqrtRatioLowerX96,
        uint256 sqrtRatioUpperX96
    ) internal pure returns (bool) {
        // If the current price is below `sqrtRatioLowerX96`, only token0 is required.
        if (sqrtPriceX96 <= sqrtRatioLowerX96) return false;
        // If the current tick is above `sqrtRatioUpperX96`, only token1 is required.
        else if (sqrtPriceX96 >= sqrtRatioUpperX96) return true;
        else
            return
                isZeroForOneInRange(amount0Desired, amount1Desired, sqrtPriceX96, sqrtRatioLowerX96, sqrtRatioUpperX96);
    }
    function nextInitializedTick(
        IUniswapV3Pool pool,
        int24 tick,
        int24 tickSpacing,
        bool lte,
        int16 lastWordPos,
        uint256 lastWord
    ) private view returns (int24 next, int16 wordPos, uint256 tickWord) {
    
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        uint8 bitPos;
        uint256 masked;
        uint8 sb;
        if (lte) {
            // (wordPos, bitPos) = BitMath.position(compressed);
            assembly {
            // signed arithmetic shift right
                wordPos := sar(8, compressed)
                bitPos := and(compressed, 255)
            }
            // Reuse the same word if the position doesn't change
            tickWord = wordPos == lastWordPos ? lastWord : pool.tickBitmap(wordPos);
            // all the 1s at or to the right of the current bitPos
            // mask = (1 << (bitPos + 1)) - 1
            // (bitPos + 1) may be 256 but fine
            assembly {
                let mask := sub(shl(add(bitPos, 1), 1), 1)
                masked := and(tickWord, mask)
            }
            while (masked == 0) {
                // Always query the next word to the left
               
                    masked = tickWord = pool.tickBitmap(--wordPos);
                
            }
            sb = BitMath.mostSignificantBit(masked);
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            compressed ++;
            assembly {
            // signed arithmetic shift right
                wordPos := sar(8, compressed)
                bitPos := and(compressed, 255)
            }
            
            // Reuse the same word if the position doesn't change
            tickWord = wordPos == lastWordPos ? lastWord : pool.tickBitmap(wordPos);
            // all the 1s at or to the left of the bitPos
            // mask = ~((1 << bitPos) - 1)
            assembly {
                let mask := not(sub(shl(bitPos, 1), 1))
                masked := and(tickWord, mask)
            }
            while (masked == 0) {
                // Always query the next word to the right
                
                    masked = tickWord = pool.tickBitmap(++wordPos);
                
            }
            sb = BitMath.leastSignificantBit(masked);
        }
        assembly {
            // next = (wordPos * 256 + sb) * tickSpacing
            next := mul(add(shl(8, wordPos), sb), tickSpacing)
        }
    }

    function computeSwapStepExactIn(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        uint256 amountRemaining,
        uint256 feePips
    ) private pure returns (uint160 sqrtRatioNextX96, uint256 amountIn, uint256 amountOut) {
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
        uint256 feeComplement = MAX_FEE_PIPS.sub(feePips);
        uint256 amountRemainingLessFee = FullMath.mulDiv(amountRemaining, feeComplement, MAX_FEE_PIPS);
        amountIn = zeroForOne
            ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
            : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);
        if (amountRemainingLessFee >= amountIn) {
            // `amountIn` is capped by the target price
            sqrtRatioNextX96 = sqrtRatioTargetX96;
            // add the fee amount
            amountIn = FullMath.mulDivRoundingUp(amountIn, MAX_FEE_PIPS, feeComplement);
        } else {
            // exhaust the remaining amount
            amountIn = amountRemaining;
            sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                sqrtRatioCurrentX96,
                liquidity,
                amountRemainingLessFee,
                zeroForOne
            );
        }
        amountOut = zeroForOne
            ? SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false)
            : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
    }

    function sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

}