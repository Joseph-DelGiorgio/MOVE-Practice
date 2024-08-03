module my_addrx::counter {
    use std::signer;

    struct CounterHolder has key {
        count: u64
    }

    public fun init(account: &signer) {
        move_to(account, CounterHolder { count: 0 });
    }

    public fun increment(account: &signer) acquires CounterHolder {
        let counter = borrow_global_mut<CounterHolder>(signer::address_of(account));
        counter.count = counter.count + 1;
    }

    public fun get_count(account: &signer): u64 acquires CounterHolder {
        borrow_global<CounterHolder>(signer::address_of(account)).count
    }
}
