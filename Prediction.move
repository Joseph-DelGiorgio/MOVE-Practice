module prediction_market::market {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::event;

    // Errors
    const EInvalidOutcome: u64 = 0;
    const EMarketClosed: u64 = 1;
    const EMarketNotResolved: u64 = 2;
    const EInsufficientBalance: u64 = 3;
    const EUnauthorized: u64 = 4;

    // Prediction market struct
    struct PredictionMarket has key {
        id: UID,
        question: String,
        outcomes: vector<String>,
        resolution_time: u64,
        resolved: bool,
        winning_outcome: Option<u64>,
        creator: address,
        oracle: address,
        fee_percentage: u64,
        balances: vector<Balance<SUI>>,
        total_shares: vector<u64>,
    }

    // User's position in the market
    struct Position has key {
        id: UID,
        market_id: ID,
        outcome: u64,
        shares: u64,
    }

    // Events
    struct MarketCreated has copy, drop {
        market_id: ID,
        question: String,
        outcomes: vector<String>,
        resolution_time: u64,
    }

    struct SharesPurchased has copy, drop {
        market_id: ID,
        outcome: u64,
        shares: u64,
        cost: u64,
    }

    struct MarketResolved has copy, drop {
        market_id: ID,
        winning_outcome: u64,
    }

    // Create a new prediction market
    public entry fun create_market(
        question: String,
        outcomes: vector<String>,
        resolution_time: u64,
        oracle: address,
        fee_percentage: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&outcomes) >= 2, EInvalidOutcome);
        assert!(resolution_time > clock::timestamp_ms(clock), EMarketClosed);

        let balances = vector::empty();
        let total_shares = vector::empty();
        let outcomes_count = vector::length(&outcomes);

        while (outcomes_count > 0) {
            vector::push_back(&mut balances, balance::zero<SUI>());
            vector::push_back(&mut total_shares, 0);
            outcomes_count = outcomes_count - 1;
        };

        let market = PredictionMarket {
            id: object::new(ctx),
            question,
            outcomes,
            resolution_time,
            resolved: false,
            winning_outcome: option::none(),
            creator: tx_context::sender(ctx),
            oracle,
            fee_percentage,
            balances,
            total_shares,
        };

        event::emit(MarketCreated {
            market_id: object::id(&market),
            question,
            outcomes,
            resolution_time,
        });

        transfer::share_object(market);
    }

    // Buy shares for a specific outcome
    public entry fun buy_shares(
        market: &mut PredictionMarket,
        outcome: u64,
        amount: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!market.resolved, EMarketClosed);
        assert!(clock::timestamp_ms(clock) < market.resolution_time, EMarketClosed);
        assert!(outcome < vector::length(&market.outcomes), EInvalidOutcome);

        let amount_value = coin::value(&amount);
        let shares = calculate_shares_to_buy(market, outcome, amount_value);

        let balance = vector::borrow_mut(&mut market.balances, outcome);
        coin::put(balance, amount);

        let total_shares = vector::borrow_mut(&mut market.total_shares, outcome);
        *total_shares = *total_shares + shares;

        let position = Position {
            id: object::new(ctx),
            market_id: object::id(market),
            outcome,
            shares,
        };

        event::emit(SharesPurchased {
            market_id: object::id(market),
            outcome,
            shares,
            cost: amount_value,
        });

        transfer::transfer(position, tx_context::sender(ctx));
    }

    // Resolve the market
    public entry fun resolve_market(
        market: &mut PredictionMarket,
        winning_outcome: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == market.oracle, EUnauthorized);
        assert!(clock::timestamp_ms(clock) >= market.resolution_time, EMarketNotResolved);
        assert!(!market.resolved, EMarketClosed);
        assert!(winning_outcome < vector::length(&market.outcomes), EInvalidOutcome);

        market.resolved = true;
        market.winning_outcome = option::some(winning_outcome);

        event::emit(MarketResolved {
            market_id: object::id(market),
            winning_outcome,
        });
    }

    // Claim winnings
    public entry fun claim_winnings(
        market: &mut PredictionMarket,
        position: Position,
        ctx: &mut TxContext
    ) {
        assert!(market.resolved, EMarketNotResolved);
        let winning_outcome = *option::borrow(&market.winning_outcome);
        assert!(position.outcome == winning_outcome, EInvalidOutcome);

        let total_balance = balance::value(vector::borrow(&market.balances, winning_outcome));
        let total_shares = *vector::borrow(&market.total_shares, winning_outcome);
        let winnings = (((position.shares as u128) * (total_balance as u128)) / (total_shares as u128) as u64);

        let fee = (winnings * market.fee_percentage) / 10000;
        let payout = winnings - fee;

        let balance = vector::borrow_mut(&mut market.balances, winning_outcome);
        let coin = coin::take(balance, payout, ctx);

        transfer::transfer(coin, tx_context::sender(ctx));
        transfer::transfer(position, tx_context::sender(ctx));
    }

    // Helper function to calculate shares to buy
    fun calculate_shares_to_buy(market: &PredictionMarket, outcome: u64, amount: u64): u64 {
        let balance = balance::value(vector::borrow(&market.balances, outcome));
        let total_shares = *vector::borrow(&market.total_shares, outcome);

        if (balance == 0 || total_shares == 0) {
            amount
        } else {
            ((amount as u128) * (total_shares as u128) / (balance as u128)) as u64
        }
    }
}
