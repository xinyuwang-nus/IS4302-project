// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BorrowerManagement.sol";
import "./LenderManagement.sol";
import "./ProposalMarket.sol";
import "./SecondaryMarket.sol";

contract LoanEasy {
    address admin; // keep track of admin account

    // satelite contracts
    BorrowerManagement borrowerContract;
    LenderManagement lenderContract;
    ProposalMarket proposalMarketContract;
    SecondaryMarket secondaryMarketContract;

    constructor(BorrowerManagement borrowerManagementAddress, LenderManagement lenderManagementAddress,
        ProposalMarket proposalMarketAddress, SecondaryMarket secondaryMarketAddress) public {

        admin = msg.sender;

        borrowerContract = borrowerManagementAddress;
        lenderContract = lenderManagementAddress;
        proposalMarketContract = proposalMarketAddress;
        secondaryMarketContract = secondaryMarketAddress;
    }

    // ensure function is only callable by the admin 
    modifier adminOnly() {
        require(msg.sender == admin, "You are not allowed to call this function as you are not the admin.");
        _;
    }

    // borrower management contract functions
    function add_borrower(string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location) public {
        
        borrowerContract.add_borrower(name, email, password, phoneNumber, location, msg.sender);
    }

    function get_borrower(uint256 borrowerId) public payable returns 
        (string memory, string memory, string memory, string memory, address, uint256[] memory,  BorrowerManagement.creditTier) {
        
        return borrowerContract.get_borrower(borrowerId);
    }

    function update_borrower(uint256 borrowerId, string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location) public {
        // get wallet address of owner
        address walletAddress = borrowerContract.get_owner(borrowerId);

        // only allow user to edit their own details
        require(msg.sender == walletAddress, "You are not allowed to edit these details.");

        borrowerContract.update_borrower(borrowerId, name, email, password, phoneNumber, location);
    }

    /* function add_proposal(uint256 borrowerId, uint256 proposalId) public {
        borrowerContract.add_proposal(borrowerId, proposalId);
    } */

    function remove_borrower(uint256 borrowerId) public adminOnly {
        borrowerContract.remove_borrower(borrowerId);
    }

    function edit_borrower_tier(uint256 borrowerId, uint256 tierNum) public adminOnly {
        borrowerContract.edit_borrower_tier(borrowerId, tierNum);
    }

    // lender management contract functions
    function add_lender(string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location, address walletAddress) public {
            lenderContract.add_lender(name, email, password, phoneNumber, location, walletAddress);
    }

    function get_lender(uint256 lenderId) public returns 
    (string memory, string memory, string memory, string memory, 
    address, uint256, uint256[] memory) {
        return lenderContract.get_lender(lenderId);
    }

    function update_lender(uint256 lenderId, string memory name, string memory email, string memory password,
    string memory phoneNumber, string memory location) public {
        address addressOfLender = lenderContract.get_owner(lenderId);
        require(msg.sender == addressOfLender, "You are not allowed to edit these details");
        lenderContract.update_lender(lenderId, name, email, password, phoneNumber, location);
    }

    function delete_lender(uint256 lenderId) public adminOnly() {
        lenderContract.remove_lender(lenderId);
    }

    function update_amount_loaned(uint256 amount, uint256 lenderId) public adminOnly() {
        lenderContract.update_amount_loaned(amount, lenderId);
    }

    // CRUD notes

    // CRUD platform stats

    // CRUD proposals
    
}