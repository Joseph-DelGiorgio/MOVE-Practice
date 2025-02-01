module example::advanced_ptb_demo {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    // Error codes
    const EInsufficientFunds: u64 = 0;
    const EInvalidIncrement: u64 = 1;

    struct Counter has key {
        id: UID,
        value: u64,
        fee: Balance<SUI>,
        owner: address,
    }

    struct CounterUpdated has copy, drop {
        counter_id: ID,
        old_value: u64,
        new_value: u64,
        updater: address,
    }

    public fun create(fee_amount: u64, ctx: &mut TxContext) {
        let counter = Counter {
            id: object::new(ctx),
            value: 0,
            fee: balance::zero(),
            owner: tx_context::sender(ctx),
        };
        transfer::share_object(counter);
    }

    public fun increment(counter: &mut Counter, payment: &mut Coin<SUI>, amount: u64, ctx: &mut TxContext) {
        assert!(amount > 0, EInvalidIncrement);
        let fee = coin::value(payment);
        assert!(fee >= amount, EInsufficientFunds);

        let old_value = counter.value;
        counter.value = counter.value + amount;

        let paid = coin::split(payment, amount, ctx);
        balance::join(&mut counter.fee, coin::into_balance(paid));

        event::emit(CounterUpdated {
            counter_id: object::id(counter),
            old_value,
            new_value: counter.value,
            updater: tx_context::sender(ctx),
        });
    }

    public fun withdraw_fees(counter: &mut Counter, ctx: &mut TxContext): Coin<SUI> {
        assert!(tx_context::sender(ctx) == counter.owner, 0);
        let amount = balance::value(&counter.fee);
        coin::from_balance(balance::split(&mut counter.fee, amount), ctx)
    }

    public fun get_value(counter: &Counter): u64 {
        counter.value
    }

    public fun get_fee_balance(counter: &Counter): u64 {
        balance::value(&counter.fee)
    }

    public entry fun ptb_example(
        counter: &mut Counter,
        payment: &mut Coin<SUI>,
        increment_amount: u64,
        ctx: &mut TxContext
    ) {
        increment(counter, payment, increment_amount, ctx);
        let current_value = get_value(counter);
        let fee_balance = get_fee_balance(counter);
        
        // Emit an event with the current state
        event::emit(CounterState { 
            value: current_value, 
            fee_balance,
            last_updater: tx_context::sender(ctx)
        });
    }

    struct CounterState has copy, drop {
        value: u64,
        fee_balance: u64,
        last_updater: address,
    }
}

