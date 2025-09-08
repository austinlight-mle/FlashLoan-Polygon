import { ethers } from "ethers";
import { Flashloan, Flashloan__factory } from "../typechain-types";
import { deployContract } from "../utils/deployContract";
import { DeployDODOFlashloanParams } from "../types";

export async function deployDodoFlashloan(params: DeployDODOFlashloanParams) {
  const Flashloan: Flashloan = await deployContract(
    Flashloan__factory,
    [],
    params.wallet,
  );

  const deployed = await Flashloan.waitForDeployment();
  console.log("Flashloan deployed to:", deployed.target);

  return deployed;
}
