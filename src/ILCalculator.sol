// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ILCalculator {
    /**
     * @notice Calculates a simplified impermanent loss percentage for demonstration
     * @param initialPrice The starting price
     * @param currentPrice The current price
     * @param depositedAmount The amount of tokens deposited
     * @return IL percentage (e.g., 5 represents 5%)
     */
    function calculateIL(
        uint256 initialPrice,
        uint256 currentPrice,
        uint256 depositedAmount
    ) external pure returns (uint256) {
        require(initialPrice > 0, "Initial price cannot be zero");
        
        if (currentPrice == initialPrice || depositedAmount == 0) {
            return 0;
        }

        uint256 priceDiff = currentPrice > initialPrice 
            ? currentPrice - initialPrice 
            : initialPrice - currentPrice;

        // Simple mock IL math: Half of the percentage change in price
        uint256 priceChangePercentage = (priceDiff * 100) / initialPrice;
        uint256 ilPercentage = priceChangePercentage / 2;

        return ilPercentage;
    }
}
