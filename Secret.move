module deployer::secret_message {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};

    /// Struct to store the secret message
    struct SecretMessage has key, store {
        id: UID,
        content: String,
        recipient: address
    }

    /// Create a new secret message
    public entry fun create_message(content: vector<u8>, recipient: address, ctx: &mut TxContext) {
        let message = SecretMessage {
            id: object::new(ctx),
            content: string::utf8(content),
            recipient
        };
        transfer::transfer(message, recipient);
    }

    /// Read the content of the message
    public fun read_message(message: &SecretMessage, ctx: &TxContext): String {
        assert!(message.recipient == tx_context::sender(ctx), 0);
        message.content
    }

    /// Destroy the message after reading
    public entry fun destroy_message(message: SecretMessage, ctx: &mut TxContext) {
        assert!(message.recipient == tx_context::sender(ctx), 0);
        let SecretMessage { id, content: _, recipient: _ } = message;
        object::delete(id);
    }
}
