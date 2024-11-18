// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract USDT is ERC20 {
    constructor() {
        owner = address(this);
    }

    function addToAccount() public payable {
        require(msg.value > 0, "Please add a non-zero amount");
        // There will be off-chain checking of the live Wei/ETH to USD rate
        // For demonstrability purposes, we will use the conversion rate of 1 wei/10^-18 ETH to 0.001 USD
        uint256 amountAdded = msg.value / 1000;
        this.mint(msg.sender, amountAdded);
    }
}