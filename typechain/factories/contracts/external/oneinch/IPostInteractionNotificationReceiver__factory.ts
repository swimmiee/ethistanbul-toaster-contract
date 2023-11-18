/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IPostInteractionNotificationReceiver,
  IPostInteractionNotificationReceiverInterface,
} from "../../../../contracts/external/oneinch/IPostInteractionNotificationReceiver";

const _abi = [
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "orderHash",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "maker",
        type: "address",
      },
      {
        internalType: "address",
        name: "taker",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "makingAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "takingAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "remainingAmount",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "interactionData",
        type: "bytes",
      },
    ],
    name: "fillOrderPostInteraction",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

export class IPostInteractionNotificationReceiver__factory {
  static readonly abi = _abi;
  static createInterface(): IPostInteractionNotificationReceiverInterface {
    return new utils.Interface(
      _abi
    ) as IPostInteractionNotificationReceiverInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IPostInteractionNotificationReceiver {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as IPostInteractionNotificationReceiver;
  }
}
