// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract InsuranceVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public usdc;

    uint256 public totalEthReserves;
    uint256 public totalUsdcReserves;
    uint256 public totalCoveredValue; // Used for solvency ratio

    event CapitalDeposited(address indexed depositor, address token, uint256 amount);
    event ClaimPaid(address indexed lp, address token, uint256 amount);

    constructor(address _usdc, address initialOwner) Ownable(initialOwner) {
        usdc = IERC20(_usdc);
    }

    receive() external payable {
        depositETH();
    }

    function depositETH() public payable nonReentrant {
        require(msg.value > 0, "Amount must be > 0");
        totalEthReserves += msg.value;
        emit CapitalDeposited(msg.sender, address(0), msg.value);
    }

    function depositUSDC(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        totalUsdcReserves += amount;
        emit CapitalDeposited(msg.sender, address(usdc), amount);
    }

    function payClaim(address lp, uint256 amount) external onlyOwner nonReentrant {
        require(totalEthReserves >= amount, "Insufficient ETH reserves");
        totalEthReserves -= amount;
        
        (bool success, ) = lp.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ClaimPaid(lp, address(0), amount);
    }

    function payClaimUSDC(address lp, uint256 amount) external onlyOwner nonReentrant {
        require(totalUsdcReserves >= amount, "Insufficient USDC reserves");
        totalUsdcReserves -= amount;
        usdc.safeTransfer(lp, amount);

        emit ClaimPaid(lp, address(usdc), amount);
    }

    function updateCoveredValue(uint256 _newCoveredValue) external onlyOwner {
        totalCoveredValue = _newCoveredValue;
    }

    // Solvency ratio = Total Reserves / Total Covered Value (in a common denominator, here assuming simplified)
    // For a real implementation, price oracles would be used to normalize ETH and USDC to USD.
    function getSolvencyRatio() external view returns (uint256) {
        if (totalCoveredValue == 0) return type(uint256).max;
        // Simplified: assuming totalReserves normalized
        // This should be adjusted based on Oracle prices
        return (totalEthReserves + totalUsdcReserves) * 10000 / totalCoveredValue;
    }
}
