import { ethers } from "hardhat";


export default async function makeWETH(ETHamount: string, WETHaddress: string) {
  const weth = await ethers.getContractAt("WETH9", WETHaddress);
  return weth
    .deposit({ value: ethers.utils.parseEther(ETHamount) });
}
