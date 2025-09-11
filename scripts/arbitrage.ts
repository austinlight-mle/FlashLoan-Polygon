import { ethers } from 'ethers';
import { Protocols, Routers, factories } from '../constants';
import { ERC20Token } from '../constants/tokens';
import { getPriceInUSDC } from '../utils/getPriceinusdc';
import flashloan from '../artifacts/contracts/FlashLoan.sol/Flashloan.json';
import { FlashLoanParams } from '../types';
import { dodoV2Pool } from '../constants';
import { findRouterByProtocol } from '../utils/findRouterByProtocol';
import { executeFlashloan } from './executeFlashloan';

require('dotenv').config();

const MIN_PRICE_DIFF = 10000000; // 20 USDC

async function main() {
    // WETH/USDC Pools
    const checkArbitrage = async () => {
        const provider = new ethers.JsonRpcProvider(
            `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
        );

        const sushiQuote = await getPriceInUSDC({
            router: Routers.POLYGON_SUSHISWAP,
            factory: factories.POLYGON_SUSHISWAP,
            tokenAddress: ERC20Token.WETH?.address,
            id: Protocols.SUSHISWAP,
            provider,
        });

        const quickQuote = await getPriceInUSDC({
            router: Routers.POLYGON_QUICKSWAP,
            factory: factories.POLYGON_QUICKSWAP,
            tokenAddress: ERC20Token.WETH?.address,
            id: Protocols.QUICKSWAP,
            provider,
        });

        const apeQuote = await getPriceInUSDC({
            router: Routers.POLYGON_APESWAP,
            factory: factories.POLYGON_APESWAP,
            tokenAddress: ERC20Token.WETH?.address,
            id: Protocols.APESWAP,
            provider,
        });

        const quotes = [sushiQuote, quickQuote];

        const min = quotes.reduce((min, obj) => (obj.quote < min.quote ? obj : min));
        const max = quotes.reduce((max, obj) => (obj.quote > max.quote ? obj : max));

        const biggestPriceDiff = max.quote - min.quote;

        console.log(`Biggest price difference: ${ethers.formatUnits(biggestPriceDiff, 6)}`);

        // console.log(`liquidity in SUSHISWAP: ${ethers.formatUnits(sushiQuote.reserves[0], 6)}`);
        // console.log(`liquidity in QUICKSWAP: ${ethers.formatUnits(quickQuote.reserves[0], 6)}`);
        // console.log(`liquidity in APESWAP: ${ethers.formatUnits(apeQuote.reserves[0], 6)}`);

        // SHUHISWAP FEE 0.3%
        // QUICKSWAP FEE 0.3%
        // APESWAP FEE 0.3%

        // 0.3% of 0.5 WETH = 0.0015 WETH
        // 0.0015 WETH = 4.5 USDC

        if (biggestPriceDiff > MIN_PRICE_DIFF) {
            // execute arbitrage

            const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
            const Flashloan = new ethers.Contract(
                process.env.FLASHLOAN_CONTRACT_ADDRESS!,
                flashloan.abi,
                provider,
            );

            const params: FlashLoanParams = {
                flashLoanContractAddress: Flashloan.target.toString(),
                flashLoanPool: dodoV2Pool.WETH_ULT,
                loanAmount: ethers.parseEther('0.5'),
                loanAmountDecimals: 18,
                hops: [
                    {
                        protocol: max.protocol,
                        data: ethers.AbiCoder.defaultAbiCoder().encode(
                            ['address'],
                            [findRouterByProtocol(max.protocol)],
                        ),
                        path: [ERC20Token.WETH?.address, ERC20Token.USDC?.address],
                    },
                    {
                        protocol: min.protocol,
                        data: ethers.AbiCoder.defaultAbiCoder().encode(
                            ['address'],
                            [findRouterByProtocol(min.protocol)],
                        ),
                        path: [ERC20Token.USDC?.address, ERC20Token.WETH?.address],
                    },
                ],
                gasLimit: 3_000_000,
                gasPrice: ethers.parseUnits('300', 'gwei'),
                signer: wallet,
            };

            executeFlashloan(params);
        }
    };

    try {
        checkArbitrage();
    } catch (error) {
        console.error(error);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
