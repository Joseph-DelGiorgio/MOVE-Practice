module airdrop::advanced_airdrop {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use sui::event;

    // Error codes
    const EInsufficientBalance: u64 = 0;
    const EAirdropNotStarted: u64 = 1;
    const EAirdropEnded: u64 = 2;
    const EAlreadyClaimed: u64 = 3;

    struct AirdropPool<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        start_time: u64,
        end_time: u64,
        claims: Table<address, bool>,
    }

    struct AirdropCap has key {
        id: UID,
    }

    struct AirdropEvent has copy, drop {
        recipient: address,
        amount: u64,
    }

    public fun initialize<T>(
        coin: Coin<T>,
        start_time: u64,
        end_time: u64,
        ctx: &mut TxContext
    ) {
        let balance = coin::into_balance(coin);
        let pool = AirdropPool<T> {
            id: object::new(ctx),
            balance,
            start_time,
            end_time,
            claims: table::new(ctx),
        };
        let cap = AirdropCap {
            id: object::new(ctx),
        };
        transfer::share_object(pool);
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    public entry fun claim<T>(
        pool: &mut AirdropPool<T>,
        clock: &Clock,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        assert!(current_time >= pool.start_time, EAirdropNotStarted);
        assert!(current_time <= pool.end_time, EAirdropEnded);
        assert!(!table::contains(&pool.claims, sender), EAlreadyClaimed);
        assert!(balance::value(&pool.balance) >= amount, EInsufficientBalance);

        let coin = coin::take(&mut pool.balance, amount, ctx);
        transfer::transfer(coin, sender);
        table::add(&mut pool.claims, sender, true);

        event::emit(AirdropEvent { recipient: sender, amount });
    }

    public entry fun batch_airdrop<T>(
        _: &AirdropCap,
        pool: &mut AirdropPool<T>,
        recipients: vector<address>,
        amounts: vector<u64>,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&recipients) == vector::length(&amounts), 0);
        let i = 0;
        while (i < vector::length(&recipients)) {
            let recipient = *vector::borrow(&recipients, i);
            let amount = *vector::borrow(&amounts, i);
            if (balance::value(&pool.balance) >= amount) {
                let coin = coin::take(&mut pool.balance, amount, ctx);
                transfer::transfer(coin, recipient);
                event::emit(AirdropEvent { recipient, amount });
            };
            i = i + 1;
        }
    }

    public entry fun extend_airdrop<T>(
        _: &AirdropCap,
        pool: &mut AirdropPool<T>,
        new_end_time: u64
    ) {
        assert!(new_end_time > pool.end_time, 0);
        pool.end_time = new_end_time;
    }

    public entry fun add_funds<T>(
        _: &AirdropCap,
        pool: &mut AirdropPool<T>,
        coin: Coin<T>
    ) {
        let added_balance = coin::into_balance(coin);
        balance::join(&mut pool.balance, added_balance);
    }

    public fun is_claimed<T>(pool: &AirdropPool<T>, addr: address): bool {
        table::contains(&pool.claims, addr)
    }

    public fun get_pool_balance<T>(pool: &AirdropPool<T>): u64 {
        balance::value(&pool.balance)
    }
}
