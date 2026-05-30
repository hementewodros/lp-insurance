// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ILCalculator.sol";
import "../src/InsuranceVault.sol";
import "../src/CoverageManager.sol";
import "../src/LiquidityInsuranceHook.sol";

contract LiquidityInsuranceTest is Test {
    ILCalculator public calculator;
    InsuranceVault public vault;
    CoverageManager public coverageManager;
    LiquidityInsuranceHook public hook;

    address public user = address(0x123);
    address public owner = address(0x456);

    function setUp() public {
        vm.startPrank(owner);
        calculator = new ILCalculator();
        
        // Note: Vault needs coverage manager address but we don't have it yet,
        // so we use a dummy then create coverage manager, then deploy hook
        // Actually, the constructor for Vault in liquishield takes (address _coverageManager)
        // Let's deploy CoverageManager first without vault, but wait, CoverageManager takes (_calculator, _vault)
        // We can just deploy them and assume they can call each other
        
        // Wait, CoverageManager in liquishield takes `(address _calculator, address payable _vault)`.
        // Let's modify Vault constructor if needed, or just pass address(0) for coverageManager to vault
        vault = new InsuranceVault(address(0));
        
        coverageManager = new CoverageManager(address(calculator), payable(address(vault)));
        
        // Update vault's coverage manager (we can't natively unless we add a setter, but let's just cheat with prank or we changed `payClaim` to allow msg.sender == address(coverageManager) directly using the stored coverageManager... Wait, in InsuranceVault: `require(msg.sender == address(coverageManager) || msg.sender == owner)`. We are owner, so we can't change coverageManager. Wait, `owner` deployed it, so `owner` can call payClaim, but `coverageManager` needs to call it. Since `vault.coverageManager` is `address(0)`, it won't allow `coverageManager`.
        // Let's just create them in right order if we can... wait, circular dependency.
        
        // It's okay, I'll update Vault to allow CoverageManager, or I will use `vm.mockCall`.
        vm.stopPrank();

        // Let's re-deploy them correctly
        vm.startPrank(owner);
        vault = new InsuranceVault(address(0));
        coverageManager = new CoverageManager(address(calculator), payable(address(vault)));
        // We can just use `vm.store` to set vault's coverageManager to the actual address
        vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(uint160(address(coverageManager)))));

        hook = new LiquidityInsuranceHook(address(coverageManager), address(vault));
        
        // fund vault with ETH
        vm.deal(address(vault), 10 ether);
        vm.stopPrank();

        vm.deal(user, 10 ether);
    }

    function testHookClaimFlow() public {
        vm.startPrank(user);

        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: address(0),
            fee: 0,
            tickSpacing: 0,
            hooks: address(hook)
        });

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1 ether,
            salt: bytes32(0)
        });

        // 1. User adds liquidity + buys insurance
        bytes memory hookData = abi.encode(true); // optInInsurance = true
        hook.beforeAddLiquidity(user, key, params, hookData);
        
        // Assume user pays premium via CoverageManager
        uint256 premium = 0.1 ether;
        coverageManager.buyCoverage{value: premium}(1 ether, 1000e18);

        hook.afterAddLiquidity(user, key, params, 1 ether, 1000e18, hookData);

        // 2. Simulate price decrease
        uint256 currentPrice = 500e18;
        
        // 3. Calculate IL > 5%
        uint256 ilAmount = calculator.calculateIL(1000e18, currentPrice, 1 ether);
        uint256 ilPercentage = (ilAmount * 10000) / 1 ether;
        assertTrue(ilPercentage > 500, "IL should be > 5%");

        uint256 balanceBefore = user.balance;

        // 4. Trigger claim
        // In the hook it would be triggered in beforeRemoveLiquidity, but since we updated CoverageManager to have `claim(currentPrice)`, let's call that, or mock the hook calling it.
        coverageManager.claim(currentPrice);

        // 5. Verify payout from InsuranceVault
        uint256 balanceAfter = user.balance;
        uint256 payout = balanceAfter - balanceBefore;
        assertTrue(payout > 0, "Should receive payout");

        // 6. Ensure double-claim is not possible
        vm.expectRevert("No active policy");
        coverageManager.claim(currentPrice);

        vm.stopPrank();
    }
}
