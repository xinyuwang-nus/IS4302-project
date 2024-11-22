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
    - [6. NFT.sol](#6-nftsol)
    - [7. LoanEasy.sol](#7-loaneasysol)
  - [Usage](#usage)
    - [Deployment](#deployment)
    - [Borrower Action Flow](#borrower-action-flow)
    - [Lender Action Flow](#lender-action-flow)
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
  - Open → Funded → AcceptedLoan → Repayment → Concluded/Defaulted.
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
  - acceptedLoan: *loans in proposal have been accepted by the borrower*
  - awaitingRepayment: *proposal waiting for repayment (after paid out)*
  - late: *proposal repayment deadline reached and funds have not been repaid by borrower*
  - defaulted: *proposal repayment required insurance from platform*
  - concluded: *proposal repaid (borrower or insurance) and concluded*
  - deleted: *proposal has been deleted by borrower*

### 6. NFT.sol
- Implements the ERC-721 standard.
- Upon loan dispersement, the generateReward() function is triggered.
- The number of NFTs for each user can be retrieved through the balanceOf() function.

### 7. LoanEasy.sol
- Central contract for management.


## Usage

### Deployment
1. In Remix, under advanced configurations, enable the Enable Optimization setting. This is needed for the smart contracts to compile.
2. Compile the LoanEasy.sol contract and in the process, the remaining contracts will be compiled.
3. Deploy NFT.sol, LenderManagement.sol, BorrowerManagement.sol, USDT.sol contracts.
4. Deploy the ProposalMarket.sol contract with the address of 
 NFT.sol, LenderManagement.sol, BorrowerManagement.sol, USDT.sol contracts being passed into the constructor of ProposalMarket
5. Deploy the LoanEasy.sol contract with the address of ProposalMarket.sol, LenderManagement.sol and BorrowerManagement.sol
contracts being passed into the constructor of LoanEasy

### Borrower Action Flow
1. **Borrowers** can be added via the **LoanEasy.sol** contract.
2. **Submit Loan Proposal**:
   - Specify loan amount, deadline, etc.
3. **Manage Proposal**:
   - Update details of proposals.
4. **Repay Loans**:
   - Repay borrowed amounts with interest.

### Lender Action Flow
1. **Lenders** can be added via the **LoanEasy.sol** contract.
2. **Evaluate Proposals**:
   - Browse proposals via the **LoanEasy.sol** contract which calls **ProposalMarket.sol**
3. **Fund Proposals**:
   - Partially or fully fund selected proposals.
   - Track funded loans and expected repayments.

## Technologies

- **Ethereum Blockchain**: Platform for smart contracts.
- **Solidity**: Smart contract programming language.
- **ERC-20 Standard**: For creating USDT fungible tokens.
- **ERC-721 Standard**: For creating the NFTs.


## Future Enhancements

- Secondary Market