// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BorrowerManagement.sol"; 
import "./LenderManagement.sol";
import "./Stablecoin/USDT.sol";

contract ProposalMarket {
    uint256 private commissionRate = 500; // Solidity does not support floating point numbers so division by 10000 is used to get 0.5% commision
    uint256 private interestRate = 1225; // Fixed rate of 12.25% (Will be stored as 1225 and divide by 10000 when computing)
    uint256 private commissionPoolBalance = 0; // To add when implementing insurance, taken to comm

    uint256 constant acceptancePeriod = 2 days; // time given for borrowers to accept or decline partial loan
    uint256 constant verificationPeriod = 2 days; // time given for lenders to verify before funds get released to borrower
    uint256 constant loanPeriod = 365 days; // time given for borrower to repay their loans
    uint256 constant insurancePeriod = 60 days; // time given before lenders get their insurance payout if borrower did not repay

    // keep track of all proposals
    mapping(uint256 => proposal) proposalList;
    uint256 private proposalCount = 0;

    // Borrower Management contract
    BorrowerManagement borrowerContract;
    // Lender Management contract
    LenderManagement lenderContract;
    // USDT Contract
    USDT usdtContract;

    constructor(BorrowerManagement borrowerManagementAddress, LenderManagement lenderManagementAddress, USDT usdtAddress) {
        borrowerContract = borrowerManagementAddress;
        lenderContract = lenderManagementAddress;
        usdtContract = usdtAddress;
    }

    // status of a proposal
    enum proposalStatus {
        open, // proposal is open for lending
        closed, // proposal deadline reached or funding goal reached
        pendingVerification, // proposal waiting for verification by lenders before executing paid out
        awaitingRepayment, // proposal waiting for repayment (after paid out)
        late, // proposal repayment deadline reached and funds have not been repaid by borrower
        defaulted, // proposal repayment required insurance from platform
        concluded, // proposal repaid (borrower or insurance) and concluded
        deleted // proposal has been deleted by borrower
    }

    // Event to log actions
    event ProposalProgress(uint256 id, string actionType, uint256 timestamp);
    event ProposalDetails(uint256 proposalId, address borrower, string title, string description, uint256 timestamp, uint256 expiresAt, uint256 endDate, uint256 numOfLenders, proposalStatus status);
    event ProposalFundDetails(uint256 fundsRequired, uint256 fundsRaised, loan[] loans, bool goalReached, bool fundsDistributed, bool loanRepaid);
    event LenderAction(uint256 id, string actionType);
    event RepaymentProcessed(address from, address to, uint256 loanAmount, uint256 repaymentAmount);
    event InsuranceProcessed(address to, uint256 loanAmount, uint256 insuranceAmount, uint256 coveragePercentage);

    // struct of proposal
    struct proposal {
        uint256 proposalId;
        address borrower;
        string title;
        string description;
        uint256 interest_rate;
        uint256 commission;
        uint256 fundsRequired; // funding goal
        uint256 fundsRaised;
        uint256 timestamp; // start time
        uint256 expiresAt; // expiry deadline
        uint256 endDate; // actual end date of proposal, default is expiry date
        uint256 numOfLenders;
        proposalStatus status;
        loan[] allLoans; // funds loaned to proposal by lender
        bool goalReached; // proposal goal reached or not reached by deadline
        bool fundsDistributed; // true if funds are distributed to borrower or refunded to lender else false
        bool loanRepaid; // proposal successfully repaid or not by owner
    }

    // for owner's repayment
    struct loan {
        uint256 lender; // Reference to Lender ID in LenderManagement
        uint256 amount; // Loaned amount
        uint256 dueDate; // Due date for repayment
        bool isRepaid; // Repayment status
    }

    modifier validProposalId(uint256 proposalId) {
        require(proposalId < proposalCount, "Please enter a valid proposal id");
        _;
    }

    modifier validBorrowerId(uint256 borrowerId, address borrowerAddress) {
        // Ensure valid borrower id is used
        require(borrowerContract.get_owner(borrowerId) == borrowerAddress, "Invalid borrower id is used for owner address");
        _;
    }

    modifier validLoanAmount(uint256 fundingGoal, uint256 borrowerId) {
        // ensure that funding goal borrower set is within limit (based on credit tier)
        // get the credit tier of the borrower
        BorrowerManagement.creditTier borrowerTier = borrowerContract.get_borrower_tier(borrowerId);

        if (borrowerTier == BorrowerManagement.creditTier.gold) {
            // if credit tier is gold, borrower can list their proposal as max funding limit of 500 stablecoins
            require(fundingGoal <= 500, "You are only allowed to list your proposal with a maximum funding goal of 500.");

        } else if (borrowerTier == BorrowerManagement.creditTier.silver) {
            // if credit tier is silver, borrower can list their proposal as max funding limit of 250 stablecoins
            require(fundingGoal <= 250, "You are only allowed to list your proposal with a maximum funding goal of 250.");

        } else if (borrowerTier == BorrowerManagement.creditTier.bronze) {
            // if credit tier is bronze, borrower can list their proposal as max funding limit of 100 stablecoins
            require(fundingGoal <= 100, "You are only allowed to list your proposal with a maximum funding goal of 100.");
        }

        _;
    }

    // add proposal to list of proposals
    function add_proposal(uint256 borrowerId, address borrower, string memory title, 
        string memory description, uint256 fundsRequired, uint256 daysUntilExpiration) public 
        validBorrowerId(borrowerId, borrower) validLoanAmount(fundsRequired, borrowerId) {

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
        newProposal.interest_rate = interestRate;
        newProposal.commission = commissionRate;
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
    function update_proposal(uint256 proposalId, string memory title, string memory description) public validProposalId(proposalId) {
        // ensure proposal hasn't been deleted
        require(proposalList[proposalId].status != proposalStatus.deleted, "Proposal has been deleted and cannot be updated.");

        proposal memory p = proposalList[proposalId];

        if (keccak256(abi.encodePacked(title)) != keccak256(abi.encodePacked(""))) {
            p.title = title;
        }
        if (keccak256(abi.encodePacked(description)) != keccak256(abi.encodePacked(""))) {
            p.description = description;
        }
        
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

        require(proposalList[proposalId].fundsDistributed == false, "Proposal funds have already been refunded.");

        // refund the lenders 
        perform_proposal_refund(proposalId);
    }

    // lenders lend funds / loan to selected proposal
    function lend_to_proposal(uint256 lenderId, uint256 proposalId, uint256 amountToLoan, address lenderAddress) public validProposalId(proposalId) {
        require(amountToLoan > 0, "Please enter a non-zero amount to loan");
        require(usdtContract.balanceOf(lenderAddress) >= amountToLoan, "Not enough funds in lender's account to loan");
        require(lenderAddress == lenderContract.get_owner(lenderId), "Invalid lender id.");
        proposal storage p = proposalList[proposalId];

        // ensure that proposal allows funding
        require(p.status == proposalStatus.open, "Proposal is no longer opened for funding.");

        // lender can loan any amount, return back excess if exceed funding goal
        if (p.fundsRaised + amountToLoan >= p.fundsRequired) {
            // funding goal is reached

            // Only transfer required amount to reach funding goal (Excess amount is not transferred)
            uint256 loanAmount = p.fundsRequired - p.fundsRaised;

            // Transfer required loan amount to proposalMarketContract
            // Lender must approve proposal market contract to transfer loanAmount to proposal market 
            usdtContract.transferFrom(lenderAddress, address(this), loanAmount);

            // create new loan and add it to proposal's loan list
            createAndStoreLoan(lenderId, loanAmount, p.proposalId);

            // emit event to show lender successfully loaned fund
            emit LenderAction(lenderId, "Funds loaned to proposal");

            // update proposal details: add money to funds raised, change status to closed, goal reached to true
            p.fundsRaised += loanAmount;
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
            // Transfer required loan amount to proposalMarketContract
            // Lender must approve proposal market contract to transfer loanAmount to proposal market 
            usdtContract.transferFrom(lenderAddress, address(this), amountToLoan);

            // create a new loan and add it to lender's list of loan
            createAndStoreLoan(lenderId, amountToLoan, p.proposalId);

            // update proposal details: add money to funds raised
            p.fundsRaised += amountToLoan;

            // emit event to show lender successfully loaned fund
            emit LenderAction(lenderId, "Funds loaned to proposal");
        }
    }

    function createAndStoreLoan(uint256 lenderId, uint256 amount, uint256 proposalId) internal {
        proposal storage p = proposalList[proposalId];

        // create a new loan and add it to lender's list of loan
        // Use 0 as placeholder for due date as it is not set yet
        loan memory newLoan = loan(lenderId, amount, 0, false);
        p.allLoans.push(newLoan);

        // edit lender attributes: total amount loaned and add to loan list
        lenderContract.update_amount_loaned(lenderContract.get_amount_loaned(lenderId) + amount, lenderId);
        lenderContract.add_loan(lenderId, p.proposalId);
    }

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
        uint256 commissionToPay = p.fundsRequired * p.commission / 10000;
        uint256 amountToBorrower = p.fundsRequired - commissionToPay;

        // add commission amount to commission pool
        commissionPoolBalance += commissionToPay;

        // funds distributed true
        p.fundsDistributed = true;

        // status to awaiting repayment
        p.status = proposalStatus.awaitingRepayment;

        // set a 1 year deadline for repayment
        loan[] storage proposalLoans = p.allLoans;
        for (uint256 i = 0; i < proposalLoans.length; i++) {
            proposalLoans[i].dueDate = block.timestamp + loanPeriod;
        }

        // transfer from proposal market contract to borrower
        usdtContract.transfer(p.borrower, amountToBorrower);
    }

    // perform refund of proposal funds
    function perform_proposal_refund(uint256 proposalId) internal validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];

        // ensure loan easy have enough money --> do we want to do this? (Scenario is unlikely unless there is attack)
        require(usdtContract.balanceOf(address(this)) >= p.fundsRaised, "LoanEasy does not have enough funds, fail to refund lenders.");

        // get the list of loans from proposal
        loan[] memory proposalLoans = p.allLoans;

        // loop through the lenders that loaned proposal and refund them
        for (uint256 i = 0; i < proposalLoans.length; i++) {
            loan memory currLoan = proposalLoans[i];

            usdtContract.transfer(lenderContract.get_owner(currLoan.lender), currLoan.amount);
            //lenderContract.update_amount_loaned(get_amount_loaned(lenderId) - currLoan.amount, lenderId);
        }

        // set funds distributed to true, means funds have been refunded
        p.fundsDistributed = true;

        emit ProposalProgress(proposalId, "Proposal has been refunded", block.timestamp);
    }

    // deadline of proposal met and funding goal not reached --> allow choice between accept or decline funds
    function proposal_deadline_met(uint256 proposalId, bool isAccepted) public validProposalId(proposalId) {
        proposal storage p = proposalList[proposalId];

        // check status is open
        require(p.status == proposalStatus.open, "The proposal must be opened");
        
        // check for deadline met
        require(block.timestamp >= p.endDate, "Proposal deadline has not been met yet");

        // status to closed
        p.status = proposalStatus.closed;

        // Case where owner accept partial funds (Must be within 2 days of deadline)
        if (isAccepted) {
            accept_partial_funds(proposalId);
        } 
        // Case where owner declines partial funds
        else {
            decline_partial_funds(proposalId);
        }
    }

    // funding goal is not met and borrower decides to accept proposal funds --> payout
    function accept_partial_funds(uint256 proposalId) internal validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];

        // check status is closed
        require(p.status == proposalStatus.closed, "Proposal needs to be closed first");

        // check funds distributed is false
        require(p.fundsDistributed == false, "Funds have already been distributed");
        
        // check is today date is within 2 days (acceptance period) from end date (deadline)
        require((block.timestamp > p.endDate) && (block.timestamp <= (p.endDate + acceptancePeriod)), 
        "Proposal must be accepted within 2 days of proposal's end date");

        // change status to pending verification
        p.status = proposalStatus.pendingVerification;
        
        emit ProposalProgress(proposalId, "Proposal is currently pending verification", block.timestamp);
    }

    // funding goal is not met and borrower decides to decline proposal funds --> refund
    function decline_partial_funds(uint256 proposalId) internal validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];
        // check status is closed
        require(p.status == proposalStatus.closed, "Proposal needs to be closed first");
        // check funds distributed is false
        require(p.fundsDistributed == false, "Funds have already been distributed");
        
        // refund to lenders
        perform_proposal_refund(proposalId);
        
        // status to concluded
        p.status = proposalStatus.concluded;

        emit ProposalProgress(proposalId, "Proposal has been refunded and concluded", block.timestamp);
    }

    // borrower fully repays loan
    // borrower has to approve proposal market as spender on usdt contract first
    function repay_loan(uint256 proposalId, address borrowerAddress) public validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];

        // ensure that borrower has sufficient funds to process repayment
        uint256 totalRepaymentAmount = p.fundsRaised * (10000 + p.interest_rate) / 10000;
        require(usdtContract.balanceOf(borrowerAddress) >= totalRepaymentAmount);

        // check status is awaiting repayment
        require(p.status == proposalStatus.awaitingRepayment, "Proposal needs to be awaiting for repayment first");
        // check loan repaid is false
        require(p.loanRepaid == false);

        // transfer the repayment amount to the proposal market contract
        usdtContract.transferFrom(borrowerAddress, address(this), totalRepaymentAmount);

        // repay loan then set loan repaid to true
        for(uint256 i = 0; i < p.allLoans.length; i++) {
            loan storage indivLoan = p.allLoans[i];

            // pay back the loan with interest
            uint256 repaymentAmount = indivLoan.amount * (10000 + p.interest_rate) / 10000;
            indivLoan.isRepaid = true;

            // get the lender address and repay loan from borrower to lender
            address lenderAddress = lenderContract.get_owner(indivLoan.lender);
            // transfer amount from proposal market contract to lender
            usdtContract.transfer(lenderAddress, repaymentAmount);

            emit RepaymentProcessed(borrowerAddress, lenderAddress, indivLoan.amount, repaymentAmount);
        }

        // set status to concluded
        p.status = proposalStatus.concluded;
        p.loanRepaid = true;
        emit ProposalProgress(proposalId, "Proposal has been repayed and concluded", block.timestamp);
    }

    // repayment deadline is met without repayment from borrower, credit tier will be affected (admin only)
    function repayment_deadline_met(uint256 proposalId) public validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];

        // check status is awaiting repayment
        require(p.status == proposalStatus.awaitingRepayment);
        // check for loan deadline exceed
        require(block.timestamp > p.allLoans[0].dueDate);
        // check loan repaid is false
        require(p.loanRepaid == false);

        // set proposal status to be late
        p.status = proposalStatus.late;
        emit ProposalProgress(proposalId, "Proposal is late for repayment, deadline has reached", block.timestamp);

        // affect credit tier --> done off chain
        emit ProposalProgress(proposalId, "Proposal is late for repayment, credit tier will be affected", block.timestamp);
    }

    // todo
    // to recalculate credit tier when repayment deadline is met and no repayment was made
    function credit_risk_calculation() internal {
        //
    }

    // execute insurance repayment and conclude --> did not repay by the set deadline of 1 year + 2 months grace (admin only)
    function execute_insurance(uint256 proposalId) public validProposalId(proposalId) {
        // get the proposal from proposal id
        proposal storage p = proposalList[proposalId];

        // check status is late
        require(p.status == proposalStatus.late);
        // check for loan deadline + 2 months met
        require(block.timestamp >= p.allLoans[0].dueDate + insurancePeriod);

        uint256 totalInsurance;

        // calculate the total amount required for insurance payout
        for(uint256 i = 0; i < p.allLoans.length; i++) {
            loan storage indivLoan = p.allLoans[i];

            // check insurance amount according to matrix and sum it up
            uint256 coveragePercentage = calculate_loan_coverage(lenderContract.get_owner(indivLoan.lender));
            uint256 insuranceAmount = indivLoan.amount * (coveragePercentage / 100);
            totalInsurance += insuranceAmount;
        }

        require(commissionPoolBalance >= totalInsurance, "Platform does not have enough funds.");

        // do insurance payouts as a whole
        for(uint256 i = 0; i < p.allLoans.length; i++) {
            loan storage indivLoan = p.allLoans[i];

            // get the lender address and repay loan from borrower to lender
            address lenderAddress = lenderContract.get_owner(indivLoan.lender);

            // check insurance amount according to matrix
            uint256 coveragePercentage = calculate_loan_coverage(lenderAddress);
            uint256 insuranceAmount = indivLoan.amount * (coveragePercentage / 100);
            
            // transfer insurance amount from proposal market contract to lender
            usdtContract.transfer(lenderAddress, insuranceAmount);
            indivLoan.isRepaid = true;

            emit InsuranceProcessed(lenderAddress, indivLoan.amount, insuranceAmount, coveragePercentage);
        }

        // update the commission pool balance
        commissionPoolBalance -= totalInsurance;

        // set proposal status to be deafulted
        p.status = proposalStatus.defaulted;
    }

    // todo
    // helper function for insurance compensation matrix
    // need nft contract
    function calculate_loan_coverage(address lender) internal returns (uint256) {
        //uint256 proportion = no. of nfts lender own / total supply * 100

        /* if (proportion >= 50) {
            return 50;
        } else if (proportion >= 40) {
            return 40;
        } else if (proportion >= 30) {
            return 30;
        } else if (proportion >= 20) {
            return 20;
        } else {
            return 10;
        } */

        return 10;
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