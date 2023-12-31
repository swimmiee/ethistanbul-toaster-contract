/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IAggregatorProtocol,
  IAggregatorProtocolInterface,
} from "../../../../../contracts/external/1inch/interface/IAggregatorProtocol";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "minReturn",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "pools",
        type: "uint256[]",
      },
    ],
    name: "uniswapV3Swap",
    outputs: [
      {
        internalType: "uint256",
        name: "returnAmount",
        type: "uint256",
      },
    ],
    stateMutability: "payable",
    type: "function",
  },
];

export class IAggregatorProtocol__factory {
  static readonly abi = _abi;
  static createInterface(): IAggregatorProtocolInterface {
    return new utils.Interface(_abi) as IAggregatorProtocolInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IAggregatorProtocol {
    return new Contract(address, _abi, signerOrProvider) as IAggregatorProtocol;
  }
}
