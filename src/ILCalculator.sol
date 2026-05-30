// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ILCalculator {
    /**
     * @notice Calculates a simplified impermanent loss percentage for demonstration
     * @param initialPrice The starting price
     * @param currentPrice The current price
     * @param liquidityAmount The amount of liquidity
     * @return IL percentage
     */
    function calculateIL(
        uint256 initialPrice,
        uint256 currentPrice,
        uint256 liquidityAmount
    ) external pure returns (uint256) {
        if (initialPrice == 0 || liquidityAmount == 0) {
            return 0;
        }

        // Simplified hold value and current value computation
        uint256 holdValue = liquidityAmount * initialPrice;
        uint256 currentValue = liquidityAmount * currentPrice;

        if (holdValue == currentValue) {
            return 0;
        }

        // Calculate absolute difference for the formula: IL = |currentValue - holdValue| / holdValue
        uint256 diff = holdValue > currentValue 
            ? holdValue - currentValue 
            : currentValue - holdValue;

        // Return as a percentage
        return (diff * 100) / holdValue;
    }
}
