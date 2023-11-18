import { ethers } from "hardhat";

export async function getBalanceOf(tokenAddress: string, address: string) {
  const token = await ethers.getContractAt("IERC20", tokenAddress);
  return token.balanceOf(address);
}

export default getBalanceOf;
