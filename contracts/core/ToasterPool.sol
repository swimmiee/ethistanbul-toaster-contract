// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.5;
pragma abicoder v2;
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {PositionValue} from "@uniswap/v3-periphery/contracts/libraries/PositionValue.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IPostInteractionNotificationReceiver} from "../external/oneinch/IPostInteractionNotificationReceiver.sol";

import {IToasterPoolDeployer} from "../interfaces/IToasterPoolDeployer.sol";
import {IToasterPool} from "../interfaces/IToasterPool.sol";
import {IToasterStrategy} from "../interfaces/IToasterStrategy.sol";
import {IAggregatorProtocol} from "../external/oneinch/interface/IAggregatorProtocol.sol";
import {IZapCalculator} from "../interfaces/IZapCalculator.sol";


struct SwapCallbackData {
    bytes path;
    address payer;
}

contract ToasterPool is
    IPostInteractionNotificationReceiver,
    IToasterPool,
    Ownable
{
    PoolState public state;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Pool public immutable override pool;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint24 public immutable fee;
    int24 public immutable tickSpacing;

    IZapCalculator public immutable zapCalculator;
    IToasterStrategy public immutable strategy;
    address public immutable _1inch;
    
    mapping(address => uint128) userShare;
    mapping(address => mapping(address => uint)) public balances;
    bool public override locked;

    event IncreaseLiquidity(
        address user,
        uint investedAmount0,
        uint investedAmount1
    );
    event DecreaseLiquidity(
        address user,
        uint decreasedAmount0,
        uint decreasedAmount1
    );

    constructor(
        address _zapCalculator,
        address _positionManager,
        address _pool,
        address __1inch,
        address _strategy
    ) {
        zapCalculator = IZapCalculator(_zapCalculator);
        _1inch = __1inch;
        strategy = IToasterStrategy(_strategy);
        positionManager = INonfungiblePositionManager(_positionManager);
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(IUniswapV3Pool(_pool).token0());
        token1 = IERC20(IUniswapV3Pool(_pool).token1());
        fee = IUniswapV3Pool(_pool).fee();
        tickSpacing = IUniswapV3Pool(_pool).tickSpacing();
    }

    function init(
        int24 tickLower,
        int24 tickUpper,
        uint amount0,
        uint amount1
    ) external override {
        require(state.tokenId == 0, "A_I");
        if (amount0 > 0) {
            SafeERC20.safeTransferFrom(
                token0,
                msg.sender,
                address(this),
                amount0
            );
        }
        if (amount1 > 0) {
            SafeERC20.safeTransferFrom(
                token1,
                msg.sender,
                address(this),
                amount1
            );
        }
        SafeERC20.safeApprove(token0, address(positionManager), type(uint).max);
        SafeERC20.safeApprove(token1, address(positionManager), type(uint).max);
        SafeERC20.safeApprove(token0, address(pool), type(uint).max);
        SafeERC20.safeApprove(token1, address(pool), type(uint).max);
        uint128 liquidity = _mint(tickLower, tickUpper);
        state.totalShare = liquidity;
    }

    function zap(
        int24 tickLower,
        int24 tickUpper,
        uint amount0Desired,
        uint amount1Desired
    ) internal returns (uint newAmount0, uint newAmount1) {
        uint256 amountOut;
        (uint256 amountIn, , bool zeroForOne, ) = zapCalculator.zap(
            pool,
            tickLower,
            tickUpper,
            amount0Desired,
            amount1Desired
        );

        {
            (address tokenIn, address tokenOut) = zeroForOne
                ? (address(token0), address(token1))
                : (address(token1), address(token0));
            (int256 amount0, int256 amount1) = pool.swap(
                address(this),
                zeroForOne,
                int256(amountIn),
                (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1),
                abi.encode(
                    SwapCallbackData({
                        path: abi.encode(tokenIn, fee, tokenOut),
                        payer: address(this)
                    })
                )
            );
            amountOut = uint256(-(zeroForOne ? amount1 : amount0));
        }
        if (zeroForOne) {
            (newAmount0, newAmount1) = (
                amount0Desired - amountIn,
                amount1Desired + amountOut
            );
        } else {
            (newAmount0, newAmount1) = (
                amount0Desired + amountOut,
                amount1Desired - amountIn
            );
        }
    }

    function increaseLiquidity(
        address user,
        uint amount0,
        uint amount1
    ) public override {
        PoolState memory s = state;
        require(s.tokenId != 0, "NOL");
        // collect fees and reinvest
        reinvest();
        uint reserve0 = IERC20(token0).balanceOf(address(this));
        uint reserve1 = IERC20(token1).balanceOf(address(this));
        (amount0, amount1) = zap(s.tickLower, s.tickUpper, reserve0, reserve1);
        (
            uint128 increasedLiquidity,
            uint investedAmount0,
            uint investedAmount1
        ) = positionManager.increaseLiquidity(
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: s.tokenId,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

        uint128 increasedShare = (increasedLiquidity * s.totalShare) /
            s.liquidity;

        state = PoolState({
            tokenId: s.tokenId,
            tickLower: s.tickLower,
            tickUpper: s.tickUpper,
            liquidity: s.liquidity + increasedLiquidity,
            totalShare: s.totalShare + increasedShare
        });
        userShare[user] += increasedShare;

        if (amount0 > investedAmount0) {
            SafeERC20.safeTransfer(
                IERC20(token0),
                user,
                amount0 - investedAmount0
            );
        }
        if (amount1 > investedAmount1) {
            SafeERC20.safeTransfer(
                IERC20(token1),
                user,
                amount1 - investedAmount1
            );
        }
        emit IncreaseLiquidity(user, investedAmount0, investedAmount1);
    }

    /// 유저가 모든 liquidity를 제거하려면 MaxUint128를 넣으면 된다
    function decreaseLiqduidity(
        address user,
        uint128 decreasedShare
    ) public override {
        // collect fees and reinvest
        reinvest();

        PoolState memory s = state;

        // for user-friendly: if user want to remove all liquidity,
        // set decreasedLiquidity to MaxUint128
        if (decreasedShare == type(uint128).max)
            decreasedShare = userShare[user];
        uint128 decreasedLiquidity = (decreasedShare * s.liquidity) /
            s.totalShare;

        (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: s.tokenId,
                liquidity: decreasedLiquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        // send tokens to user directly
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: s.tokenId,
                recipient: user,
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            })
        );

        // handle user's share & liquidity
        state = PoolState({
            tokenId: s.tokenId,
            tickLower: s.tickLower,
            tickUpper: s.tickUpper,
            liquidity: s.liquidity - decreasedLiquidity,
            totalShare: s.totalShare - decreasedShare
        });

        userShare[user] -= decreasedShare;

        emit DecreaseLiquidity(user, amount0, amount1);
    }

    function _mint(
        int24 tickLower,
        int24 tickUpper
    ) internal returns (uint128 liquidity) {
        address _token0 = address(token0);
        address _token1 = address(token1);

        uint256 tokenId;
        uint256 invested0;
        uint256 invested1;

        uint amount0 = IERC20(_token0).balanceOf(address(this));
        uint amount1 = IERC20(_token1).balanceOf(address(this));

        (tokenId, liquidity, invested0, invested1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: _token0,
                token1: _token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp //COMM: deadline
            })
        );

        state = PoolState({
            tokenId: uint64(tokenId),
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            totalShare: state.totalShare
        });

        balances[address(this)][_token0] = invested0 - amount0;
        balances[address(this)][_token1] = invested1 - amount1;
    }

    // execution like rebalance call back
    function fillOrderPostInteraction(
        bytes32, //orderHash,
        address maker,
        address, // taker,
        uint256, // makingAmount,
        uint256 takingAmount,
        uint256 remainingAmount,
        bytes memory interactionData
    ) external override {
        // require(msg.sender == address(_1inch), "NOT_1INCH");

        (address baseToken, uint baseAmount) = abi.decode(
            interactionData,
            (address, uint256)
        );

        address quoteToken;
        {
            address _token0 = address(token0);
            quoteToken = baseToken == _token0 ? address(token1) : _token0;
        }

        if (remainingAmount > 0) {
            balances[maker][quoteToken] += takingAmount;
            return;
        }

        // if (maker == address(this)) {
        //     require(locked == true, "UL");

        //     (int24 newTickLower, int24 newTickUpper) = abi.decode(
        //         interactionData,
        //         (int24, int24)
        //     );

        //     _mint(newTickLower, newTickUpper);

        //     locked = false;
        // }
        // maker != address(this)
        uint quoteAmount = balances[maker][quoteToken] + takingAmount;
        balances[maker][quoteToken] = 0;

        // should approve for this Pool before swap
        SafeERC20.safeTransferFrom(
            IERC20(baseToken),
            maker,
            address(this),
            baseAmount
        );

        baseToken < quoteToken
            ? increaseLiquidity(maker, baseAmount, quoteAmount)
            : increaseLiquidity(maker, quoteAmount, baseAmount);
    }

    /**
     * @dev Reinvest with accumulated fees
     */
    function reinvest() public override {
        PoolState memory s = state;
        (uint amount0, uint amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: s.tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        if (amount0 == 0 && amount1 == 0) return;

        (amount0, amount1) = zap(s.tickLower, s.tickUpper, amount0, amount1);

        (uint128 increasedLiquidity, , ) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: s.tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        state.liquidity += increasedLiquidity;
    }

    /********************/
    /** VIEW FUNCTIONS **/
    /********************/
    function approveMax(address token, address spender) public {
        SafeERC20.safeApprove(IERC20(token), spender, 0);
        SafeERC20.safeApprove(IERC20(token), spender, type(uint).max);
    }

    function isInRange() public view override returns (bool inRange) {
        PoolState memory s = state;
        (, int24 tick, , , , , ) = pool.slot0();
        inRange = s.tickLower < tick && tick < s.tickUpper;
    }

    /** REBALANCE **/
    function rebalance(
        int24 newTickLower,
        int24 newTickUpper
    ) external override {
        require(address(strategy) == msg.sender, "NOT STRATEGY");
        require(locked == true, "UL");
        PoolState memory s = state;
        positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: s.tokenId,
                liquidity: s.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: s.tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // call zap to rebalance
        uint reserve0 = IERC20(token0).balanceOf(address(this));
        uint reserve1 = IERC20(token1).balanceOf(address(this));
        zap(newTickLower, newTickUpper, reserve0, reserve1);

        _mint(newTickLower, newTickUpper);

        locked = false;
    }

    function lock() external override {
        require(address(strategy) == msg.sender, "NOT STRATEGY");
        locked = true;
    }

    function setPeriod(uint24 _period) external onlyOwner {
        period = _period;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        require(msg.sender == address(pool)); // ensure that msg.sender is the pool
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported

        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, , ) = abi.decode(
            data.path,
            (address, uint24, address)
        );
        uint256 amountToPay = uint256(
            amount0Delta > 0 ? amount0Delta : amount1Delta
        );
        SafeERC20.safeTransfer(IERC20(tokenIn), msg.sender, amountToPay);
    }
}
