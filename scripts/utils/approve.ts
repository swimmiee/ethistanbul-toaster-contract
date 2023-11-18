import { ethers } from "hardhat";
import { IERC20 } from "../../typechain";

export async function approveToken(tokenAddress: string, spender: string) {
  const token:IERC20 = await ethers.getContractAt("IERC20", tokenAddress);
  const signer = await ethers.getSigners();
  
  const allowance = await token.allowance(signer[0].address, spender);
  if (allowance != ethers.constants.MaxUint256) {
    
    return token
      .approve(spender, ethers.constants.MaxUint256)
      .then((tx) => tx.wait())
      .then((tx) => tx?.gasUsed!);
  }
  
  return allowance;
}

export default approveToken;
