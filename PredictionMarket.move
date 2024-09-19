module prediction_market::market {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::timestamp;

    struct Market has key {
        id: u64,
        question: vector<u8>,
        end_time: u64,
        yes_pool: u64,
        no_pool: u64,
        resolved: bool,
        outcome: bool,
    }

    struct UserPosition has key {
        market_id: u64,
        yes_amount: u64,
        no_amount: u64,
    }

    public fun create_market(creator: &signer, question: vector<u8>, duration: u64) {
        let market = Market {
            id: get_next_market_id(),
            question: question,
            end_time: timestamp::now_seconds() + duration,
            yes_pool: 0,
            no_pool: 0,
            resolved: false,
            outcome: false,
        };
        move_to(creator, market);
    }

    public fun place_bet(user: &signer, market_id: u64, is_yes: bool, amount: u64) acquires Market, UserPosition {
        let market = borrow_global_mut<Market>(market_id);
        assert!(!market.resolved, 1); // Market not resolved
        assert!(timestamp::now_seconds() < market.end_time, 2); // Market still open

        if (is_yes) {
            market.yes_pool = market.yes_pool + amount;
        } else {
            market.no_pool = market.no_pool + amount;
        }

        // Update user position
        if (!exists<UserPosition>(signer::address_of(user))) {
            move_to(user, UserPosition { market_id, yes_amount: 0, no_amount: 0 });
        }
        let position = borrow_global_mut<UserPosition>(signer::address_of(user));
        if (is_yes) {
            position.yes_amount = position.yes_amount + amount;
        } else {
            position.no_amount = position.no_amount + amount;
        }

        // Transfer tokens from user to market
        coin::transfer<AptosCoin>(user, @prediction_market, amount);
    }

    public fun resolve_market(resolver: &signer, market_id: u64, outcome: bool) acquires Market {
        let market = borrow_global_mut<Market>(market_id);
        assert!(!market.resolved, 3); // Market not already resolved
        assert!(timestamp::now_seconds() >= market.end_time, 4); // Market ended

        market.resolved = true;
        market.outcome = outcome;
    }

    public fun claim_winnings(user: &signer, market_id: u64) acquires Market, UserPosition {
        let market = borrow_global<Market>(market_id);
        assert!(market.resolved, 5); // Market must be resolved

        let position = borrow_global<UserPosition>(signer::address_of(user));
        assert!(position.market_id == market_id, 6); // User has position in this market

        let winnings = if (market.outcome) {
            (position.yes_amount * (market.yes_pool + market.no_pool)) / market.yes_pool
        } else {
            (position.no_amount * (market.yes_pool + market.no_pool)) / market.no_pool
        };

        // Transfer winnings to user
        coin::transfer<AptosCoin>(@prediction_market, signer::address_of(user), winnings);

        // Clean up user position
        move_from<UserPosition>(signer::address_of(user));
    }

    // Helper functions and other necessary logic...
}
