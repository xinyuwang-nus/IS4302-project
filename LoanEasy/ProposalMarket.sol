// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BorrowerManagement.sol";
import "./LenderManagement.sol";

contract ProposalMarket {
    struct Loan {
        uint256 lender; // Reference to Lender ID in LenderManagement
        uint256 amount; // Loaned amount
        uint256 dueDate; // Due date for repayment
        bool isRepaid; // Repayment status
    }

    struct Proposal {
        uint256 id;
        uint256 borrower; // Reference to Borrower ID in BorrowerManagement
        string title;
        string description;
        uint256 fundsRequired;
        uint256 fundsRaised;
        bool isActive;
        bool isFunded;
        uint256 deadline;
        uint256 decisionTime;
        bool loanAccepted;
        Loan[] loans; // Array of loans for this proposal
    }

    uint256 private proposalCount = 0;
    uint256 private proposalMaxId = 0;
    mapping(uint256 => Proposal) private proposals; // Mapping of proposal ID to Proposal

    BorrowerManagement private borrowerManagement;
    LenderManagement private lenderManagement;

    uint256 public commissionRate = 1; // TODO: Default commission rate (%)
    uint256 public compensationPoolBalance; // Balance of the compensation pool

    uint256 public interestRate = 5; // TODO: Default interest rate (%)

    event ProposalAdded(
        uint256 proposalId,
        uint256 borrowerId,
        string title,
        uint256 fundsRequired
    );
    event ProposalRemoved(uint256 proposalId, uint256 borrowerId);
    event ProposalUpdated(
        uint256 proposalId,
        string newTitle,
        string newDescription,
        uint256 newDeadline
    );
    event ProposalFunded(uint256 proposalId);
    event ProposalCompletelyFunded(uint256 proposalId);
    event ProposalAccepted(uint256 proposalId);
    event ProposalDeclined(uint256 proposalId);
    event BorrowerPaid(uint256 proposalId, uint256 amount);
    event FundsReturnedToLenders(uint256 proposalId);
    event LoanPaid(
        uint256 proposalId,
        uint256 loanIndex,
        address lender,
        uint256 repaymentAmount
    );
    event AllLoansRepaid(uint256 proposalId);

    constructor(address _borrowerManagement, address _lenderManagement) {
        borrowerManagement = BorrowerManagement(_borrowerManagement);
        lenderManagement = LenderManagement(_lenderManagement);
    }

    // Add a new proposal
    function addProposal(
        string memory _title,
        string memory _description,
        uint256 _fundsRequired,
        uint256 _durationInDays, // Accept the duration in days as input, to calculate deadline
        uint256 _borrowerId
    ) public {
        // Retrieve the borrower details from BorrowerManagement
        BorrowerManagement.Borrower memory borrower = borrowerManagement
            .getBorrower(_borrowerId);

        // Check that the sender's address matches the borrower's stored address
        require(
            msg.sender == borrower.addr,
            "Only the registered borrower can create this proposal"
        );

        proposalCount++;
        proposalMaxId++;

        uint256 deadlineTimestamp = block.timestamp + (_durationInDays * 1 days);

        // Initialize a new Proposal with the verified borrower ID
        // This can avoid the UnimplementedFeatureError while keeping the array loans initialized as empty. Avoid Loan[] memory emptyLoans;
        Proposal storage newProposal = proposals[proposalMaxId];
        newProposal.id = proposalMaxId;
        newProposal.borrower = _borrowerId;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.fundsRequired = _fundsRequired;
        newProposal.fundsRaised = 0;
        newProposal.isActive = true;
        newProposal.isFunded = false;
        newProposal.deadline = deadlineTimestamp;
        newProposal.decisionTime = deadlineTimestamp + 2 days;
        newProposal.loanAccepted = false;

        emit ProposalAdded(proposalMaxId, _borrowerId, _title, _fundsRequired);
    }

    // Read all proposals
    function getAllProposals() public view returns (Proposal[] memory) {
        Proposal[] memory activeProposals = new Proposal[](proposalCount);
        uint256 index = 0;

        for (uint256 i = 1; i <= proposalMaxId; i++) {
            if (proposals[i].id != 0) {
                // Check if proposal exists (not deleted)
                activeProposals[index] = proposals[i];
                index++;
            }
        }

        return activeProposals;
    }

    // Read proposals by a specific borrower ID
    function getProposalsByBorrower(
        uint256 _borrowerId
    ) public view returns (Proposal[] memory) {
        // Count the number of proposals for the specified borrower ID
        uint256 count = 0;
        for (uint256 i = 1; i <= proposalMaxId; i++) {
            if (proposals[i].id != 0 && proposals[i].borrower == _borrowerId) {
                count++;
            }
        }

        // Initialize an array to store proposals for the specified borrower ID
        Proposal[] memory borrowerProposals = new Proposal[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= proposalMaxId; i++) {
            if (proposals[i].id != 0 && proposals[i].borrower == _borrowerId) {
                borrowerProposals[index] = proposals[i];
                index++;
            }
        }

        return borrowerProposals;
    }

    // Update an existing proposal by proposal ID
    function getProposalById(
        uint256 _id
    ) public view returns (Proposal memory) {
        require(_id > 0 && _id <= proposalMaxId, "Proposal does not exist");
        return proposals[_id];
    }

    function removeProposal(uint256 _proposalId) public {
        Proposal storage proposal = proposals[_proposalId];

        // Ensure proposal exists
        require(proposal.id != 0, "Proposal does not exist");

        // Retrieve borrower details and verify permission
        BorrowerManagement.Borrower memory borrower = borrowerManagement
            .getBorrower(proposal.borrower);
        require(
            msg.sender == borrower.addr,
            "Only the proposal owner can remove this proposal"
        );

        // Delete the proposal by setting it to default values
        delete proposals[_proposalId];
        proposalCount--;

        emit ProposalRemoved(_proposalId, proposal.borrower);
    }

    function updateProposal(
        uint256 _id,
        string memory _newTitle,
        string memory _newDescription,
        uint256 _newDurationInDays // Accept the new duration in days as input
    ) public {
        Proposal storage proposal = proposals[_id];

        // Ensure proposal exists
        require(proposal.id != 0, "Proposal does not exist");

        // TODO: does this need admin's permission? Otherwise the borrower can keep extending the deadline
        // Retrieve borrower details and verify permission
        BorrowerManagement.Borrower memory borrower = borrowerManagement
            .getBorrower(proposal.borrower);
        require(
            msg.sender == borrower.addr,
            "Only the proposal owner can update this proposal"
        );

        uint256 newDeadline = block.timestamp + (_newDurationInDays * 1 days);

        // Ensure the new deadline is later than the current deadline
        require(
            newDeadline > proposal.deadline,
            "New deadline must be later than the current deadline"
        );

        proposal.title = _newTitle;
        proposal.description = _newDescription;
        proposal.deadline = newDeadline;
        proposal.decisionTime = newDeadline + 2 days;

        emit ProposalUpdated(_id, _newTitle, _newDescription, newDeadline);
    }

    // Fund a proposal
    function fundProposal(
        uint256 _proposalId,
        uint256 _lenderId
    ) public payable {
        // Retrieve the lender details from LenderManagement
        LenderManagement.Lender memory lender = lenderManagement.getLender(
            _lenderId
        );
        // Check that the lender's address matches the lender's stored address
        require(
            msg.sender == lender.addr,
            "Only the registered lender can fund this proposal"
        );

        Proposal storage proposal = proposals[_proposalId];

        require(proposal.isActive, "Proposal is not active");
        require(
            block.timestamp <= proposal.deadline,
            "Funding period has ended"
        );

        require(
            proposal.fundsRaised + msg.value <= proposal.fundsRequired,
            "Exceeds required funds"
        );

        proposal.fundsRaised += msg.value;

        // Create a new Loan entry and add to the proposal's loan list
        Loan memory newLoan = Loan({
            lender: _lenderId,
            amount: msg.value,
            dueDate: 0, // Placeholder value to indicate "not yet set"
            isRepaid: false
        });
        proposal.loans.push(newLoan);

        // Update the lender's total loaned amount
        lenderManagement.updateLender(
            _lenderId,
            lender.name,
            lender.amountLoaned + msg.value
        );

        emit ProposalFunded(_proposalId);

        if (proposal.fundsRaised >= proposal.fundsRequired) {
            proposal.isFunded = true;
            emit ProposalCompletelyFunded(_proposalId);
        }
    }

    // TODO: when the money should be took from the lender's account? When the lender agrees to fund (in fundProposal) or when the borrower accepts the loan?
    // Borrower accepts the loan (if fully funded)
    function acceptLoan(uint256 _proposalId, uint256 _borrowerId) public {
        // Retrieve the borrower details from BorrowerManagement
        BorrowerManagement.Borrower memory borrower = borrowerManagement
            .getBorrower(_borrowerId);

        // Check that the sender's address matches the borrower's stored address
        require(
            msg.sender == borrower.addr,
            "Only the registered borrower can continue with this operation"
        );

        Proposal storage proposal = proposals[_proposalId];
        require(
            _borrowerId == proposal.borrower,
            "Only the owner can accept the loan"
        );

        require(proposal.isFunded, "Proposal is not fully funded");
        require(!proposal.loanAccepted, "Loan already accepted");

        uint256 commission = calculateCommission(proposal.fundsRaised);
        compensationPoolBalance += commission; // Add commission to the compensation pool
        uint256 netAmount = proposal.fundsRaised - commission;

        proposal.loanAccepted = true;
        proposal.isActive = false;

        // Set the due date for each loan to one year from the current time
        for (uint256 i = 0; i < proposal.loans.length; i++) {
            proposal.loans[i].dueDate = block.timestamp + 365 days;
        }

        // Transfer funds to the borrower
        (bool success, ) = payable(borrower.addr).call{value: netAmount}("");
        require(success, "Transfer to borrower failed");

        emit ProposalAccepted(_proposalId);
    }

    // Function to allow borrower to accept or decline partially funded proposals after the deadline
    function decidePartialFunding(
        uint256 _proposalId,
        uint256 _borrowerId,
        bool acceptPartialFunding
    ) public {
        Proposal storage proposal = proposals[_proposalId];

        // Validate borrower's decision eligibility, including checking the deadline
        validateBorrowerDecision(proposal, _borrowerId);

        // Check if the decision period has expired
        if (block.timestamp > proposal.decisionTime) {
            // If expired, refund lenders
            refundLenders(_proposalId);
            proposal.isActive = false;
            emit ProposalDeclined(_proposalId);
        } else if (acceptPartialFunding) {
            processPartialAcceptance(proposal, _borrowerId);
            proposal.loanAccepted = true;
            proposal.isActive = false;
            emit ProposalAccepted(_proposalId);
        } else {
            // Borrower explicitly declines partial funding
            refundLenders(_proposalId);
            proposal.isActive = false;
            emit ProposalDeclined(_proposalId);
        }
    }

    // Helper function to validate borrower's decision eligibility
    function validateBorrowerDecision(
        Proposal storage proposal,
        uint256 _borrowerId
    ) internal view {
        BorrowerManagement.Borrower memory borrower = borrowerManagement
            .getBorrower(_borrowerId);

        require(
            msg.sender == borrower.addr,
            "Only the registered borrower can continue with this operation"
        );
        require(
            _borrowerId == proposal.borrower,
            "Only the owner can make this decision"
        );
        require(
            block.timestamp > proposal.deadline,
            "Funding period has not ended yet"
        );
        require(!proposal.isFunded, "Proposal is already fully funded");
        require(!proposal.loanAccepted, "Loan has already been processed");
    }

    // Helper function to process partial acceptance
    function processPartialAcceptance(
        Proposal storage proposal,
        uint256 _borrowerId
    ) internal {
        uint256 commission = calculateCommission(proposal.fundsRaised);
        compensationPoolBalance += commission;
        uint256 netAmount = proposal.fundsRaised - commission;

        proposal.loanAccepted = true;
        proposal.isActive = false;

        // Set the due date for each loan to one year from the current time
        for (uint256 i = 0; i < proposal.loans.length; i++) {
            proposal.loans[i].dueDate = block.timestamp + 365 days;
        }

        BorrowerManagement.Borrower memory borrower = borrowerManagement
            .getBorrower(_borrowerId);

        // Transfer funds to the borrower after deducting commission
        (bool success, ) = payable(borrower.addr).call{value: netAmount}("");
        require(success, "Transfer to borrower failed");
    }

    // Function to refund all lenders if the proposal is expired or declined
    function refundLenders(uint256 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];
        for (uint256 i = 0; i < proposal.loans.length; i++) {
            Loan storage loan = proposal.loans[i];
            if (!loan.isRepaid) {
                LenderManagement.Lender memory lender = lenderManagement
                    .getLender(loan.lender);
                (bool success, ) = lender.addr.call{value: loan.amount}("");
                require(success, "Refund transfer failed");
                loan.isRepaid = true; // Mark as refunded
            }
        }
        emit FundsReturnedToLenders(_proposalId);
    }

    // Repay all loans within a proposal
    function repayAllLoans(uint256 _proposalId) public payable {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.loanAccepted, "Loan not accepted");

        uint256 totalRepaymentRequired = 0;

        // Calculate the total repayment required for all loans
        for (uint256 i = 0; i < proposal.loans.length; i++) {
            Loan storage loan = proposal.loans[i];
            if (!loan.isRepaid) {
                uint256 repaymentAmount = loan.amount +
                    ((loan.amount * interestRate) / 100);
                totalRepaymentRequired += repaymentAmount;
            }
        }

        require(
            msg.value >= totalRepaymentRequired,
            "Insufficient repayment amount for all loans"
        );

        // Repay each loan using repayLoan
        for (uint256 i = 0; i < proposal.loans.length; i++) {
            Loan storage loan = proposal.loans[i];
            if (!loan.isRepaid) {
                uint256 singleRepaymentAmount = loan.amount +
                    ((loan.amount * interestRate) / 100);
                repayLoanHelper(_proposalId, i, singleRepaymentAmount);
            }
        }

        emit AllLoansRepaid(_proposalId);
    }

    function repayLoanHelper(
        uint256 _id,
        uint256 _loanIndex,
        uint256 repaymentAmount
    ) internal {
        Proposal storage proposal = proposals[_id];
        Loan storage loan = proposal.loans[_loanIndex];
        if (!loan.isRepaid) {
            loan.isRepaid = true;
            LenderManagement.Lender memory lender = lenderManagement.getLender(
                loan.lender
            );
            // Transfer repayment amount to the lender
            (bool success, ) = lender.addr.call{value: repaymentAmount}("");
            require(success, "Repayment transfer failed");
            emit LoanPaid(_id, _loanIndex, lender.addr, repaymentAmount);
        }
    }

    // Method to pay a specific loan within a proposal
    function repayOneLoan(
        uint256 _proposalId,
        uint256 _loanIndex
    ) public payable {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        require(proposal.loanAccepted, "Loan not accepted");

        require(_loanIndex < proposal.loans.length, "Loan does not exist");

        Loan storage loan = proposal.loans[_loanIndex];
        require(!loan.isRepaid, "Loan already repaid");

        uint256 repaymentAmount = loan.amount +
            ((loan.amount * interestRate) / 100);

        // Ensure sufficient funds are sent for repayment
        require(msg.value >= repaymentAmount, "Insufficient payment amount");

        // Mark the loan as repaid
        loan.isRepaid = true;

        // Transfer repayment amount to the lender
        LenderManagement.Lender memory lender = lenderManagement.getLender(
            loan.lender
        );
        (bool success, ) = payable(lender.addr).call{value: repaymentAmount}(
            ""
        );
        require(success, "Repayment transfer to lender failed");

        // Calculate any excess amount and refund to the borrower
        uint256 excessAmount = msg.value - repaymentAmount;
        if (excessAmount > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{
                value: excessAmount
            }("");
            require(
                refundSuccess,
                "Refund of excess payment to borrower failed"
            );
        }

        emit LoanPaid(_proposalId, _loanIndex, lender.addr, repaymentAmount);
    }

    // TODO: Who's in charge of this? Admin? Trigger automatically?
    // Check for default after a 2-month (60 days) grace period and compensate lenders
    function checkDefault(uint256 _id) public {
        Proposal storage proposal = proposals[_id];

        for (uint256 i = 0; i < proposal.loans.length; i++) {
            Loan storage loan = proposal.loans[i];
            if (block.timestamp > loan.dueDate + 60 days && !loan.isRepaid) {
                compensateLender(loan.lender, loan.amount);
            }
        }
    }

    // Add funds to the compensation pool
    function addFundsToCompensationPool() public payable {
        compensationPoolBalance += msg.value;
    }

    // Compensate a lender from the compensation pool
    // TODO: This is just a placeholder for the sake of the compensation example, need to adapt to our insurance rules
    function compensateLender(uint256 lenderId, uint256 amount) internal {
        LenderManagement.Lender memory lender = lenderManagement.getLender(
            lenderId
        );
        uint256 compensationAmount = (amount * 105) / 100; // Example: 5% bonus as compensation
        require(
            compensationPoolBalance >= compensationAmount,
            "Insufficient funds in compensation pool"
        );

        compensationPoolBalance -= compensationAmount;
        (bool success, ) = lender.addr.call{value: compensationAmount}("");
        require(success, "Compensation transfer failed");
    }

    function changeCommissionRate(uint256 newRate) public {
        require(newRate >= 0 && newRate <= 100, "Invalid commission rate");
        commissionRate = newRate;
    }

    function calculateCommission(
        uint256 amount
    ) internal view returns (uint256) {
        return (amount * commissionRate) / 100;
    }
}
