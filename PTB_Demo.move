module example::ptb_demo {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Counter has key {
        id: UID,
        value: u64,
    }

    public fun create(ctx: &mut TxContext) {
        let counter = Counter {
            id: object::new(ctx),
            value: 0,
        };
        transfer::share_object(counter);
    }

    public fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
    }

    public fun get_value(counter: &Counter): u64 {
        counter.value
    }

    public entry fun ptb_example(counter: &mut Counter, ctx: &mut TxContext) {
        increment(counter);
        let current_value = get_value(counter);
        // Emit an event with the current value
        sui::event::emit(CounterUpdated { value: current_value });
    }

    struct CounterUpdated has copy, drop {
        value: u64,
    }
}
