// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CoverageManager.sol";
import "./InsuranceVault.sol";

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

contract LiquidityInsuranceHook {
    CoverageManager public coverageManager;
    InsuranceVault public vault;
    IPoolManager public poolManager;

    struct LPPosition {
        uint256 liquidityAmount;
        uint256 entryPrice;
        bytes32 poolId;
        bool hasInsurance;
    }

    mapping(bytes32 => LPPosition) public lpPositions;

    constructor(address _coverageManager, address _vault, address _poolManager) {
        coverageManager = CoverageManager(_coverageManager);
        vault = InsuranceVault(payable(_vault));
        poolManager = IPoolManager(_poolManager);
    }

    // beforeAddLiquidity
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return this.beforeAddLiquidity.selector;
    }

    // afterAddLiquidity
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        int256 delta0,
        int256 delta1,
        bytes calldata hookData
    ) external payable returns (bytes4) {
        bool optInInsurance = false;
        if (hookData.length > 0) {
            optInInsurance = abi.decode(hookData, (bool));
        }

        if (optInInsurance) {
            uint256 amount = uint256(params.liquidityDelta > 0 ? params.liquidityDelta : -params.liquidityDelta);
            bytes32 poolId = keccak256(abi.encode(key));
            
            // Fetch real Uniswap price safely without overflow
            (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(poolId);
            uint256 sqrtPrice = uint256(sqrtPriceX96);
            uint256 scaled = (sqrtPrice * 1e9) >> 96;
            uint256 entryPrice = scaled * scaled;
            
            bytes32 positionId = keccak256(abi.encodePacked(sender, params.tickLower, params.tickUpper, amount));

            lpPositions[positionId] = LPPosition({
                liquidityAmount: amount,
                entryPrice: entryPrice,
                poolId: poolId,
                hasInsurance: true
            });

            // Create policy in CoverageManager. Forward the premium.
            coverageManager.createPolicy{value: msg.value}(
                sender,
                positionId,
                poolId,
                amount,
                entryPrice
            );
        }

        return this.afterAddLiquidity.selector;
    }

    // afterSwap
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        int256 delta0,
        int256 delta1,
        bytes calldata hookData
    ) external returns (bytes4) {
        return this.afterSwap.selector;
    }

    // beforeRemoveLiquidity
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        uint256 amount = uint256(params.liquidityDelta > 0 ? params.liquidityDelta : -params.liquidityDelta);
        bytes32 positionId = keccak256(abi.encodePacked(sender, params.tickLower, params.tickUpper, amount));
        
        LPPosition memory pos = lpPositions[positionId];
        if (pos.hasInsurance) {
            delete lpPositions[positionId];
        }

        return this.beforeRemoveLiquidity.selector;
    }

    receive() external payable {}
}
