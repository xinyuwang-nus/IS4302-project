// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LenderManagement {
    // track all lenders on platform
    mapping (uint256 => lender) lender_list;

    // struct to store lender details
    struct lender {
        uint256 lenderId;
        string name;
        string email;
        bytes32 password;
        string phoneNumber;
        string location;
        address walletAddress;
        uint256 totalAmountLoaned;
        uint256[] loanIdList;
    }

    uint256 private lenderNum = 0;
    // Used for initialising empty array of notes id
    uint256[] emptyLoanIdList;

    modifier validLender(uint256 lenderId) {
        require(lenderId < lenderNum, "Please enter a valid lender id");
        _;
    }

    // Events for each CRUD action
    event addLenderEvent(uint256 lenderId, string name, string email, string phoneNumber, 
    string location, address walletAddress, uint256 totalAmountLoaned, uint256[] loansList);
    event getLenderEvent(uint256 lenderId);
    event updateLenderEvent(uint256 lenderId);
    event deleteLenderEvent(uint256 lenderId);
    event updated_loan_list(uint256 lenderId, uint256[] loansList);

    // Add lender
    function add_lender(string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location, address walletAddress) public {
            uint256 lenderId = lenderNum;

            // Checks that lender provided a valid user name
            require(keccak256(abi.encodePacked(name)) != keccak256(abi.encodePacked("")), "Please enter a non-empty name");
            
            // Checks that lender provided a valid email
            require(keccak256(abi.encodePacked(email)) != keccak256(abi.encodePacked("")), "Please enter a non-empty email");
            
            // Checks that lender provided a valid password
            require(keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("")), "Please enter a non-empty password");
            
            // Checks that lender provided a valid phone number
            require(keccak256(abi.encodePacked(phoneNumber)) != keccak256(abi.encodePacked("")), "Please enter a non-empty phone number");
            
            // Checks that lender provided a valid location
            require(keccak256(abi.encodePacked(location)) != keccak256(abi.encodePacked("")), "Please enter a non-empty location");
            
            // Storing hashed password instead of normal password for security purposes
            bytes32 hashed_password = keccak256(abi.encodePacked(password));

            lender memory newLender = lender(
                lenderId,
                name,
                email,
                hashed_password,
                phoneNumber,
                location,
                walletAddress,
                0,
                emptyLoanIdList
                );

            lender_list[lenderId] = newLender;

            emit addLenderEvent(newLender.lenderId, newLender.name, newLender.email, 
            newLender.phoneNumber, newLender.location, newLender.walletAddress, 
            newLender.totalAmountLoaned, newLender.loanIdList);

            lenderNum++;
    }

    // Get Lender
    function get_lender(uint256 lenderId) public validLender(lenderId) returns 
        (string memory, string memory, string memory, string memory, address, uint256, uint256[] memory) {

        lender memory l = lender_list[lenderId];

        emit getLenderEvent(lenderId);

        return (l.name, l.email, l.phoneNumber, l.location, l.walletAddress, l.totalAmountLoaned, l.loanIdList);
    }

    // Get Lender
    function get_lender_address(uint256 lenderId) public validLender(lenderId) returns (address) {

        lender memory l = lender_list[lenderId];

        emit getLenderEvent(lenderId);

        return (l.walletAddress);
    }

    // Update Lender
    function update_lender(uint256 lenderId, string memory name, string memory email, string memory password,
        string memory phoneNumber, string memory location) public validLender(lenderId) {

        lender storage l = lender_list[lenderId];

        if (keccak256(abi.encodePacked(name)) != keccak256(abi.encodePacked(""))) {
            l.name = name;
        }
        if (keccak256(abi.encodePacked(email)) != keccak256(abi.encodePacked(""))) {
            l.email = email;
        }
        if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked(""))) {
            l.password = keccak256(abi.encodePacked(password));
        }
        if (keccak256(abi.encodePacked(phoneNumber)) != keccak256(abi.encodePacked(""))) {
            l.phoneNumber = phoneNumber;
        }
        if (keccak256(abi.encodePacked(location)) != keccak256(abi.encodePacked(""))) {
            l.location = location;
        }

        emit updateLenderEvent(lenderId);
    }

    // Update total amount loaned
    function update_amount_loaned(uint256 amount, uint256 lenderId) public validLender(lenderId) {
        lender_list[lenderId].totalAmountLoaned = amount;
    }

    // Update list of loans id
    // update borrower's proposal list !!!!!!! store proposal id or loan id
    function add_loan(uint256 lenderId, uint256 proposalId) public validLender(lenderId) {
        // retrieve lender from list
        lender storage l = lender_list[lenderId];

        // add new proposal into borrower's proposal list array
        lender_list[lenderId].loanIdList.push(proposalId);

        // emit proposal list updated event
        emit updated_loan_list(l.lenderId, l.loanIdList);
    }


    // Remove Lender
    function remove_lender(uint256 lenderId) public validLender(lenderId) {
        delete lender_list[lenderId];

        emit deleteLenderEvent(lenderId);
    }

    // Get wallet address of lender
    function get_owner(uint256 lenderId) public view validLender(lenderId) returns (address) {
        return lender_list[lenderId].walletAddress;
    }

    // get total loan amount of lender
    function get_amount_loaned(uint256 lenderId) public view validLender(lenderId) returns (uint256) {
        return lender_list[lenderId].totalAmountLoaned;
    }
}