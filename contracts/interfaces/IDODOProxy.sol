// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDODOProxy {
    function dodoSwapV2TopkenToToken(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory dodoPairs,
        uint256 directions,
        bool isIncentive,
        address deadLine
    ) external returns (uint256 returnAmount);
}
