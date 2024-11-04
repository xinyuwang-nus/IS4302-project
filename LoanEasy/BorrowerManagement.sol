// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BorrowerManagement {
    struct Borrower {
        uint256 id;
        address addr;           // Borrower's Ethereum address
        string name;
        uint256 loanHistory;    // TODO: Define loan history struct
        uint8 creditTier;       // TODO: Define credit tier enum
    }

    uint256 private borrowerCount = 0;
    mapping(uint256 => Borrower) private borrowers;

    // Add a new borrower
    function addBorrower(string memory _name, uint256 _loanHistory, uint8 _creditTier) public {
        borrowerCount++;
        borrowers[borrowerCount] = Borrower(borrowerCount, msg.sender, _name, _loanHistory, _creditTier);
    }

    // Get borrower details
    function getBorrower(uint256 _id) public view returns (Borrower memory) {
        require(_id > 0 && _id <= borrowerCount, "Borrower does not exist");
        return borrowers[_id];
    }

    // Update borrower details
    function updateBorrower(uint256 _id, string memory _name, uint256 _loanHistory, uint8 _creditTier) public {
        require(_id > 0 && _id <= borrowerCount, "Borrower does not exist");
        Borrower storage borrower = borrowers[_id];
        borrower.name = _name;
        borrower.loanHistory = _loanHistory;
        borrower.creditTier = _creditTier;
    }

    // Remove a borrower by ID
    function removeBorrower(uint256 _id) public {
        require(_id > 0 && _id <= borrowerCount, "Borrower does not exist");
        delete borrowers[_id];
    }
}
