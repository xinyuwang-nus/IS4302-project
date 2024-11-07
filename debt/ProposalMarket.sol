// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BorrowerManagement.sol"; 
import "./LenderManagement.sol";

contract ProposalMarket {

    uint256 private commissionRate = 500; // Solidity does not support floating point numbers so division by 1000 is used to get 0.5% commision
    uint256 private interestRate = 1225; // Fixed rate of 12.25% (Will be stored as 1225 and divide by 10000 when computing)

    uint256 constant acceptancePeriod = 2 days; // time given for borrowers to accept or decline partial loan
    uint256 constant verificationPeriod = 2 days; // time given for lenders to verify before funds get released to borrower
    uint256 constant loanPeriod = 365 days; // time given for borrower to repay their loans
    uint256 constant insurancePeriod = loanPeriod + 30 days; // time given before lenders get their insurance payout if borrower did not repay

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

    // status of a proposal
    enum proposalStatus {
        open, // proposal is open for lending
        closed, // proposal deadline reached or funding goal reached
        pendingVerification, // proposal waiting for verification by lenders before executing paid out
        awaitingRepayment, // proposal waiting for repayment (after paid out)
        concluded, // proposal repaid (borrower or insurance) and concluded
        deleted // proposal has been deleted by borrower
    }

    // Event to log actions
    event ProposalProgress(uint256 id, string actionType, uint256 timestamp);
    event ProposalDetails(uint256 proposalId, address borrower, string title, string description, uint256 timestamp, uint256 expiresAt, uint256 endDate, uint256 numOfLenders, proposalStatus status);
    event ProposalFundDetails(uint256 fundsRequired, uint256 fundsRaised, loan[] loans, bool goalReached, bool fundsDistributed, bool loanRepaid);
    event LenderAction(uint256 id, string actionType);

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
        uint256 endDate; // actual end date of proposal, default is expiry date
        uint256 numOfLenders;
        proposalStatus status;
        loan[] allLoans; // funds loaned to proposal by lender
        bool goalReached; // proposal goal reached or not reached by deadline
        bool fundsDistributed; // proposal funds paid out to owner (accept) or refunded (decline)
        bool loanRepaid; // proposal successfully repaid or not by owner

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

    // add proposal to list of proposals
    function add_proposal(uint256 borrowerId, address borrower, string memory title, 
        string memory description, uint256 fundsRequired, uint256 daysUntilExpiration) public {
        // Ensure valid borrower id is used
        require(borrowerContract.get_owner(borrowerId) == borrower, "Invalid borrower id is used for owner address");

        // Ensure input fields are filled and valid
        require(keccak256(abi.encodePacked(title)) != keccak256(abi.encodePacked("")), "Title cannot be empty");
        require(keccak256(abi.encodePacked(description)) != keccak256(abi.encodePacked("")), "Description cannot be empty");
        require(daysUntilExpiration > 0, "Number of days till expiration must be greater than 0");
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
        newProposal.endDate = block.timestamp + (daysUntilExpiration * 1 days);
        newProposal.numOfLenders = 0;
        newProposal.status = proposalStatus.open;
        newProposal.goalReached = false;
        newProposal.fundsDistributed = false;
        newProposal.loanRepaid = false;

        // add the new proposal to borrower struct's list of proposals in borrower management
        borrowerContract.add_proposal(borrowerId, proposalCount);
        // emit event to show new proposal created
        emit ProposalProgress(proposalCount++, "Proposal is created", block.timestamp);
    }

    // update proposal details and upload business documents off chain
    function update_proposal(uint256 proposalId, string memory title, string memory description
        //, uint256 daysUntilExpiration
        ) public validProposalId(proposalId) {
        
        // ensure proposal hasn't been deleted
        require(proposalList[proposalId].status != proposalStatus.deleted, "Proposal has been deleted and cannot be updated.");

        proposal memory p = proposalList[proposalId];

        if (keccak256(abi.encodePacked(title)) != keccak256(abi.encodePacked(""))) {
            p.title = title;
        }
        if (keccak256(abi.encodePacked(description)) != keccak256(abi.encodePacked(""))) {
            p.description = description;
        }
        /* if (daysUntilExpiration > 0) {
            p.expiresAt = block.timestamp + (daysUntilExpiration * 1 days);
        } */
        
        emit ProposalProgress(proposalId, "Proposal is updated", block.timestamp);
    }

    // borrower delete proposal and funds re refunded back to lenders
    function delete_proposal(uint256 proposalId, address creatorAddress) public validProposalId(proposalId) {
        // ensure only creator of proposal can delete it
        require(creatorAddress == proposalList[proposalId].borrower, "You are not allowed to delete this proposal.");
        
        // only can delete the proposal if it is open
        require(proposalList[proposalId].status == proposalStatus.open, "Proposal is no longer opened.");

        // set status to deleted
        proposalList[proposalId].status = proposalStatus.deleted;
        emit ProposalProgress(proposalId, "Proposal is deleted", block.timestamp);

        require(proposalList[proposalId].fundsDistributed == false, "Proposal funds have been refunded.");

        // refund the lenders 
        perform_proposal_refund(proposalId);
    }

    // lenders lend funds / loan to selected proposal
    function lend_to_proposal(uint256 lenderId, uint256 proposalId, address lenderAddress) public payable validProposalId(proposalId) {
        require(msg.value > 0, "Include the amount of funds you want to loan.");
        require(lenderAddress == lenderContract.get_owner(lenderId), "Invalid lender id.");
        proposal storage p = proposalList[proposalId];

        // ensure that proposal allows funding
        require(p.status == proposalStatus.open, "Proposal is no longer opened for funding.");

        // lender can loan any amount, return back excess if exceed funding goal
        if (p.fundsRaised + msg.value >= p.fundsRequired) {
            // funding goal is reached
            // return back excess funds to lender
            uint256 excess = (p.fundsRaised + msg.value) - p.fundsRequired;
            (bool success, ) = lenderAddress.call{value: excess}("");
            require(success, "Excess funds transfer failed");

            // emit event to show lender successfully loaned fund
            emit LenderAction(lenderId, "Excess funds refunded to lender");

            // create new loan and add it to proposal's loan list
            uint256 loanAmount = msg.value - excess;
            createAndStoreLoan(lenderId, loanAmount, p.proposalId);

            // emit event to show lender successfully loaned fund
            emit LenderAction(lenderId, "Funds loaned to proposal");

            // update proposal details: add money to funds raised, change status to closed, goal reached to true
            p.fundsRaised = p.fundsRaised + loanAmount;
            p.status = proposalStatus.closed;
            p.goalReached = true;
            p.endDate = block.timestamp;

            // emit event to show funding goal is reached
            emit ProposalProgress(proposalId, "Proposal funding goal is reached", block.timestamp);

            // update proposal status to wait for 2 days before pay out
            p.status = proposalStatus.pendingVerification;
            // wait 2 days then perform pay out
            emit ProposalProgress(proposalId, "The funds will be released to borrower in 2 days, lenders can verify proposal before funds get released.", block.timestamp);

        } else {
            // funding goal not reached
            // create a new loan and add it to lender's list of loan
            createAndStoreLoan(lenderId, msg.value, p.proposalId);

            // update proposal details: add money to funds raised
            p.fundsRaised = p.fundsRaised + msg.value;

            // emit event to show lender successfully loaned fund
            emit LenderAction(lenderId, "Funds loaned to proposal");
        }
    }

    function createAndStoreLoan(uint256 lenderId, uint256 amount, uint256 proposalId) internal {
        proposal storage p = proposalList[proposalId];

        // create a new loan and add it to lender's list of loan
        loan memory newLoan = loan(lenderId, amount);
        p.allLoans.push(newLoan);

        // edit lender attributes: total amount loaned and add to loan list
        lenderContract.update_amount_loaned(lenderContract.get_amount_loaned(lenderId) + amount, lenderId);
        lenderContract.add_loan(lenderId, p.proposalId);
    }

    // todo
    // pay out funds to borrower (funds accepted by borrower) --> admin only
    function payout_to_borrower(uint256 proposalId) public validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];

        // check if proposal is pending verification and haven't received funds
        require((p.status == proposalStatus.pendingVerification) && (p.fundsDistributed == false), "Proposal is unable to receive payout, either proposal not pending verification or funds were already paid.");

        if(p.goalReached == true) {
            // check if 2 days have passed from end date
            require(block.timestamp > p.endDate + verificationPeriod, "Proposal is still undergoing verification from end date and cannot be paid out yet.");
        } else {
            // check if 4 days have passed from end date (include acceptance period and verification period)
            require(block.timestamp > p.endDate + acceptancePeriod + verificationPeriod, "Proposal is still undergoing verification from acceptance date and cannot be paid out yet.");
        }

        // commision fee deducted, remaining to borrower
        // funds distributed true
        // status to awaiting repayment
        // set a 1 year deadline for repayment?
    }

    // perform refund of proposal funds
    function perform_proposal_refund(uint256 proposalId) internal validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];

        // ensure loan easy have enough money --> do we want to do this?
        require(address(this).balance >= p.fundsRaised, "LoanEasy does not have enough funds, fail to refund lenders.");

        // get the list of loans from proposal
        loan[] memory proposalLoans = p.allLoans;

        // loop through the lenders that loaned proposal and refund them
        for (uint256 i = 0; i < proposalLoans.length; i++) {
            loan memory currLoan = proposalLoans[i];

            (bool success, ) = lenderContract.get_owner(currLoan.lender).call{value: currLoan.amount}("");
            require(success, "Refund transfer failed");

            //lenderContract.update_amount_loaned(get_amount_loaned(lenderId) - currLoan.amount, lenderId);
        }

        // set funds distributed to true, means funds have been refunded
        p.fundsDistributed = true;

        emit ProposalProgress(proposalId, "Proposal has been refunded", block.timestamp);
    }

    // todo
    // deadline of proposal met and funding goal not reached --> allow choice between accept or decline funds
    function proposal_deadline_met() public {
        // check status is open
        // check for deadline met
        // provide choice?
        // status to closed
    }

    // todo
    // funding goal is not met and borrower decides to accept proposal funds --> payout
    function accept_partial_funds() public {
        // check status is closed
        // check funds distributed is false
        // check is today date is within 2 days (acceptance period) from end date (deadline)
        // edit acceptance date
        // change status to pending verification
    }

    // todo
    // funding goal is not met and borrower decides to decline proposal funds --> refund
    function decline_partial_funds() public {
        // check status is closed
        // check funds distributed is false
        // check is today date is within 2 days (acceptance period) from end date (deadline) if not auto decline?
        // refund to lenders
        // status to concluded
    }

    // todo
    // borrower repays loan --> proposal concludes
    function repay_loan() public {
        // check status is awaiting repayment
        // check loan repaid is false
        // repay loan then set loan repaid to true
        // status to concluded
    }

    // todo
    // execute insurance repayment and conclude --> did not repay by the set deadline of 1 year
    // admin only
    function execute_insurance() public {
        // check status is awaiting repayment
        // check for loan deadline + 2 months met
        // check loan repaid is false
        // do insurance payouts
        // affect credit tier?
        // status to concluded
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
    function get_all_proposals() public view returns (proposal[] memory) {
        proposal[] memory activeProposals = new proposal[](proposalCount);

        // loop through proposal list mapping and store proposals as an array
        for (uint256 i = 0; i < proposalCount; i++) {
            activeProposals[i] = proposalList[i];
        }

        return activeProposals;
    }

    // get proposals by a specific borrower ID
    function get_proposals_by_borrower(uint256 borrowerId) public view returns (proposal[] memory) {
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
    function get_proposal_by_id(uint256 proposalId) public view validProposalId(proposalId) returns (proposal memory) {
        return proposalList[proposalId];
    }

    // get proposal details
    function read_proposal(uint256 proposalId) public validProposalId(proposalId) {
            
        proposal memory p = proposalList[proposalId];

        emit ProposalDetails(p.proposalId, p.borrower, p.title, p.description, p.timestamp, p.expiresAt, p.endDate, p.numOfLenders, p.status);
        emit ProposalFundDetails(p.fundsRequired, p.fundsRaised, p.allLoans, p.goalReached, p.fundsDistributed, p.loanRepaid);
    }
}