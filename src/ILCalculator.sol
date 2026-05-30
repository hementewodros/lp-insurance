// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ILCalculator {
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /**
     * @notice Calculates real ratio-based impermanent loss in basis points (10000 = 100%)
     * @param initialPrice The starting price (18 decimals)
     * @param currentPrice The current price (18 decimals)
     * @return IL in basis points
     */
    function calculateIL(
        uint256 initialPrice,
        uint256 currentPrice
    ) external pure returns (uint256) {
        if (initialPrice == 0 || currentPrice == 0) {
            return 0;
        }
        if (initialPrice == currentPrice) {
            return 0;
        }

        // r = currentPrice / initialPrice. Scale by 1e18 for precision.
        uint256 r = (currentPrice * 1e18) / initialPrice;
        
        // sqrt(r)
        uint256 sqrtR = sqrt(r * 1e18); // since r is scaled by 1e18, r * 1e18 is scaled by 1e36, so sqrt is scaled by 1e18.

        // IL ratio = 1 - (2 * sqrtR) / (1e18 + r)
        uint256 term = (2 * sqrtR * 1e18) / (1e18 + r);
        
        if (term >= 1e18) {
            return 0;
        }

        uint256 ilFraction = 1e18 - term; // Out of 1e18

        // Convert to basis points: 1e18 corresponds to 10000 bps. So divide by 1e14.
        return ilFraction / 1e14;
    }
}
