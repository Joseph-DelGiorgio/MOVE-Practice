module time_capsule_predictions::oracle {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::hash::keccak256;
    use sui::event;
    use std::string::{Self, String};
    use std::vector;

    // Errors
    const EInsufficientStake: u64 = 0;
    const EEventNotFound: u64 = 1;
    const EEventNotDue: u64 = 2;
    const EPredictionAlreadyRevealed: u64 = 3;
    const EIncorrectRevealData: u64 = 4;
    const EUnauthorized: u64 = 5;

    // Structs
    struct PredictionMarket has key {
        id: UID,
        events: Table<ID, FutureEvent>,
        oracle: address,
        stake_requirement: u64,
        reward_pool: Coin<SUI>,
    }

    struct FutureEvent has store {
        id: UID,
        description: String,
        due_time: u64,
        outcome: Option<bool>,
        total_stake: u64,
    }

    struct TimeCapsule has key, store {
        id: UID,
        event_id: ID,
        owner: address,
        prediction_hash: vector<u8>,
        stake: u64,
        revealed: bool,
    }

    // Events
    struct EventCreated has copy, drop {
        event_id: ID,
        description: String,
        due_time: u64,
    }

    struct PredictionMade has copy, drop {
        event_id: ID,
        capsule_id: ID,
        stake: u64,
    }

    struct PredictionRevealed has copy, drop {
        event_id: ID,
        capsule_id: ID,
        prediction: bool,
        correct: bool,
    }

    // Initialize the prediction market
    fun init(ctx: &mut TxContext) {
        let market = PredictionMarket {
            id: object::new(ctx),
            events: table::new(ctx),
            oracle: tx_context::sender(ctx),
            stake_requirement: 100_000_000, // 0.1 SUI
            reward_pool: coin::zero(ctx),
        };
        transfer::share_object(market);
    }

    // Create a new future event
    public entry fun create_event(
        market: &mut PredictionMarket,
        description: vector<u8>,
        due_time: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == market.oracle, EUnauthorized);

        let event = FutureEvent {
            id: object::new(ctx),
            description: string::utf8(description),
            due_time,
            outcome: option::none(),
            total_stake: 0,
        };

        let event_id = object::id(&event);
        table::add(&mut market.events, event_id, event);

        event::emit(EventCreated {
            event_id,
            description: string::utf8(description),
            due_time,
        });
    }

    // Make a prediction
    public entry fun make_prediction(
        market: &mut PredictionMarket,
        event_id: ID,
        prediction_hash: vector<u8>,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let stake = market.stake_requirement;
        assert!(coin::value(payment) >= stake, EInsufficientStake);

        let event = table::borrow_mut(&mut market.events, event_id);
        event.total_stake = event.total_stake + stake;

        let stake_payment = coin::split(payment, stake, ctx);
        coin::join(&mut market.reward_pool, stake_payment);

        let capsule = TimeCapsule {
            id: object::new(ctx),
            event_id,
            owner: tx_context::sender(ctx),
            prediction_hash,
            stake,
            revealed: false,
        };

        let capsule_id = object::id(&capsule);
        transfer::transfer(capsule, tx_context::sender(ctx));

        event::emit(PredictionMade {
            event_id,
            capsule_id,
            stake,
        });
    }

    // Reveal a prediction
    public entry fun reveal_prediction(
        market: &mut PredictionMarket,
        capsule: &mut TimeCapsule,
        prediction: bool,
        salt: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let event = table::borrow(&market.events, capsule.event_id);
        assert!(clock::timestamp_ms(clock) >= event.due_time, EEventNotDue);
        assert!(!capsule.revealed, EPredictionAlreadyRevealed);

        // Verify the revealed prediction matches the hash
        let mut prediction_data = vector::empty();
        vector::append(&mut prediction_data, b"prediction:");
        vector::append(&mut prediction_data, if (prediction) b"true" else b"false");
        vector::append(&mut prediction_data, b",salt:");
        vector::append(&mut prediction_data, salt);
        assert!(keccak256(&prediction_data) == capsule.prediction_hash, EIncorrectRevealData);

        capsule.revealed = true;

        if (option::is_some(&event.outcome)) {
            let correct = prediction == *option::borrow(&event.outcome);
            if (correct) {
                // Calculate reward (simplified)
                let reward = (capsule.stake * 2) - (capsule.stake / 10); // 90% of double stake
                let reward_coin = coin::split(&mut market.reward_pool, reward, ctx);
                transfer::public_transfer(reward_coin, capsule.owner);
            }

            event::emit(PredictionRevealed {
                event_id: capsule.event_id,
                capsule_id: object::id(capsule),
                prediction,
                correct,
            });
        }
    }

    // Oracle sets the outcome of an event
    public entry fun set_event_outcome(
        market: &mut PredictionMarket,
        event_id: ID,
        outcome: bool,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == market.oracle, EUnauthorized);

        let event = table::borrow_mut(&mut market.events, event_id);
        event.outcome = option::some(outcome);
    }

    // View functions
    public fun get_event_info(market: &PredictionMarket, event_id: ID): (String, u64, Option<bool>, u64) {
        let event = table::borrow(&market.events, event_id);
        (event.description, event.due_time, event.outcome, event.total_stake)
    }

    public fun get_market_stats(market: &PredictionMarket): (u64, u64) {
        (market.stake_requirement, coin::value(&market.reward_pool))
    }
}
