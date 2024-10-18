// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract DebtFinancing {
    // State variables
    address public owner; // The owner of the contract
    uint public commissionPct; // The fee percentage charged by the platform on successful debt financing, e.g., input 5 for 5%
    uint public projectCount; // Used as ID for project creation
    statsStruct public stats; // Struct to track overall statistics of the platform
    projectStruct[] projects; // Array to store all projects

    mapping(address => projectStruct[]) projectsOf; // Tracks projects created by each user
    mapping(uint => lenderStruct[]) lendersOf; // Tracks lenders for each project by project ID
    mapping(uint => bool) public projectExist; // Boolean to check if a project exists based on its ID

    // Status of a project
    enum statusEnum {
        OPEN, // Project is open for lending
        REVERTED, // Project was not successful, and lenders are refunded
        DELETED, // Project has been deleted, and lenders are refunded
        PAIDOUT // Project has been paid out to its owner
    }

    // Struct to store overall platform stats
    struct statsStruct {
        uint totalProjects; // Total number of active (open) projects
        uint totalLoans; // Total amount of active loans (raised amount), but not yet paid out
    }

    // Struct to represent a lender's information
    struct lenderStruct {
        address owner; // The lender's address
        uint amountLoaned; // The amount loaned by the lender
        uint timestamp; // Time when the loan was made
        bool refunded; // Whether the lender has been refunded if the project was unsuccessful
    }

    // Struct to represent a project
    struct projectStruct {
        uint id; // Unique ID for the project
        address owner; // The creator of the project
        string title;
        string description;
        uint need; // Total loan need for the project
        uint raised; // Amount raised so far
        uint timestamp; // Time when the project was created
        uint expiresAt; // Deadline for the project
        uint lenders; // Number of lenders for the project
        statusEnum status;
    }

    // Modifier to restrict to the contract owner only
    modifier ownerOnly() {
        require(msg.sender == owner, "Owner reserved only");
        _;
    }

    // Event to log actions
    event Action(
        uint256 id,
        string actionType,
        address indexed executor,
        uint256 timestamp
    );

    // Constructor to initialize the contract with a commission percentage
    constructor(uint _commissionPct) {
        owner = msg.sender;
        commissionPct = _commissionPct;
    }

    // Function to create a new project
    function createProject(
        string memory title,
        string memory description,
        uint needInEther, // accept Ether as input
        uint daysUntilExpiration
    ) public returns (bool) {
        // Validate
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(needInEther > 0 ether, "Need must be greater than 0 Ether");

        // Create a new project
        projectStruct memory project;
        project.id = projectCount;
        project.owner = msg.sender;
        project.title = title;
        project.description = description;
        project.need = needInEther * 1 ether; // Convert Ether to Wei
        project.timestamp = block.timestamp;
        project.expiresAt = block.timestamp + (daysUntilExpiration * 1 days); // Add days in seconds

        // Add the project to the array and mappings
        projects.push(project);
        projectExist[projectCount] = true;
        projectsOf[msg.sender].push(project);
        stats.totalProjects += 1;

        emit Action(
            projectCount++,
            "PROJECT CREATED",
            msg.sender,
            block.timestamp
        );
        return true;
    }

    // Function to update an existing project's details
    function updateProject(
        uint id,
        string memory title,
        string memory description,
        uint daysUntilExpiration
    ) public returns (bool) {
        // Validate
        require(msg.sender == projects[id].owner, "Unauthorized Entity");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(
            daysUntilExpiration > 0,
            "Expiration period must be greater than 0 days"
        );

        // Update the project details
        projects[id].title = title;
        projects[id].description = description;
        projects[id].expiresAt =
            block.timestamp +
            (daysUntilExpiration * 1 days); // Add days in seconds

        emit Action(id, "PROJECT UPDATED", msg.sender, block.timestamp);

        return true;
    }

    // Function to delete an existing project
    function deleteProject(uint id) public returns (bool) {
        // Validate
        require(
            projects[id].status == statusEnum.OPEN,
            "Project no longer opened"
        );
        require(msg.sender == projects[id].owner, "Unauthorized Entity");

        // Mark the project as deleted and process refunds for lenders
        projects[id].status = statusEnum.DELETED;
        performRefund(id);

        emit Action(id, "PROJECT DELETED", msg.sender, block.timestamp);

        return true;
    }

    // Function for lenders to lend to a project
    function lendToProject(uint id) public payable returns (bool) {
        // Validate
        require(msg.value >= 1 ether, "Ether must be at least 1 Ether");
        require(projectExist[id], "Project not found");
        require(
            projects[id].status == statusEnum.OPEN,
            "Project no longer opened"
        );

        // Ensure the loan does not exceed the goal
        require(
            projects[id].raised + msg.value <= projects[id].need,
            "Loan amount exceeds project goal"
        );

        // Update project stats and lender details
        stats.totalLoans += msg.value;
        projects[id].raised += msg.value;
        projects[id].lenders += 1;

        lendersOf[id].push(
            lenderStruct(msg.sender, msg.value, block.timestamp, false)
        );

        emit Action(id, "PROJECT LENT TO", msg.sender, block.timestamp);

        // If the goal is met, pay out the project
        if (projects[id].raised >= projects[id].need) {
            performPayout(id);
            return true;
        }

        // If the deadline has passed without meeting the loan goal, revert the project
        if (block.timestamp >= projects[id].expiresAt) {
            projects[id].status = statusEnum.REVERTED;
            performRefund(id);
            return true;
        }

        return true;
    }

    // Function to change the commission fee percentage for the platform
    function changeCommission(uint _commissionPct) public ownerOnly {
        commissionPct = _commissionPct;
    }

    // Function to get a specific project by its ID
    function getProject(uint id) public view returns (projectStruct memory) {
        require(projectExist[id], "Project not found");
        return projects[id];
    }

    // Function to get a list of all projects
    function getProjects() public view returns (projectStruct[] memory) {
        return projects;
    }

    // Function to get the list of lenders for a specific project by its ID
    function getLenders(uint id) public view returns (lenderStruct[] memory) {
        return lendersOf[id];
    }

    // Internal function to process refunds to all lenders of a failed or deleted project
    function performRefund(uint id) internal {
        for (uint i = 0; i < lendersOf[id].length; i++) {
            address _owner = lendersOf[id][i].owner;
            uint amount = lendersOf[id][i].amountLoaned;

            lendersOf[id][i].refunded = true;
            lendersOf[id][i].timestamp = block.timestamp;
            payTo(_owner, amount);

            stats.totalLoans -= amount;
        }
    }

    // Internal function to process the payout to the project owner and platform commission
    function performPayout(uint id) internal {
        uint raised = projects[id].raised;
        uint fee = (raised * commissionPct) / 100;

        projects[id].status = statusEnum.PAIDOUT;

        // Pay the project owner the raised amount minus the platform's commission
        payTo(projects[id].owner, (raised - fee));
        // Pay the platform owner the commission fee
        payTo(owner, fee);

        stats.totalProjects -= 1;
        stats.totalLoans -= raised;

        emit Action(id, "PROJECT PAID OUT", msg.sender, block.timestamp);
    }

    // Internal function to send ether to an address
    function payTo(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success);
    }
}