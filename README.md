# LoanEasy DeFi Platform

## Table of Contents
- [LoanEasy DeFi Platform](#loaneasy-defi-platform)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
    - [Borrower Features](#borrower-features)
    - [Lender Features](#lender-features)
    - [Loan Features](#loan-features)
  - [Smart Contracts](#smart-contracts)
    - [1. ERC20.sol](#1-erc20sol)
    - [2. USDT.sol](#2-usdtsol)
    - [3. BorrowerManagement.sol](#3-borrowermanagementsol)
    - [4. LenderManagement.sol](#4-lendermanagementsol)
    - [5. ProposalMarket.sol](#5-proposalmarketsol)
    - [6. LoanEasy.sol](#6-loaneasysol)
  - [Usage](#usage)
    - [Deployment](#deployment)
    - [Borrower Workflow](#borrower-workflow)
    - [Lender Workflow](#lender-workflow)
  - [Technologies](#technologies)
  - [Future Enhancements](#future-enhancements)


## Overview
**LoanEasy** is an Ethereum-based decentralized finance (DeFi) platform that brings together borrowers and lenders, offering transparency and security in loan transactions. The system leverages USDT (ERC-20) tokens for all transactions.

The platform offers:
- A system for borrowers to propose loans with defined goals and terms.
- A robust mechanism for lenders to evaluate, fund, and track loans.



## Features

### Borrower Features
- **Registration and Profile Management**: Borrowers can create and manage profiles.
- **Loan Proposals**: Submit proposals specifying loan amount required and deadline.
- **Proposal Lifecycle**:
    - Submit proposals.
    - Track the status of proposals.
    - Successfully fund proposals (partially or fully) / Delete unfunded proposals.

### Lender Features
- **Registration and Profile Management**: Lenders can register and manage loan portfolios.
- **Loan Funding**: Evaluate and fund proposals:
  - Partial funding allowed.
  - Return excess funds if goals are exceeded.
- **Loan Tracking**: Monitor funded proposals and repayment timeline.

### Loan Features
- **Loan lifecycle:**
  - Open → Funded → Verification → Repayment → Concluded/Defaulted.
- **Repayment**: Borrowers repay loans with interest to lenders.
- **Default Management**:
  - Missed deadlines trigger penalties.
  - Insurance mechanisms compensate lenders in case of default.

## Smart Contracts

### 1. ERC20.sol
- Implements the ERC-20 Token Standard for fungible tokens, as stable coins.

### 2. USDT.sol
- A mock USDT token based on ERC-20.
- Used for testing and simulating real-world transactions.

### 3. BorrowerManagement.sol
- Handles borrower registration and management.
- Tracks borrower-specific proposals.
- Credit tiers:
  - gold
  - silver
  - bronze
  
### 4. LenderManagement.sol
- Handles lender registration and management.
- Adds loans to lender profiles and tracks loaned amounts.

### 5. ProposalMarket.sol
- Manages borrower loan proposals.
- Funds proposals partially or fully.
- Tracks proposal statuses:
  - open: *proposal is open for lending*
  - closed: *proposal deadline reached or funding goal reached*
  - pendingVerification: *proposal waiting for verification by lenders before executing paid out*
  - awaitingRepayment: *proposal waiting for repayment (after paid out)*
  - late: *proposal repayment deadline reached and funds have not been repaid by borrower*
  - defaulted: *proposal repayment required insurance from platform*
  - concluded: *proposal repaid (borrower or insurance) and concluded*
  - deleted: *proposal has been deleted by borrower*

### 6. LoanEasy.sol
- Central contract for management.

## Usage

### Deployment
1. Deploy the **ERC20.sol** and **USDT.sol** to establish the token interface.
2. Deploy **BorrowerManagement.sol** and **LenderManagement.sol** to handle profiles.
3. Deploy **ProposalMarket.sol** for managing borrower proposals.
4. Deploy **LoanEasy.sol** as the central management.

### Borrower Workflow
1. **Register** via the **BorrowerManagement.sol** contract.
2. **Submit Loan Proposal**:
   - Specify loan amount, deadline, etc.
3. **Manage Proposal**:
   - Update details of proposals.
4. **Repay Loans**:
   - Repay borrowed amounts with interest.

### Lender Workflow
1. **Register** via the **LenderManagement.sol** contract.
2. **Evaluate Proposals**:
   - Browse proposals using **ProposalMarket.sol**.
3. **Fund Proposals**:
   - Partially or fully fund selected proposals.
   - Track funded loans and expected repayments.

## Technologies

- **Ethereum Blockchain**: Platform for smart contracts.
- **Solidity**: Smart contract programming language.
- **ERC-20 Standard**: For tokenization.


## Future Enhancements

- NFT Integration
- Secondary Market