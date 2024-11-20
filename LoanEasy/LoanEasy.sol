// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BorrowerManagement.sol";
import "./LenderManagement.sol";
import "./ProposalMarket.sol";

contract LoanEasy {
    address admin; // keep track of admin account

    // satelite contracts
    BorrowerManagement borrowerContract;
    LenderManagement lenderContract;
    ProposalMarket proposalMarketContract;

    constructor(BorrowerManagement borrowerManagementAddress, LenderManagement lenderManagementAddress,
        ProposalMarket proposalMarketAddress) {

        admin = msg.sender;

        borrowerContract = borrowerManagementAddress;
        lenderContract = lenderManagementAddress;
        proposalMarketContract = proposalMarketAddress;
    }

    // ensure function is only callable by the admin (Ownership design pattern (Authorization))
    modifier adminOnly() {
        require(msg.sender == admin, "You are not allowed to call this function as you are not the admin.");
        _;
    }

    // borrower management contract functions
    
    function add_borrower(string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location) public {
        
        borrowerContract.add_borrower(name, email, password, phoneNumber, location, msg.sender);
    }

    function get_borrower(uint256 borrowerId) public returns 
        (string memory, string memory, string memory, string memory, address, uint256[] memory,  BorrowerManagement.creditTier, uint256, uint256) {
        
        return borrowerContract.get_borrower(borrowerId);
    }

    function update_borrower(uint256 borrowerId, string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location) public {
        // get wallet address of owner
        address borrowerAddress = borrowerContract.get_owner(borrowerId);

        // only allow user to edit their own details
        require(msg.sender == borrowerAddress, "You are not allowed to edit these details.");

        borrowerContract.update_borrower(borrowerId, name, email, password, phoneNumber, location);
    }

    function update_borrower_tier(uint256 borrowerId, uint256 tierNum) public adminOnly() {
        borrowerContract.update_borrower_tier(borrowerId, tierNum);
    }

    function delete_borrower(uint256 borrowerId) public adminOnly() {
        borrowerContract.delete_borrower(borrowerId);
    }

    // update average days overdue for borrower
    function update_avg_days_overdue(uint256 borrowerId) public adminOnly() {
        ProposalMarket.proposal[] memory proposals;
        uint256 totalDaysOverdue = 0;

        proposals = proposalMarketContract.get_proposals_by_borrower(borrowerId);
        for (uint256 i = 0; i < proposals.length; i++) {
            totalDaysOverdue += proposals[i].numOfOverduedays;
        }

        borrowerContract.update_avg_days_overdue(borrowerId, totalDaysOverdue / proposals.length);
    }

    function get_avg_days_overdue(uint256 borrowerId) public view returns (uint256) {
        return borrowerContract.get_avg_days_overdue(borrowerId);
    }

    function update_defaulted_loans(uint256 borrowerId) public adminOnly() {
            // Update number of defaulted loans for borrower
            uint256 numOfDefaultedLoans = 0;
            uint256[] memory proposals = borrowerContract.get_borrower_proposal_list(borrowerId);
            for (uint256 i = 0; i < proposals.length; i++) {
                if (proposalMarketContract.get_proposal_by_id(borrowerId).status == ProposalMarket.proposalStatus.defaulted) {
                    numOfDefaultedLoans++;
                }
            }
            borrowerContract.update_defaulted_loans(borrowerId, numOfDefaultedLoans);
    }

    function get_defaulted_loans(uint256 borrowerId) public view returns (uint256) {
        return borrowerContract.get_defaulted_loans(borrowerId);
    }

    // lender management contract functions
    function add_lender(string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location) public {
            
        lenderContract.add_lender(name, email, password, phoneNumber, location, msg.sender);
    }

    function get_lender(uint256 lenderId) public returns (string memory, string memory, string memory, string memory, 
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


    // proposal market contract functions
    function add_proposal(uint256 borrowerId, string memory title, string memory description, 
        uint256 fundsRequired, uint256 daysUntilExpiration) public {

        proposalMarketContract.add_proposal(borrowerId, msg.sender, title, description, fundsRequired, daysUntilExpiration); 
    }

    function update_proposal(uint256 proposalId, string memory title, string memory description) public {
        proposalMarketContract.update_proposal(proposalId, title, description, msg.sender);
    }
    
    function delete_proposal(uint256 proposalId) public {
        proposalMarketContract.delete_proposal(proposalId, msg.sender);
    }
    
    function lend_to_proposal(uint256 lenderId, uint256 proposalId, uint256 amountToLoan) public {
        proposalMarketContract.lend_to_proposal(lenderId, proposalId, amountToLoan, msg.sender);
    }
    
    function payout_to_borrower(uint256 proposalId) public adminOnly() {
        proposalMarketContract.payout_to_borrower(proposalId);
    }
    
    function proposal_deadline_met(uint256 proposalId, bool isAccepted) public {
        proposalMarketContract.proposal_deadline_met(proposalId, isAccepted, msg.sender);
    }
    
    function repay_loan(uint256 proposalId) public {
        proposalMarketContract.repay_loan(proposalId, msg.sender);
    }
    
    function repayment_deadline_met(uint256 proposalId) public adminOnly() {
        proposalMarketContract.repayment_deadline_met(proposalId);
    }
    
    // function execute_insurance(uint256 proposalId) public adminOnly() {
    //     proposalMarketContract.execute_insurance(proposalId);
    // }
    
    function get_commission() public view returns (uint256) {
        return proposalMarketContract.get_commision();
    }

    function change_commission(uint256 newCommissionRate) public adminOnly() {
        proposalMarketContract.change_commission(newCommissionRate);
    }

    function get_interest_rate() public view returns (uint256) {
        return proposalMarketContract.get_interest_rate();
    }

    function change_interest_rate(uint256 newInterestRate) public adminOnly() {
        proposalMarketContract.change_interest_rate(newInterestRate);
    }

    function get_all_proposals() public view returns (ProposalMarket.proposal[] memory) {
        return proposalMarketContract.get_all_proposals();
    }

    function get_proposals_by_borrower(uint256 borrowerId) public view returns (ProposalMarket.proposal[] memory) {
        return proposalMarketContract.get_proposals_by_borrower(borrowerId);
    }

    function get_proposal_by_id(uint256 proposalId) public view returns (ProposalMarket.proposal memory) {
        return proposalMarketContract.get_proposal_by_id(proposalId);
    }

    function read_proposal(uint256 proposalId) public {
        return proposalMarketContract.read_proposal(proposalId);
    }
}