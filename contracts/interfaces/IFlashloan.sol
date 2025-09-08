// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract IFlashloan {
    /**
     * @dev Hop struct represents a single swap operation within a route.
     * @param protocol A numeric identifer for the swap protocol (e.g., 0 = UniswapV2, 1 = UniswapV3, 2 = Sushiswap etc).
     * @param data Additional data required for the swap (e.g., router address, fee).
     * @param path The sequence of token addresses involved in the swap. (e.g., ["WETH", "USDC", "DAI"])
     */
    struct Hop {
        uint8 protocol;
        bytes data;
        address[] path;
    }

    /**
     * @dev Swap struct represents a complete swap operation.
     * @param hops An array of `Hop` structs, each representing a step in the swap process.
     * @param part A uint256 value representing the proportion of the total loan amount allocated to this route
     */
    struct Route {
        Hop[] hops;
        uint16 part;
    }

    /**
     * @dev FlashParams struct encapsulates all parameters required to execute a flash loan and perform swaps.
     * @param flashLoanPool The address of the pool from which the flash loan is borrowed.
     * @param loanAmount The total amount of tokens to borrow in the flash loan.
     * @param routes An array of `Route` structs, each representing a distinct swap operation to be performed with the borrowed funds.
     */
    struct FlashParams {
        address flashLoanPool;
        uint256 loanAmount;
        Route[] routes;
    }
}
