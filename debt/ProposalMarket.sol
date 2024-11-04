pragma solidity ^0.5.0;


import './BorrowerManagement.sol'; 
import './LenderManagement.sol';
import './NoteContract.sol';

contract ProposalMarket {

    uint256 private commissionFee; // Solidity does not support floating point numbers so division by 1000 is used to get 0.5% commision
    uint256 private interestRate; // Fixed rate of 12.25% (Will be stored as 1225 and divide by 10000 when computing)
    mapping(uint256 => proposal) proposalList; // List of proposals created by each id
    uint256 private proposalCount;

    // Notes contract
    NoteContract noteContract;
    // Borrower Management contract
    BorrowerManagement borrowerContract;
    // Lender Management contract
    LenderManagement lenderContract;

    constructor(BorrowerManagement borrowerManagementAddress, LenderManagement lenderManagementAddress, NoteContract noteContractAddress) public {
        borrowerContract = borrowerManagementAddress;
        lenderContract = lenderManagementAddress;
        noteContract = noteContractAddress;
    }

    // Status of a project
    enum proposalStatus {
        OPEN, // Project is open for lending
        REVERTED, // Project was not successful, and lenders are refunded
        DELETED, // Project has been deleted, and lenders are refunded
        PAIDOUT // Project has been paid out to its owner
    }

    // Event to log actions
    event Action(
        uint256 id,
        string actionType,
        uint256 timestamp
    );

    // Struct of proposal
    struct proposal {
        address borrower;
        string title;
        string description;
        uint256 interest_rate; 
        uint256 commission;
        uint256 funds_required;
        uint256 funds_raised;
        uint256 timestamp;
        uint256 expiresAt;
        uint256 numOfLenders;
        proposalStatus status;
    }

    modifier validProposalId(uint256 proposalId) {
        require(proposalId < proposalCount, "Please enter a valid proposal id");
        _;
    }

    // add_proposal
    function add_proposal(uint256 borrowerId, address borrower, string memory title, 
    string memory description,
    uint256 funds_required, uint256 daysUntilExpiration) public {
        
        require(borrowerContract.get_owner(borrowerId) != borrower, "Invalid borrower id is used for owner address");
        require(keccak256(abi.encodePacked(title)) != keccak256(abi.encodePacked("")), "Title cannot be empty");
        require(keccak256(abi.encodePacked(description)) != keccak256(abi.encodePacked("")), "Description cannot be empty");
        require(daysUntilExpiration > 0, "Number of days til expiration must be greater than 0");
        require(funds_required > 0, "Please enter a fund amount greater than 0");
        
        proposal memory p = proposal(
            borrower,
            title,
            description,
            interestRate,
            commissionFee,
            funds_required,
            0,
            block.timestamp,
            block.timestamp + (daysUntilExpiration * 1 days),
            0,
            proposalStatus.OPEN
        );

        proposalList[proposalCount] = p;
        borrowerContract.add_proposal(borrowerId, proposalCount);
        emit Action(proposalCount++, "Proposal is created", block.timestamp);
    }

    // read_proposal
    function read_proposal(uint256 proposalId) public validProposalId(proposalId) returns (address, string memory, string memory,
    uint256, uint256, uint256, uint256, uint256, uint256, uint256, proposalStatus) {
        proposal memory p = proposalList[proposalId];

        emit Action(proposalId, "Proposal is read", block.timestamp);
        return (p.borrower, p.title, p.description, p.interest_rate, p.commission, p.funds_required, 
        p.funds_raised, p.timestamp, p.expiresAt, p.numOfLenders, p.status);
    }

    // remove_proposal
    function remove_proposal(uint256 proposalId) public validProposalId(proposalId) {
        require(proposalList[proposalId].status == proposalStatus.OPEN, "Project is no longer opened");

        proposalList[proposalId].status = proposalStatus.DELETED;
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
        if (daysUntilExpiration > 0) {
            p.expiresAt = block.timestamp + (daysUntilExpiration * 1 days);
        }
        
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

    // change_commission
    function change_commission(uint256 newCommissionFee) public {
        commissionFee = newCommissionFee;
    }

    // Change interest rate
    function change_interest_rate(uint256 newInterestRate) public {
        interestRate = newInterestRate;
    }
}