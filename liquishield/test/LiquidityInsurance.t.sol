// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ILCalculator.sol";
import "../src/InsuranceVault.sol";
import "../src/CoverageManager.sol";
import "../src/LiquidityInsuranceHook.sol";

contract MockPoolManager {
    mapping(bytes32 => uint160) public sqrtPrices;
    
    function setSlot0(bytes32 poolId, uint160 sqrtPriceX96) external {
        sqrtPrices[poolId] = sqrtPriceX96;
    }
    
    function getSlot0(bytes32 poolId) external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality
    ) {
        return (sqrtPrices[poolId], 0, 0, 0);
    }
}

contract LiquidityInsuranceTest is Test {
    ILCalculator public calculator;
    InsuranceVault public vault;
    CoverageManager public coverageManager;
    LiquidityInsuranceHook public hook;
    MockPoolManager public poolManager;

    address public user = address(0x123);
    address public owner = address(0x456);

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function priceToSqrtPriceX96(uint256 price) internal pure returns (uint160) {
        uint256 value = (price * (2**112)) / 1e18;
        return uint160(sqrt(value) * (2**40));
    }

    function setUp() public {
        vm.startPrank(owner);
        calculator = new ILCalculator();
        poolManager = new MockPoolManager();
        
        coverageManager = new CoverageManager(address(calculator), address(poolManager));
        vault = new InsuranceVault(address(coverageManager));
        
        coverageManager.setVault(payable(address(vault)));
        
        hook = new LiquidityInsuranceHook(address(coverageManager), address(vault), address(poolManager));
        coverageManager.setHook(address(hook));

        // fund vault with ETH
        vm.deal(address(vault), 10 ether);
        vm.stopPrank();

        vm.deal(user, 10 ether);
    }

    function testHookClaimFlow() public {
        // Prepare Pool and Position Keys
        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: address(0),
            fee: 0,
            tickSpacing: 0,
            hooks: address(hook)
        });

        bytes32 poolId = keccak256(abi.encode(key));

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1 ether, // liquidity amount
            salt: bytes32(0)
        });

        bytes32 positionId = keccak256(abi.encodePacked(user, params.tickLower, params.tickUpper, uint256(1 ether)));

        // Set initial slot0 price of pool to 1000 ETH/USDC
        poolManager.setSlot0(poolId, priceToSqrtPriceX96(1000e18));

        vm.startPrank(user);

        // 1. User adds liquidity with optInInsurance = true, paying premium (say 0.1 ether)
        bytes memory hookData = abi.encode(true);
        hook.beforeAddLiquidity(user, key, params, hookData);
        
        // Simulating the afterAddLiquidity called by poolManager with premium sent as msg.value
        hook.afterAddLiquidity{value: 0.1 ether}(user, key, params, 1 ether, 1000e18, hookData);

        // Check policy was registered correctly in CoverageManager
        (address policyUser, bytes32 policyPoolId, uint256 liquidityAmount, uint256 initialPrice, uint256 coverageAmount, bool isActive) = coverageManager.policies(positionId);
        assertEq(policyUser, user);
        assertEq(policyPoolId, poolId);
        assertEq(liquidityAmount, 1 ether);
        assertApproxEqAbs(initialPrice, 1000e18, 1e11);
        assertEq(coverageAmount, 1 ether); // 10x premium of 0.1 ether
        assertTrue(isActive);

        // 2. Simulate price movement to trigger IL
        // If price changes to 500 (halved), the IL is 5.71% (571 bps), which exceeds IL_THRESHOLD of 500 bps (5%)
        poolManager.setSlot0(poolId, priceToSqrtPriceX96(500e18));

        // 3. Verify IL is > 5% via CoverageManager
        uint256 ilBps = coverageManager.getIL(positionId);
        assertEq(ilBps, 571); // 5.71%

        uint256 balanceBefore = user.balance;

        // 4. Trigger claim
        coverageManager.claim(positionId);

        // 5. Verify payout from InsuranceVault
        uint256 balanceAfter = user.balance;
        uint256 payout = balanceAfter - balanceBefore;
        assertTrue(payout > 0, "Should receive payout");
        
        // Payout should be exactly 0.0571 ether
        assertEq(payout, 0.0571 ether);

        // 6. Ensure double-claim is not possible
        vm.expectRevert("No active policy");
        coverageManager.claim(positionId);

        vm.stopPrank();
    }
}
