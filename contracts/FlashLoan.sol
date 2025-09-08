// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IFlashloan.sol";

import "./interfaces/IDODO.sol";
import "./interfaces/IDODOProxy.sol";

import "./base/DodoBase.sol";
import "./base/FlashloanValidation.sol";
import "./base/Withdraw.sol";

import "./libraries/RouteUtils.sol";

import "./uniswap/v3/ISwapRouter.sol";
import "./uniswap/IUniswapV2Router.sol";

import "./libraries/Part.sol";

import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "hardhat/console.sol";

contract Flashloan is IFlashloan, DodoBase {
    using SignedMath for uint256;

    event SentProfit(address recipient, uint256 amount);
    event SwapFinished(address token, uint256 amount);

    /**
     * @dev Initiates a flashloan transaction with DODO protocol.
     * @param params Encoded parameters for the flashloan operation.
     */
    function executeFlashloan(FlashParams memory params) external checkParamas(params) {
        // Encodes the callback data to be used in the flashloan process.
        // This includes sender's address, flashloan pool, loan amount, and swap routes.
        bytes memory data = abi.encode(
            FlashParams({
                flashLoanPool: params.flashLoanPool,
                loanAmount: params.loanAmount,
                routes: params.routes
            })
        );

        address loanToken = RouteUtils.getInitialToken(params.routes[0]);

        console.log(
            "Contract balance before flashloan: ",
            IERC20(loanToken).balanceOf(address(this))
        );

        // Initiates the base token of the DODO pool.
        address btoken = IDODO(params.flashLoanPool)._BASE_TOKEN_();
        console.log("Base token address: ", btoken);

        uint256 baseAmount = IDODO(params.flashLoanPool)._BASE_TOKEN_() == loanToken
            ? params.loanAmount
            : 0;
        uint256 quoteAmount = IDODO(params.flashLoanPool)._BASE_TOKEN_() == loanToken
            ? 0
            : params.loanAmount;

        IDODO(params.flashLoanPool).flashLoan(baseAmount, quoteAmount, address(this), data);
    }

    function _flashLoanCallBack(
        address, // sender
        uint256, // baseAmount
        uint256, // quoteAmount
        bytes calldata data
    ) internal override {
        // Decode the received data to get flashloan parameters.
        FlashParams memory decoded = abi.decode(data, (FlashParams));

        // Identify the initial loan token from the decoded routes
        address loanToken = RouteUtils.getInitialToken(decoded.routes[0]);

        // Ensure the contract has received the flashloan amount
        require(
            IERC20(loanToken).balanceOf(address(this)) >= decoded.loanAmount,
            "Fail to borrow tokens"
        );

        console.log(IERC20(loanToken).balanceOf(address(this)), " Contract balance after loan");

        // Execute the series of swaps as per the provided routes
        routeLoop(decoded.routes, decoded.loanAmount);

        console.log(
            "Loan Token balance after borrow and swap: ",
            IERC20(loanToken).balanceOf(address(this))
        );

        emit SwapFinished(loanToken, IERC20(loanToken).balanceOf(address(this)));

        require(
            IERC20(loanToken).balanceOf(address(this)) >= decoded.loanAmount,
            "Not enough funds to return"
        );

        IERC20(loanToken).transfer(decoded.flashLoanPool, decoded.loanAmount);

        console.log(
            "Contract balance after returning the loan: ",
            IERC20(loanToken).balanceOf(address(this))
        );

        uint256 profit = IERC20(loanToken).balanceOf(address(this));
        IERC20(loanToken).transfer(msg.sender, profit);

        emit SentProfit(owner());
    }

    /**
     * @dev Executes a series of token swaps based on the provided routes.
     * @param routes An array of Route structs defining the swap paths and protocols.
     * @param totalAmount The total amount of the initial token to be swapped.
     */
    function routeLoop(
        Route[] memory routes,
        uint256 totalAmount
    ) internal checkTotalRoutePart(routes) {
        for (uint256 i = 0; i < routes.length; i++) {
            // Calculate the amount to be used in the current route based on its part of the total loan
            // If routes[i].part is 10000 (100%), then the amount to be used is the total amount.
            // This helps if you want to use a percentage of the total amount for this swap and keep the rest for other purposes
            // The partToAmountIn function from the Part library is used to calculate this amount.
            uint256 amountIn = Part.partToAmountIn(routes[i].part, totalAmount);
            console.log("Amount to swap: ", amountIn);
            hopLoop(routes[i], amountIn);
        }
    }

    /**
     * @dev Executes a single route by iterating over each hop within the route.
     *      Each hop represents a swap operation on a specific protocol.
     * @param route The Route struct defining the swap path.
     * @param totalAmount The amount of the token to be swapped in this route.
     */
    function hopLoop(Route memory route, uint256 totalAmount) internal {
        uint256 amountIn = totalAmount;

        // hop1 => path = [WETH, USDC] -- path[0] = WETH | amountIn = 10
        // hop2 => path = [USDC, DAI] -- path[0] = USDC | amountIn = 15000

        for (uint256 i = 0; i < route.hops.length; i++) {
            // Execute the token swap for the current hop and updates the amount for the next hop.
            // The pickProtocol function determines the specific protocol to use for the swap.
            amountIn = pickProtocol(route.hops[i], amountIn);
        }
    }

    function pickProtocol(Hop memory hop, uint256 amountIn) internal returns (uint256 amountOut) {
        // Checks the protocol specified in the hop
        if (hop.protocol == 0) {
            amountOut = uniswapV3(hop.data, amountIn, hop.path);
            console.log("Amount received from the protocol 0: ", amountOut);
        } else if (hop.protocol < 8) {
            // If the protocol is Uniswap V2 or similar (protocol 1-7)
            // execute a swap UniswapV2's swap function
            amountOut = uniswapV2(hop.data, amountIn, hop.path);
            console.log("Amount received from the protocol: ", amountOut);
        } else {
            // For other protocols (protocol number 8 and above)
            // execute a swap using DODO V2's swap function
            amountOut = dodoV2Swap(hop.data, amountIn, hop.path);
            console.log("Amount received from the protocol: ", amountOut);
        }
    }

    function uniswapV3(
        bytes memory data,
        uint256 amountIn,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        (address router, uint24 fee) = abi.decode(data, (address, uint24));

        ISwapRouter swapRouter = ISwapRouter(router);

        approveToken(path[0], address(swapRouter), amountIn);

        amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputParams({
                tokenIn: path[0],
                tokenOut: path[1],
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 60,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function uniswapV2(
        bytes memory data,
        uint256 amountIn,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        address router = abi.decode(data, (address));

        approveToken(path[0], router, amountIn);

        amountOut = IUniswapV2Router(router).swapExactTokensForTokens(
            amountIn,
            1,
            path,
            address(this),
            block.timestamp + 60
        )[1];
    }

    function dodoV2Swap(
        bytes memory data,
        uint256 amountIn,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        (address dodoV2Pool, address dodoApprove, address dodoProxy) = abi.decode(
            data,
            (address, address, address)
        );

        address[] memory dodoPairs = new address[][1];
        dodoPairs[0] = dodoV2Pool;

        uint256 directions = IDODO(dodoV2Pool)._BASE_TOKEN_() == path[0] ? 0 : 1; // Finds the direction of the swap

        approveToken(path[0], dodoApprove, amountIn);

        amountOut = IDODOProxy(dodoProxy).dodoSwapV2TokenToToken(
            path[0],
            path[1],
            amountIn,
            1,
            dodoPairs,
            directions,
            false,
            block.timestamp + 60
        );
    }

    function approveToken(address token, address to, uint256 amountIn) internal {
        require(IERC20(token).approve(to, amountIn), "Approve failed");
    }
}
