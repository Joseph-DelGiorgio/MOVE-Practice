module my_first_package::my_module {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct MyObject has key {
        id: UID,
        value: u64,
    }

    public fun create(value: u64, ctx: &mut TxContext) {
        let object = MyObject {
            id: object::new(ctx),
            value,
        };
        transfer::transfer(object, tx_context::sender(ctx));
    }
}
