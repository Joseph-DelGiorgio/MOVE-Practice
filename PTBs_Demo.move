module 0x0::PTB_Demo {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::option::{Self, Option};

    struct Position has key, store {
        id: UID,
        amount: u64,
    }

    struct ReferralTicket has store, drop {
        discount: u64,
    }

    struct PTB_DEMO has drop {}

    struct PTBTreasury has key {
        id: UID,
        treasury_cap: TreasuryCap<PTB_DEMO>,
    }

    fun init(witness: PTB_DEMO, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"PTB",
            b"PTB Coin",
            b"Demo coin for PTB",
            option::none(),
            ctx
        );
        transfer::public_transfer(metadata, tx_context::sender(ctx));
        
        let treasury = PTBTreasury {
            id: object::new(ctx),
            treasury_cap,
        };
        transfer::share_object(treasury);
    }

    public fun create_position(ctx: &mut TxContext) {
        let position = Position {
            id: object::new(ctx),
            amount: 0,
        };
        transfer::public_transfer(position, tx_context::sender(ctx));
    }

    public fun unstake(position: &mut Position) {
        position.amount = 0;
    }

    public fun claim_referral_ticket(): ReferralTicket {
        ReferralTicket { discount: 10 }
    }

    public fun borrow_with_referral(
        position: &mut Position,
        ticket: ReferralTicket,
        amount: u64,
        treasury: &mut PTBTreasury,
        ctx: &mut TxContext
    ): Coin<PTB_DEMO> {
        let ReferralTicket { discount: _ } = ticket;
        position.amount = position.amount + amount;
        coin::mint(&mut treasury.treasury_cap, amount, ctx)
    }

    public fun stake(position: &mut Position, amount: u64) {
        position.amount = position.amount + amount;
    }

    public entry fun perform_complex_operation(
        position: &mut Position,
        amount: u64,
        treasury: &mut PTBTreasury,
        ctx: &mut TxContext
    ) {
        unstake(position);
        let ticket = claim_referral_ticket();
        let borrowed_coins = borrow_with_referral(position, ticket, amount, treasury, ctx);
        transfer::public_transfer(borrowed_coins, tx_context::sender(ctx));
        stake(position, amount);
    }
}
