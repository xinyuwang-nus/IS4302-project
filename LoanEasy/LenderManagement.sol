// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LenderManagement {
    struct Lender {
        uint256 id;
        address addr;           // Lender's Ethereum address
        string name;
        uint256 amountLoaned;
    }

    uint256 private lenderCount = 0;
    mapping(uint256 => Lender) private lenders;

    // Add a new lender
    function addLender(string memory _name, uint256 _amountLoaned) public {
        lenderCount++;
        lenders[lenderCount] = Lender(lenderCount, msg.sender, _name, _amountLoaned);
    }

    // Get lender details
    function getLender(uint256 _id) public view returns (Lender memory) {
        require(_id > 0 && _id <= lenderCount, "Lender does not exist");
        return lenders[_id];
    }

    // Update lender details
    function updateLender(uint256 _id, string memory _name, uint256 _amountLoaned) public {
        require(_id > 0 && _id <= lenderCount, "Lender does not exist");
        Lender storage lender = lenders[_id];
        lender.name = _name;
        lender.amountLoaned = _amountLoaned;
    }

    // Remove a lender by ID
    function removeLender(uint256 _id) public {
        require(_id > 0 && _id <= lenderCount, "Lender does not exist");
        delete lenders[_id];
    }
}
