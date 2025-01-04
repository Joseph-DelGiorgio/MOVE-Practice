module virtuals::ai_agent {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use std::string::{Self, String};

    struct AIAgent has key {
        id: UID,
        name: String,
        owner: address,
        traits: Table<String, String>,
        interaction_count: u64,
        value: u64,
    }

    struct Interaction has copy, drop {
        agent_id: ID,
        user: address,
        timestamp: u64,
    }

    const ENotOwner: u64 = 0;
    const EInsufficientPayment: u64 = 1;

    public fun create_agent(name: String, ctx: &mut TxContext) {
        let agent = AIAgent {
            id: object::new(ctx),
            name,
            owner: tx_context::sender(ctx),
            traits: table::new(ctx),
            interaction_count: 0,
            value: 0,
        };
        transfer::transfer(agent, tx_context::sender(ctx));
    }

    public fun add_trait(agent: &mut AIAgent, key: String, value: String, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == agent.owner, ENotOwner);
        table::add(&mut agent.traits, key, value);
    }

    public fun interact_with_agent(agent: &mut AIAgent, payment: &mut Coin<SUI>, ctx: &mut TxContext) {
        let interaction_fee = 1_000_000; // 0.001 SUI
        assert!(coin::value(payment) >= interaction_fee, EInsufficientPayment);

        let paid = coin::split(payment, interaction_fee, ctx);
        transfer::public_transfer(paid, agent.owner);

        agent.interaction_count = agent.interaction_count + 1;
        agent.value = agent.value + interaction_fee;

        event::emit(Interaction {
            agent_id: object::id(agent),
            user: tx_context::sender(ctx),
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun get_agent_info(agent: &AIAgent): (String, address, u64, u64) {
        (agent.name, agent.owner, agent.interaction_count, agent.value)
    }

    public fun get_trait(agent: &AIAgent, key: &String): String {
        *table::borrow(&agent.traits, key)
    }
}
