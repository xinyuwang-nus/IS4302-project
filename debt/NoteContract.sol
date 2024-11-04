pragma solidity ^0.5.0;

contract NoteContract {

    mapping(uint256 => note) note_list; 

    struct note {
        uint256[] lenders; // Stores the list of lenders of note
        uint256 interest_rate; // Interest rate of note
        uint256 commission; // Commission of note
        uint256 expirtyDate; // Expiry date of note
    }

    // Include insurance inside
    function perform_payout() public {

    }
}