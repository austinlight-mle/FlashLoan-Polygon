import { ethers } from 'hardhat';
import { PriceInUsdcParams } from '../types';

import routerAbi from '../abis/routerAbi.json';
import factoryAbi from '../abis/factoryAbi.json';
import pairAbi from '../abis/pairAbi.json';

import { ERC20Token } from '../constants/tokens';
import { Protocols, Routers } from '../constants';

const sushiSwapFactoryPolygon = '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32';

require('dotenv').config();

export const getPriceInUSDC = async (params: PriceInUsdcParams) => {
    const router = new ethers.Contract(params.router, routerAbi, params.provider);
    const factory = new ethers.Contract(params.factory, factoryAbi, params.provider);

    const pairAddress = await factory.getPair(params.tokenAddress, ERC20Token.USDC?.address);

    const pair = new ethers.Contract(pairAddress, pairAbi, params.provider);

    const reserves = await pair.getReserves();

    const quote = await router.quote(ethers.parseEther('1'), reserves[1], reserves[0]);

    console.log(
        `Price of ${params.tokenAddress}: ${ethers.formatUnits(quote, 6)} USDC for protocol id ${params.id}`,
    );

    return {
        quote,
        protocol: params.id,
        reserves,
    };
};
