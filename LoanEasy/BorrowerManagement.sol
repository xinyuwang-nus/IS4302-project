// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BorrowerManagement {
    // track all borrowers on platform
    mapping (uint256 => borrower) borrowerList;

    // struct to store borrower details
    struct borrower {
        uint256 userId;
        string name;
        string email;
        bytes32 password;
        string phoneNumber;
        string location;
        address walletAddress;
        uint256[] proposalList; // Storing the list of proposals which borrower has created
        creditTier tier;
        uint256 avgDaysOverDue; // Average number of days overdue for borrower
        uint256 numOfDefaultedLoans; // Number of loans that borrower has defaulted
    }

    // how to calculate credit tier
    enum creditTier {
        gold,
        silver,
        bronze
    }

    // keep track of borrower id
    uint256 private borrowerNum = 0;
    // initialise empty array of proposals which borrower has created
    uint256[] emptyProposalList;

    // check if borrower id is a valid id
    modifier validBorrower(uint256 borrowerId) {
        require(borrowerId < borrowerNum, "Invalid borrower id.");
        _;
    }

    // events for each CRUD function
    // show all attributes except password
    event created_borrower(uint256 borrowerId, string name, string email, string phoneNumber, string location, 
        address walletAddress, uint256[] proposalList, creditTier tier, uint256 avgDaysOverdue, uint256 numOfDefaultedLoans);
    event retrieved_borrower(uint256 borrowerId);
    event updated_borrower(uint256 borrowerId);
    event updated_proposal_list(uint256 borrowerId, uint256[] newProposalList);
    event deleted_borrower(uint256 borrowerId);
    event updated_defaulted_loans(uint256 borrowerId, uint256 numOfLoans);
    event updated_avg_days_overdue(uint256 borrowerId, uint256 avgDaysOverdue);

    // events for admin functionalities
    event tier_edited(uint256 borrowerId, creditTier oldTier, creditTier newTier);

    // add new borrower into list
    function add_borrower(string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location, address walletAddress) public {

        // Checks that borrower provided a valid user name
        require(keccak256(abi.encodePacked(name)) != keccak256(abi.encodePacked("")), "Please enter a non-empty name");
        
        // Checks that borrower provided a valid email
        require(keccak256(abi.encodePacked(email)) != keccak256(abi.encodePacked("")), "Please enter a non-empty email");
        
        // Checks that borrower provided a valid password
        require(keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("")), "Please enter a non-empty password");
        
        // Checks that borrower provided a valid phone number
        require(keccak256(abi.encodePacked(phoneNumber)) != keccak256(abi.encodePacked("")), "Please enter a non-empty phone number");
        
        // Checks that borrower provided a valid location
        require(keccak256(abi.encodePacked(location)) != keccak256(abi.encodePacked("")), "Please enter a non-empty location");

        uint256 borrowerId = borrowerNum++;

        // Storing hashed password instead of normal password for security purposes
        bytes32 hashed_password = keccak256(abi.encodePacked(password));

        borrower memory newBorrower = borrower(
            borrowerId,
            name,
            email,
            hashed_password,
            phoneNumber,
            location,
            walletAddress,
            emptyProposalList,
            creditTier.bronze,
            0,
            0
        );

        // map the newly created borrower to its id in borrowerList
        borrowerList[borrowerId] = newBorrower;

        // emit creation event
        emit created_borrower(newBorrower.userId, newBorrower.name, newBorrower.email, newBorrower.phoneNumber, 
            newBorrower.location, newBorrower.walletAddress, newBorrower.proposalList, newBorrower.tier, newBorrower.avgDaysOverDue,
            newBorrower.numOfDefaultedLoans);
    }

    // get borrower from list
    function get_borrower(uint256 borrowerId) public validBorrower(borrowerId) returns 
        (string memory, string memory, string memory, string memory, address, uint256[] memory, creditTier, uint256, uint256) {
        // retrieve borrower from list
        borrower memory b = borrowerList[borrowerId];

        // emit retrieval event
        emit retrieved_borrower(b.userId);

        // return borrower's details
        return (b.name, b.email, b.phoneNumber, b.location, b.walletAddress, b.proposalList, b.tier, b.avgDaysOverDue, b.numOfDefaultedLoans);
    }

    // update borrower to new attributes
    function update_borrower(uint256 borrowerId, string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location) public validBorrower(borrowerId) {        
        // retrieve borrower from list
        borrower storage b = borrowerList[borrowerId];

        // hash an empty string for string comparison
        bytes32 emptyStringHash = keccak256(abi.encodePacked(""));

        // update to new attributes if there is user input
        if (keccak256(abi.encodePacked(name)) != emptyStringHash) {
            b.name = name;
        }

        if (keccak256(abi.encodePacked(email)) != emptyStringHash) {
            b.email = email;
        }

        if (keccak256(abi.encodePacked(password)) != emptyStringHash) {
            b.password = keccak256(abi.encodePacked(password));
        }

        if (keccak256(abi.encodePacked(phoneNumber)) != emptyStringHash) {
            b.phoneNumber = phoneNumber; // !! error: getting "," as input even though never input anything
        }

        if (keccak256(abi.encodePacked(location)) != emptyStringHash) {
            b.location = location;
        }

        // emit update event
        emit updated_borrower(b.userId);
    }

    // update borrower's proposal list
    function add_proposal(uint256 borrowerId, uint256 proposalId) public validBorrower(borrowerId) {
        // retrieve borrower from list
        borrower storage b = borrowerList[borrowerId];

        // add new proposal into borrower's proposal list array
        borrowerList[borrowerId].proposalList.push(proposalId);

        // emit proposal list updated event
        emit updated_proposal_list(b.userId, b.proposalList);
    }

    // remove borrower from list
    function delete_borrower(uint256 borrowerId) public validBorrower(borrowerId) {
        // remove borrower from mapping
        delete borrowerList[borrowerId];

        // emit deletion event
        emit deleted_borrower(borrowerId);
    }

    // admin edit borrower's tier list
    function update_borrower_tier(uint256 borrowerId, uint256 tierNum) public validBorrower(borrowerId) {
        // retrieve borrower from list
        borrower storage b = borrowerList[borrowerId];
        creditTier oldTier = b.tier;

        // edit credit tier
        if (tierNum == 0) {
            b.tier = creditTier.gold;
        } else if (tierNum == 1) {
            b.tier = creditTier.silver;
        } else if (tierNum == 2) {
            b.tier = creditTier.bronze;
        }

        // emit edit credit tier completed event
        emit tier_edited(b.userId, oldTier, b.tier);
    }

    // get wallet address of borrower 
    function get_owner(uint256 borrowerId) public view returns (address) {
        return borrowerList[borrowerId].walletAddress;
    }

    // get proposal list of borrower
    function get_borrower_proposal_list(uint256 borrowerId) public view validBorrower(borrowerId) returns (uint256[] memory) {
        return borrowerList[borrowerId].proposalList;
    }

    // get tier of borrower
    function get_borrower_tier(uint256 borrowerId) public view validBorrower(borrowerId) returns (creditTier) {
        return borrowerList[borrowerId].tier;
    }

    // update average number of days overdue
    function update_avg_days_overdue(uint256 borrowerId, uint256 numOfDays) public validBorrower(borrowerId) {
        borrower storage b = borrowerList[borrowerId];
        b.avgDaysOverDue = numOfDays;
        
        // Emit event after updating average number of days overdue
        emit updated_avg_days_overdue(borrowerId, numOfDays);
    }

    // get average number of days overdue
    function get_avg_days_overdue(uint256 borrowerId) public view validBorrower(borrowerId) returns (uint256) {
        return borrowerList[borrowerId].avgDaysOverDue;
    }

    // update number of defaulted loans
    function update_defaulted_loans(uint256 borrowerId, uint256 numOfLoans) public validBorrower(borrowerId) {
        borrower storage b = borrowerList[borrowerId];
        b.numOfDefaultedLoans = numOfLoans;
        
        // Emit event after updating number of defaulted loans
        emit updated_defaulted_loans(borrowerId, numOfLoans);
    }

    // get number of defaulted loans
    function get_defaulted_loans(uint256 borrowerId) public view validBorrower(borrowerId) returns (uint256) {
        return borrowerList[borrowerId].numOfDefaultedLoans;
    }


}