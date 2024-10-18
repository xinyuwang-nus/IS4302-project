# Debt



Definition: Debt financing is the means in which a company raises capital by borrowing money from external lenders or investors. 

## Implemented Features:

- Retrieve list of credit fund requests available in the system
    - Allows backers to view the various projects available which they can back
- Accept credit fund requests (partial or total)
    - Provides backers/lenders with the opportunity to support the project with full financial backing or partial financial backing
    - Allows Company to be supported by one or more lenders/backers
    - Currency which is used for backing of the project is Ether
- Goal: Raising capital for company through loans
    - Request amount is not met by expiration time.
        - loan amounts is returned back to the lenders
    - Request amount is met:
        - Commission fee is deducted and loan amount is released to the company borrowing


## Features **NOT** implemented yet
- **The company will then pay back the lenders the loan with interest.**
- If request amount is not met by expiration time.
  - Company can choose to **accept or decline loans**
  - If accepted, commission fee is deducted and loan amounts is released to the company borrowing
  - If declined, loan amounts is returned back to the lenders
- **Admins can vet and approve credit fund requests**
- **Add liquidity? Use token and trade**
- **How does payback work, collateral? Reputation mechanism**