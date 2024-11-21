// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './ERC721.sol';

contract NFT is ERC721 {

    // mint and transfer 
    function generateReward(address _to) public {
        uint256 tokenId = mintToken();
        transferToken(tokenId, _to);
    }

    // returns total number of tokens minted
    function totalSupply() public view returns(uint256) {
        return allTokens.length;
    }

}