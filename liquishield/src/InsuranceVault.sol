// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InsuranceVault {
    address public immutable coverageManager;
    address public owner;

    event ClaimPaid(address indexed lp, uint256 amount);
    event CapitalDeposited(address indexed depositor, uint256 amount);

    constructor(address _coverageManager) {
        coverageManager = _coverageManager;
        owner = msg.sender;
    }

    function depositCapital() external payable {
        emit CapitalDeposited(msg.sender, msg.value);
    }

    function payClaim(address lp, uint256 amount) external {
        require(msg.sender == coverageManager, "Only CoverageManager can trigger payouts");
        require(address(this).balance >= amount, "Vault lacks funds");
        
        (bool success, ) = lp.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ClaimPaid(lp, amount);
    }

    receive() external payable {
        emit CapitalDeposited(msg.sender, msg.value);
    }
}
