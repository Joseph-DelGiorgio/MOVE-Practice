module hello_world::msg {
    use std::signer;

    struct Message has key {
        value: vector<u8>
    }

    public entry fun set_message(account: &mut signer, msg: vector<u8>) {
        move_to(&account, Message { value: msg });
    }
}
