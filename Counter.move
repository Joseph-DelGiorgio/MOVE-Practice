module counter_package::counter {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// A shared counter object
    struct Counter has key {
        id: UID,
        value: u64,
    }

    /// Create and share a Counter object
    fun init(ctx: &mut TxContext) {
        let counter = Counter {
            id: object::new(ctx),
            value: 0,
        };
        transfer::share_object(counter);
    }

    /// Increment the counter
    public entry fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
    }

    /// Get the counter's value
    public fun value(counter: &Counter): u64 {
        counter.value
    }
}
