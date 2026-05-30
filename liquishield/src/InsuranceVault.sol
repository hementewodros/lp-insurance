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

    function payClaim(address lp, uint256 amount) external {
        require(msg.sender == address(coverageManager) || msg.sender == owner, "Unauthorized");
        require(address(this).balance >= amount, "Vault lacks funds");
        payable(lp).transfer(amount);
    }

    // Function to allow vault to receive ether directly
    receive() external payable {}
}