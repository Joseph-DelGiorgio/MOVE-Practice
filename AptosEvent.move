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


