// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ILCalculator.sol";

contract CoverageManager {
    ILCalculator public calculator;

    struct Policy {
        uint256 liquidityAmount;
        uint256 initialPrice;
        uint256 coverageAmount;
        bool isActive;
    }

    mapping(address => Policy) public policies;

    constructor(address _calculator) {
        calculator = ILCalculator(_calculator);
    }

    function buyCoverage(uint256 liquidityAmount, uint256 initialPrice) external payable {
        // Simple MVP: require 1 wei minimum premium
        require(msg.value > 0, "Premium required");
        policies[msg.sender] = Policy({
            liquidityAmount: liquidityAmount,
            initialPrice: initialPrice,
            coverageAmount: msg.value * 10, // Mock: coverage is 10x premium
            isActive: true
        });
    }

    function getIL(address user, uint256 currentPrice) external view returns (uint256) {
        Policy memory policy = policies[user];
        require(policy.isActive, "No active policy");
        return calculator.calculateIL(policy.initialPrice, currentPrice, policy.liquidityAmount);
    }
}