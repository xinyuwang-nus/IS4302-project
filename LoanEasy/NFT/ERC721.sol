// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC721 {
    // Mapping from token IDs to owner addresses
    mapping(uint256 => address) public tokenOwner;
    
    // Mapping from owner addresses to balances
    mapping(address => uint256) public balanceOf;
    
    // Array of all token IDs
    uint256[] public allTokens;

    // Event for token transfer
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    
    constructor() {
        // Initialize the contract
    }

    function mintToken() internal returns(uint256) {        
        uint256 newTokenId = allTokens.length + 1;
        allTokens.push(newTokenId);
        tokenOwner[newTokenId] = msg.sender;
        balanceOf[msg.sender]++;
        
        _mint(msg.sender, newTokenId);
        return newTokenId;
    }

    function transferToken(uint256 _tokenId, address _to) internal {
        require(tokenOwner[_tokenId] != address(0), "Token does not exist");
        require(tokenOwner[_tokenId] == msg.sender || 
                (tokenOwner[_tokenId] != address(this) && 
                 balanceOf[msg.sender] > 0),
               "Caller is not owner nor approved");
        
        require(_to != address(0), "Recipient address cannot be the zero address");
        
        tokenOwner[_tokenId] = _to;
        balanceOf[msg.sender]--;
        balanceOf[_to]++;
    }

    function _mint(address to, uint256 tokenId) internal {
        require(tokenId != 0, "Token ID cannot be zero");
        require(tokenId <= allTokens.length, "Token ID does not exist");
        
        tokenOwner[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }
}
