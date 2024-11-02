pragma solidity ^0.5.0;

contract BorrowerManagement {
    // track all borrowers on platform
    mapping (uint256 => borrower) borrowerList;

    // struct to store borrower details
    struct borrower {
        uint256 userId;
        string name;
        string email;
        string password;
        string phoneNumber;
        string location;
        address walletAddress;
        uint256[] loanHistory; // loans to be repaid by borrower, storing loan amount
        creditTier tier;
    }

    // how to calculate credit tier
    enum creditTier {
        gold,
        silver,
        bronze
    }

    // keep track of borrower id
    uint256 public borrowerNum = 0;
    // initialise empty array of loan history for new borrowers
    uint256[] emptyHistory;

    // check if borrower id is a valid id
    modifier validBorrower(uint256 borrowerId) {
        require(borrowerId < borrowerNum, "Invalid borrower id.");
        _;
    }

    // events for each CRUD function
    // show all attributes except password
    event created_borrower(uint256 borrowerId, string name, string email, string phoneNumber, string location, 
        address walletAddress, uint256[] loanHistory, creditTier tier);
    event retrieved_borrower(uint256 borrowerId);
    event updated_borrower(uint256 borrowerId);
    event updated_loan_history(uint256 borrowerId, uint256[] newHistory);
    event deleted_borrower(uint256 borrowerId);

    // events for admin functionalities
    event tier_edited(uint256 borrowerId, creditTier oldTier, creditTier newTier);

    // add new borrower into list
    function add_borrower(string memory name, string memory email, string memory password, 
        string memory phoneNumber, string memory location, address walletAddress) public {

        uint256 borrowerId = borrowerNum++;

        borrower memory newBorrower = borrower(
            borrowerId,
            name,
            email,
            password,
            phoneNumber,
            location,
            walletAddress,
            emptyHistory,
            creditTier.bronze
        );

        // map the newly created borrower to its id in borrowerList
        borrowerList[borrowerId] = newBorrower;

        // emit creation event
        emit created_borrower(newBorrower.userId, newBorrower.name, newBorrower.email, newBorrower.phoneNumber, 
            newBorrower.location, newBorrower.walletAddress, newBorrower.loanHistory, newBorrower.tier);
    }

    // get borrower from list
    function get_borrower(uint256 borrowerId) public payable validBorrower(borrowerId) returns 
        (string memory, string memory, string memory, string memory, address, uint256[] memory, creditTier) {
        // retrieve borrower from list
        borrower memory b = borrowerList[borrowerId];

        // emit retrieval event
        emit retrieved_borrower(b.userId);

        // return borrower's details
        return (b.name, b.email, b.phoneNumber, b.location, b.walletAddress, b.loanHistory, b.tier);
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
            b.password = password;
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

    // update borrower to have new loan history
    function add_loan_history(uint256 borrowerId, uint256 newLoan) public validBorrower(borrowerId) {
        // retrieve borrower from list
        borrower storage b = borrowerList[borrowerId];

        // add new loan into borrower's loan history array
        borrowerList[borrowerId].loanHistory.push(newLoan);

        // emit loan history updated event
        emit updated_loan_history(b.userId, b.loanHistory);
    }

    // remove borrower from list
    function remove_borrower(uint256 borrowerId) public validBorrower(borrowerId) {
        // remove borrower from mapping
        delete borrowerList[borrowerId];

        // emit deletion event
        emit deleted_borrower(borrowerId);
    }

    // admin edit borrower's tier list
    function edit_borrower_tier(uint256 borrowerId, uint256 tierNum) public validBorrower(borrowerId) {
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
}