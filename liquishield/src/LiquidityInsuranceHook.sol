// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CoverageManager.sol";
import "./InsuranceVault.sol";

// Mock interfaces for v4-core to make it compile if needed, 
// or assuming v4-periphery BaseHook. For hackathon, keeping it minimal.
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
}

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

    struct LPPosition {
        uint256 liquidityAmount;
        uint256 entryPrice;
        bool hasInsurance;
    }

    // Simplified mapping: user address -> LP Position
    mapping(address => LPPosition) public lpPositions;

    uint256 public constant PREMIUM = 0.01 ether;

    constructor(address _coverageManager, address _vault) {
        coverageManager = CoverageManager(_coverageManager);
        vault = InsuranceVault(payable(_vault));
    }

    // Hook responsibilities
    
    // beforeAddLiquidity → register position
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        // Decode hook data to check if user opted in for insurance
        bool optInInsurance = false;
        if (hookData.length > 0) {
            optInInsurance = abi.decode(hookData, (bool));
        }

        uint256 amount = uint256(params.liquidityDelta > 0 ? params.liquidityDelta : -params.liquidityDelta);

        lpPositions[sender] = LPPosition({
            liquidityAmount: amount,
            entryPrice: 0, // Will be set in afterAddLiquidity
            hasInsurance: optInInsurance
        });

        return this.beforeAddLiquidity.selector;
    }

    // afterAddLiquidity → store entry price
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        int256 delta0,
        int256 delta1,
        bytes calldata hookData
    ) external returns (bytes4) {
        // Simplified entry price as ratio of tokens (mock implementation)
        uint256 currentPrice = (uint256(delta1) * 1e18) / (uint256(delta0) == 0 ? 1 : uint256(delta0));
        
        LPPosition storage pos = lpPositions[sender];
        if (pos.hasInsurance && pos.liquidityAmount > 0) {
            pos.entryPrice = currentPrice;
            // Optionally interact with CoverageManager here or assume premium is paid via router
        }

        return this.afterAddLiquidity.selector;
    }

    // afterSwap → update price reference
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        int256 delta0,
        int256 delta1,
        bytes calldata hookData
    ) external returns (bytes4) {
        // Price reference updated in system. In a real hook, we might use the pool's slot0.
        // For hackathon, we could just evaluate IL here if needed or just store the last price.
        // The prompt says "afterSwap -> update price reference"
        uint256 currentPrice = 1e18; // Mock price
        
        return this.afterSwap.selector;
    }

    // beforeRemoveLiquidity → check IL + trigger claim logic
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        LPPosition memory pos = lpPositions[sender];
        if (pos.hasInsurance) {
            uint256 currentPrice = 1e18; // Mock price reference
            
            // Trigger IL evaluation and claim logic
            uint256 ilPercentage = coverageManager.getIL(sender, currentPrice);

            // If IL exceeds threshold, trigger a payout from the vault
            if (ilPercentage > 5) {
                // Trigger claim
                // vault.claimProtection(currentPrice);
            }
        }

        // Clean up position
        delete lpPositions[sender];

        return this.beforeRemoveLiquidity.selector;
    }

    // Allows users to pay premium directly to the hook
    receive() external payable {}
}