// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ILCalculator.sol";
import "./InsuranceVault.sol";

contract CoverageManager {
    ILCalculator public calculator;
    InsuranceVault public vault;
    
    uint256 public constant IL_THRESHOLD = 500; // 5% in basis points (10000 = 100%)
    uint256 public constant MAX_PAYOUT_BPS = 2000; // 20% in basis points

    struct Policy {
        uint256 liquidityAmount;
        uint256 initialPrice;
        uint256 coverageAmount;
        bool isActive;
    }

    mapping(address => Policy) public policies;

    constructor(address _calculator, address payable _vault) {
        calculator = ILCalculator(_calculator);
        vault = InsuranceVault(_vault);
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

    function calculatePayout(address user, uint256 currentPrice) public view returns (uint256) {
        Policy memory policy = policies[user];
        require(policy.isActive, "No active policy");

        uint256 ilAmount = calculator.calculateIL(policy.initialPrice, currentPrice, policy.liquidityAmount);
        
        if (policy.liquidityAmount == 0) return 0;

        uint256 ilPercentage = (ilAmount * 10000) / policy.liquidityAmount;
        
        if (ilPercentage <= IL_THRESHOLD) {
            return 0;
        }

        uint256 maxPayout = (policy.liquidityAmount * MAX_PAYOUT_BPS) / 10000;
        uint256 payout = ilAmount;
        
        if (payout > policy.coverageAmount) {
            payout = policy.coverageAmount;
        }

        if (payout > maxPayout) {
            payout = maxPayout;
        }

        return payout;
    }

    function claim(uint256 currentPrice) external {
        Policy storage policy = policies[msg.sender];
        require(policy.isActive, "No active policy");

        uint256 ilAmount = calculator.calculateIL(policy.initialPrice, currentPrice, policy.liquidityAmount);
        
        require(policy.liquidityAmount > 0, "No liquidity");
        uint256 ilPercentage = (ilAmount * 10000) / policy.liquidityAmount;
        
        require(ilPercentage > IL_THRESHOLD, "IL below threshold");

        uint256 payout = calculatePayout(msg.sender, currentPrice);
        require(payout > 0, "No payout available");

        policy.isActive = false;
        
        vault.payClaim(msg.sender, payout);
    }
}
