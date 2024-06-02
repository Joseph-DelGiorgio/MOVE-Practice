module 0x123::sui_fren {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string::String;
    use std::vector;
    use sui::event;
    
    struct SuiFren has key {
        id: UID,
        generation: u64,
        birthdate: u64,
        attributes: vector<String>,
        power: u64
    }

    struct CANDY has drop {}

    struct CandyTreasuryCapHolder has key {
        id: UID,
        treasury_cap: TreasuryCap<CANDY>,
    }

    entry fun mint(treasury_cap_holder: &mut CandyTreasuryCapHolder<CANDY>, amount: u64, ctx: &mut TxContext) {
        let treasury_cap = &mut treasury_cap_holder.treasury_cap;
        coin::mint_and_transfer(treasury_cap, 1000, tx_context::sender(ctx), ctx);
    }

    entry fun feed_candies(treasury_cap_holder: &mut CandyTreasuryCapHolder<CANDY>, sui_fren: &mut SuiFren, candies: Coin<CANDY>) {
        let amount = coin::value(&coins);
        sui_fren.power = sui_fren.power + amount;
        let treasury_cap = &mut treasury_cap_holder.treasury_cap;
        coin::burn(treasury_cap, coins);
    }
}


module 0x123::sui_fren {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string::String;
    use std::vector;
    use sui::event;
    
    struct SuiFren has key {
        id: UID,
        generation: u64,
        birthdate: u64,
        attributes: vector<String>,
    }

    struct CANDY has drop {}

    struct CandyTreasuryCapHolder has key {
        id: UID,
        treasury_cap: TreasuryCap<CANDY>,
        metadata: CoinMetadata<CANDY>,
    }

    fun init(otw: CANDY, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            otw,
            9,
            b"CANDY",
            b"SuiFren Candy",
            b"Candies to level up SuiFren"
            option::none(),
            ctx,
        );
        transfer::public_transfer(metadata, tx_context::sender(ctx));

        let treasury_cap_holder = CandyTreasuryCapHolder {
            id: object::new(ctx),
            treasury_cap,
        };
        transfer::share_object(treasury_cap_holder);
    }

    entry fun update_icon_url(holder: &mut CandyTreasuryCapHolder, new_icon_url: String) {
        let metadata = &mut holder.metadata;
        let treasury_cap = &holder.treasury_cap;
        coin::update_icon_url(treasury_cap, metadata, new_icon_url);
    }
}
