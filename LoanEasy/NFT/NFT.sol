// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './ERC721.sol';

contract NFT is ERC721 {
    address admin;

    constructor() {
        admin = msg.sender;
    }

    // ensure function is only callable by the admin 
    modifier adminOnly() {
        require(msg.sender == admin, "You are not allowed to call this function as you are not the admin.");
        _;
    }

    // mint and transfer 
    function generateReward(address _to) public adminOnly {
        uint256 tokenId = mintToken();
        transferToken(tokenId, _to);
    }

    // returns total number of tokens minted
    function totalSupply() public view returns(uint256) {
        return allTokens.length;
    }

}