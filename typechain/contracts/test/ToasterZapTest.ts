/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "../../common";

export interface ToasterZapTestInterface extends utils.Interface {
  functions: {
    "getOptimalSwap(address,int24,int24,uint256,uint256)": FunctionFragment;
  };

  getFunction(nameOrSignatureOrTopic: "getOptimalSwap"): FunctionFragment;

  encodeFunctionData(
    functionFragment: "getOptimalSwap",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;

  decodeFunctionResult(
    functionFragment: "getOptimalSwap",
    data: BytesLike
  ): Result;

  events: {};
}

export interface ToasterZapTest extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: ToasterZapTestInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    getOptimalSwap(
      pool: PromiseOrValue<string>,
      tickLower: PromiseOrValue<BigNumberish>,
      tickUpper: PromiseOrValue<BigNumberish>,
      amount0Desired: PromiseOrValue<BigNumberish>,
      amount1Desired: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber, boolean, BigNumber] & {
        amountIn: BigNumber;
        amountOut: BigNumber;
        zeroForOne: boolean;
        sqrtPriceX96: BigNumber;
      }
    >;
  };

  getOptimalSwap(
    pool: PromiseOrValue<string>,
    tickLower: PromiseOrValue<BigNumberish>,
    tickUpper: PromiseOrValue<BigNumberish>,
    amount0Desired: PromiseOrValue<BigNumberish>,
    amount1Desired: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<
    [BigNumber, BigNumber, boolean, BigNumber] & {
      amountIn: BigNumber;
      amountOut: BigNumber;
      zeroForOne: boolean;
      sqrtPriceX96: BigNumber;
    }
  >;

  callStatic: {
    getOptimalSwap(
      pool: PromiseOrValue<string>,
      tickLower: PromiseOrValue<BigNumberish>,
      tickUpper: PromiseOrValue<BigNumberish>,
      amount0Desired: PromiseOrValue<BigNumberish>,
      amount1Desired: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber, boolean, BigNumber] & {
        amountIn: BigNumber;
        amountOut: BigNumber;
        zeroForOne: boolean;
        sqrtPriceX96: BigNumber;
      }
    >;
  };

  filters: {};

  estimateGas: {
    getOptimalSwap(
      pool: PromiseOrValue<string>,
      tickLower: PromiseOrValue<BigNumberish>,
      tickUpper: PromiseOrValue<BigNumberish>,
      amount0Desired: PromiseOrValue<BigNumberish>,
      amount1Desired: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    getOptimalSwap(
      pool: PromiseOrValue<string>,
      tickLower: PromiseOrValue<BigNumberish>,
      tickUpper: PromiseOrValue<BigNumberish>,
      amount0Desired: PromiseOrValue<BigNumberish>,
      amount1Desired: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
