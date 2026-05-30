// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CoverageManager.sol";

contract InsuranceVault {
    CoverageManager public coverageManager;
    address public owner;

    constructor(address _coverageManager) {
        coverageManager = CoverageManager(_coverageManager);
        owner = msg.sender;
    }

    function depositCapital() external payable {
        // LPs provide capital to the vault to underwrite the insurance
    }

    function claimProtection(uint256 currentPrice) external {
        uint256 ilPercentage = coverageManager.getIL(msg.sender, currentPrice);
        require(ilPercentage > 5, "IL must exceed 5% to claim");
        
        (,, uint256 coverageAmount, ) = coverageManager.policies(msg.sender);
        require(coverageAmount > 0, "No coverage to claim");
        
        // Send IL protection to user
        require(address(this).balance >= coverageAmount, "Vault lacks funds");
        payable(msg.sender).transfer(coverageAmount);
    }

    // Function to allow vault to receive ether directly
    receive() external payable {}
}
