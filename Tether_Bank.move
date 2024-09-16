module my_bank::tether_bank {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};

    // Define the Tether coin type (assuming it's already defined elsewhere)
    struct USDT {}

    // Struct to represent the bank
    struct Bank has key {
        balances: Table<address, u64>,
        deposit_events: event::EventHandle<DepositEvent>,
        withdraw_events: event::EventHandle<WithdrawEvent>,
    }

    // Event emitted when a deposit is made
    struct DepositEvent has drop, store {
        user: address,
        amount: u64,
    }

    // Event emitted when a withdrawal is made
    struct WithdrawEvent has drop, store {
        user: address,
        amount: u64,
    }

    // Initialize the bank
    public fun initialize(account: &signer) {
        let bank = Bank {
            balances: table::new(),
            deposit_events: event::new_event_handle<DepositEvent>(account),
            withdraw_events: event::new_event_handle<WithdrawEvent>(account),
        };
        move_to(account, bank);
    }

    // Deposit USDT into the bank
    public entry fun deposit(account: &signer, amount: u64) acquires Bank {
        let addr = signer::address_of(account);
        let bank = borrow_global_mut<Bank>(@my_bank);
        
        // Transfer USDT from user to the bank
        let coins = coin::withdraw<USDT>(account, amount);
        coin::deposit(@my_bank, coins);

        // Update user's balance
        if (!table::contains(&bank.balances, addr)) {
            table::add(&mut bank.balances, addr, amount);
        } else {
            let balance = table::borrow_mut(&mut bank.balances, addr);
            *balance = *balance + amount;
        }

        // Emit deposit event
        event::emit_event(&mut bank.deposit_events, DepositEvent { user: addr, amount });
    }

    // Withdraw USDT from the bank
    public entry fun withdraw(account: &signer, amount: u64) acquires Bank {
        let addr = signer::address_of(account);
        let bank = borrow_global_mut<Bank>(@my_bank);
        
        // Ensure user has sufficient balance
        assert!(table::contains(&bank.balances, addr), 1); // Error code 1: Account not found
        let balance = table::borrow_mut(&mut bank.balances, addr);
        assert!(*balance >= amount, 2); // Error code 2: Insufficient balance

        // Update user's balance
        *balance = *balance - amount;

        // Transfer USDT from bank to user
        let coins = coin::withdraw<USDT>(&@my_bank, amount);
        coin::deposit(addr, coins);

        // Emit withdraw event
        event::emit_event(&mut bank.withdraw_events, WithdrawEvent { user: addr, amount });
    }

    // Get user's balance
    public fun get_balance(addr: address): u64 acquires Bank {
        let bank = borrow_global<Bank>(@my_bank);
        if (table::contains(&bank.balances, addr)) {
            *table::borrow(&bank.balances, addr)
        } else {
            0
        }
    }
}
