// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ILCalculator.sol";
import "./InsuranceVault.sol";

interface IPoolManager {
    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }
    function getSlot0(bytes32 poolId) external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality
    );
}

contract CoverageManager {
    ILCalculator public calculator;
    InsuranceVault public vault;
    IPoolManager public poolManager;
    address public owner;
    address public hook;
    
    uint256 public constant IL_THRESHOLD = 500; // 5% in basis points (10000 = 100%)
    uint256 public constant MAX_PAYOUT_BPS = 2000; // 20% in basis points

    struct Policy {
        address user;
        bytes32 poolId;
        uint256 liquidityAmount;
        uint256 initialPrice;
        uint256 coverageAmount;
        bool isActive;
    }

    mapping(bytes32 => Policy) public policies;
    mapping(bytes32 => bool) public validPositions;

    constructor(address _calculator, address _poolManager) {
        calculator = ILCalculator(_calculator);
        poolManager = IPoolManager(_poolManager);
        owner = msg.sender;
    }

    function setVault(address payable _vault) external {
        require(msg.sender == owner, "Only owner");
        require(address(vault) == address(0), "Vault already set");
        vault = InsuranceVault(_vault);
    }

    function setHook(address _hook) external {
        require(msg.sender == owner, "Only owner");
        require(hook == address(0), "Hook already set");
        hook = _hook;
    }

    function createPolicy(
        address user,
        bytes32 positionId,
        bytes32 poolId,
        uint256 liquidityAmount,
        uint256 initialPrice
    ) external payable {
        require(msg.sender == hook, "Only hook can register policy");
        require(!policies[positionId].isActive, "Policy already active");
        require(liquidityAmount > 0, "No liquidity");
        require(initialPrice > 0, "Invalid initial price");

        policies[positionId] = Policy({
            user: user,
            poolId: poolId,
            liquidityAmount: liquidityAmount,
            initialPrice: initialPrice,
            coverageAmount: msg.value * 10, // Coverage is 10x premium
            isActive: true
        });
        
        validPositions[positionId] = true;
    }

    function getPrice(bytes32 poolId) public view returns (uint256) {
        (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(poolId);
        uint256 sqrtPrice = uint256(sqrtPriceX96);
        uint256 scaled = (sqrtPrice * 1e9) >> 96;
        return scaled * scaled;
    }

    function getIL(bytes32 positionId) external view returns (uint256) {
        Policy memory policy = policies[positionId];
        require(policy.isActive, "No active policy");
        uint256 currentPrice = getPrice(policy.poolId);
        return calculator.calculateIL(policy.initialPrice, currentPrice);
    }

    function calculatePayout(bytes32 positionId) public view returns (uint256) {
        Policy memory policy = policies[positionId];
        if (!policy.isActive) return 0;

        uint256 currentPrice = getPrice(policy.poolId);
        uint256 ilBps = calculator.calculateIL(policy.initialPrice, currentPrice);
        
        if (ilBps <= IL_THRESHOLD) {
            return 0;
        }

        uint256 ilAmount = (policy.liquidityAmount * ilBps) / 10000;
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

    function claim(bytes32 positionId) external {
        Policy storage policy = policies[positionId];
        require(policy.isActive, "No active policy");
        require(policy.user == msg.sender, "Not policy owner");
        require(validPositions[positionId], "Unknown or invalid position");

        uint256 currentPrice = getPrice(policy.poolId);
        uint256 ilBps = calculator.calculateIL(policy.initialPrice, currentPrice);
        
        require(ilBps > IL_THRESHOLD, "IL below threshold");

        uint256 payout = calculatePayout(positionId);
        require(payout > 0, "No payout available");

        policy.isActive = false;
        validPositions[positionId] = false;
        
        vault.payClaim(msg.sender, payout);
    }
}
