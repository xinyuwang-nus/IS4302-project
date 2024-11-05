// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BorrowerManagement.sol"; 
import "./LenderManagement.sol";

contract ProposalMarket {

    uint256 private commissionRate = 500; // Solidity does not support floating point numbers so division by 1000 is used to get 0.5% commision
    uint256 private interestRate = 1225; // Fixed rate of 12.25% (Will be stored as 1225 and divide by 10000 when computing)

    // keep track of all proposals
    mapping(uint256 => proposal) proposalList;
    uint256 private proposalCount = 0;

    // Borrower Management contract
    BorrowerManagement borrowerContract;
    // Lender Management contract
    LenderManagement lenderContract;

    constructor(BorrowerManagement borrowerManagementAddress, LenderManagement lenderManagementAddress) {
        borrowerContract = borrowerManagementAddress;
        lenderContract = lenderManagementAddress;
    }

    // Status of a project
    enum proposalStatus {
        open, // Project is open for lending
        repayment, // Proposal waiting for repayment
        conclude, // Project repaid and concluded

        goalReached,// Project goal is reached by deadline
        goalNotReached, // Project goal not reached by deadline
        deleted, // Project has been deleted

        paidOut, // Project funds paid out to owner (accepted)
        reverted, // Project funds refunded to lenders (declined)

        isRepaid,
        notRepaid
    }

    // Event to log actions
    event Action(
        uint256 id,
        string actionType,
        uint256 timestamp
    );

    // struct of proposal
    struct proposal {
        uint256 proposalId;
        address borrower;
        string title;
        string description;
        // uint256 interest_rate; --> interest rate will always be the same 
        // uint256 commission; --> commision rate always the same
        uint256 fundsRequired; // funding goal
        uint256 fundsRaised;
        uint256 timestamp; // start time
        uint256 expiresAt; // expiry deadline
        uint256 numOfLenders;
        proposalStatus status;
        loan[] allLoans; // funds loaned to proposal by lender
    }

    // for owner's repayment
    struct loan {
        uint256 lender; // Reference to Lender ID in LenderManagement
        uint256 amount; // Loaned amount
        // uint256 dueDate; // Due date for repayment
        // bool isRepaid; // Repayment status --> repayment is a 1 time thing
    }

    modifier validProposalId(uint256 proposalId) {
        require(proposalId < proposalCount, "Please enter a valid proposal id");
        _;
    }

    // add_proposal
    function add_proposal(uint256 borrowerId, address borrower, string memory title, 
        string memory description, uint256 fundsRequired, uint256 daysUntilExpiration) public {
        // Ensure valid borrower id is used
        //require(borrowerContract.get_owner(borrowerId) != borrower, "Invalid borrower id is used for owner address");
        require(borrowerContract.get_owner(borrowerId) == borrower, "Invalid borrower id is used for owner address");

        // Ensure input fields are filled and valid
        require(keccak256(abi.encodePacked(title)) != keccak256(abi.encodePacked("")), "Title cannot be empty");
        require(keccak256(abi.encodePacked(description)) != keccak256(abi.encodePacked("")), "Description cannot be empty");
        require(daysUntilExpiration > 0, "Number of days til expiration must be greater than 0");
        require(fundsRequired > 0, "Please enter a fund amount greater than 0");

        // create a new proposal and add it to the proposal list
        proposal storage newProposal = proposalList[proposalCount];
        newProposal.proposalId = proposalCount;
        newProposal.borrower = borrower;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.fundsRequired = fundsRequired;
        newProposal.fundsRaised = 0;
        newProposal.timestamp = block.timestamp;
        newProposal.expiresAt = block.timestamp + (daysUntilExpiration * 1 days);
        newProposal.numOfLenders = 0;
        newProposal.status = proposalStatus.open;

        // add the new proposal to borrower struct's list of proposals in borrower management
        borrowerContract.add_proposal(borrowerId, proposalCount);
        // emit event to show new proposal created
        emit Action(proposalCount++, "Proposal is created", block.timestamp);
    }

    // read_proposal
    function read_proposal(uint256 proposalId) public validProposalId(proposalId) returns (uint256, address, string memory, string memory,
        uint256, uint256, uint256, uint256, uint256, proposalStatus) {
        proposal memory p = proposalList[proposalId];

        emit Action(proposalId, "Proposal is read", block.timestamp);
        return (p.borrower, p.title, p.description, p.fundsRequired, 
        p.fundsRaised, p.timestamp, p.expiresAt, p.numOfLenders, p.status);
    }

    // remove_proposal
    function remove_proposal(uint256 proposalId) public validProposalId(proposalId) {
        require(proposalList[proposalId].status == proposalStatus.open, "Project is no longer opened");

        proposalList[proposalId].status = proposalStatus.deleted;
        // Perform refund (todo)
        emit Action(proposalId, "Proposal is deleted", block.timestamp);
    }

    // update_proposal
    function update_proposal(uint256 proposalId, string memory title, 
        string memory description, uint256 daysUntilExpiration) public validProposalId(proposalId) {

        proposal storage p = proposalList[proposalId];
        
        if (keccak256(abi.encodePacked(title)) != keccak256(abi.encodePacked(""))) {
            p.title = title;
        }
        if (keccak256(abi.encodePacked(description)) != keccak256(abi.encodePacked(""))) {
            p.description = description;
        }
        /* if (daysUntilExpiration > 0) {
            p.expiresAt = block.timestamp + (daysUntilExpiration * 1 days);
        } */
        
        emit Action(proposalId, "Proposal is updated", block.timestamp);
    }

    // Lend to proposal
    function lend_to_proposal() public {

    }

    // execute_proposal
    function execute_proposal() public {

    }

    // create_note (Called in execute_proposal)
    function create_note() public {

    }

    // pay_borrower (Called in execute_proposal)
    function pay_borrower() public {

    }

    // perform_refund
    function perform_refund() public {

    }

    // get commission rate
    function get_commision() public view returns (uint256) {
        return commissionRate;
    }

    // change commission rate 
    function change_commission(uint256 newCommissionRate) public {
        commissionRate = newCommissionRate;
    }

    // get interest rate
    function get_interest_rate() public view returns (uint256) {
        return interestRate;
    }

    // change interest rate
    function change_interest_rate(uint256 newInterestRate) public {
        interestRate = newInterestRate;
    }

    // get all proposals
    function getAllProposals() public view returns (proposal[] memory) {
        proposal[] memory activeProposals = new proposal[](proposalCount);

        // loop through proposal list mapping and store proposals as an array
        for (uint256 i = 0; i < proposalCount; i++) {
            activeProposals[i] = proposalList[i];
        }

        return activeProposals;
    }

    // get proposals by a specific borrower ID
    function getProposalsByBorrower(uint256 borrowerId) public view returns (proposal[] memory) {
        // get the proposal list of the borrower (in the borrower struct) based on borrowerId
        uint256[] memory borrowerProposalList = borrowerContract.get_borrower_proposal_list(borrowerId);

        require(borrowerProposalList.length > 0, "Owner has not created any proposals.");

        // new array to store all borrower proposals
        proposal[] memory borrowerProposals = new proposal[](borrowerProposalList.length);
        // keep track of new array index
        uint256 index = 0;

        // loop through the proposal list of borrower (index of the proposals)
        for (uint256 i = 0; i < borrowerProposalList.length; i++) {
            // add proposal according to proposal index into new array
            borrowerProposals[index] = proposalList[borrowerProposalList[i]];
            index++;
        }

        return borrowerProposals;
    }

    // get an existing proposal by proposal ID
    function getProposalById(uint256 proposalId) public view returns (proposal memory) {
        require(proposalId < proposalCount, "Proposal does not exist");
        return proposalList[proposalId];
    }
}