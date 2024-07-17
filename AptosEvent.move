//Aptos Event vs Solidity Event

//Solidity:

event MessageAdded(string message);

function addMessage(string memory message_) external {
    emit MessageAdded(message_);
}

struct MessageAdded has store, drop {
  message: String,
}

public entry fun add_message(message: String) {
    /// ...

    event::emit(AddedMessage { message });
}

//errors

//Errors in solidity:

function onlyOwner() external {
    require(msg.sender == address(1), "Contract: not owner");

    /* ... */
}

//Errors in Move:
use std::error;
use std::signer;

const ENOT_OWNER: u64 = 1;

entry public fun only_owner(owner: &signer) {
assert!(signer::address_of(owner) == @0x1, error::permission_denied(ENOT_OWNER)
/*... */
 
