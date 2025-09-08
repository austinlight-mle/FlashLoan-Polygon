import { ethers } from "ethers";
import { deployDodoFlashloan } from "../scripts/deployDodoFlashloan";
import { FlashLoanParams } from "../types";
import { dodoV2Pool, Protocols } from "../constants";
import { findRouterByProtocol } from "../utils/findRouterByProtocol";
import { ERC20Token } from "../constants/tokens";
import { executeFlashloan } from "../scripts/executeFlashloan";

require("dotenv").config();

describe("DODO Flashloan", () => {
  it("Execute Flashloan", async () => {
    const providerUrl = "http://localhost:8545";

    const privateKey = process.env.PRIVATE_KEY;

    const wallet = new ethers.Wallet(privateKey!);

    const Flashloan = await deployDodoFlashloan({
      wallet,
    });

    const params: FlashLoanParams = {
      flashLoanContractAddress: Flashloan.target.toString(),
      flashLoanPool: dodoV2Pool.WETH_ULT,
      loanAmount: ethers.parseEther("1"),
      loanAmountDecimals: 18,
      hops: [
        {
          protocol: Protocols.UNISWAP_V2,
          data: ethers.AbiCoder.defaultAbiCoder().encode(
            ["address"],
            [findRouterByProtocol(Protocols.UNISWAP_V2)],
          ),
          path: [ERC20Token.WETH?.address, ERC20Token.USDC?.address],
        },
        {
          protocol: Protocols.SUSHISWAP,
          data: ethers.AbiCoder.defaultAbiCoder().encode(
            ["address"],
            [findRouterByProtocol(Protocols.SUSHISWAP)],
          ),
          path: [ERC20Token.USDC?.address, ERC20Token.WETH?.address],
        },
      ],
      gasLimit: 3_000_000,
      gasPrice: ethers.parseUnits("300", "gwei"),
      signer: wallet,
    };

    const tx = await executeFlashloan(params);

    console.log(`Transaction hash: ${tx.hash}`);
  });
});
