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

   
    entry fun mint(treasury_cap_holder: &mut CandyTreasuryCapHolder<CANDY>, amount: u64, ctx: &mut TxContext) {
        let treasury_cap = &mut treasury_cap_holder.treasury_cap;
        coin::mint_and_transfer(treasury_cap, 1000, tx_context::sender(ctx), ctx);
    }
}











//Coin_vs_Balance.move


//Coin vs Balance - take, put, transfer, zero, destroy_zero

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
    }

    entry fun mint(treasury_cap_holder: &mut CandyTreasuryCapHolder<CANDY>, amount: u64, ctx: &mut TxContext) {
        let treasury_cap = &mut treasury_cap_holder.treasury_cap;
        coin::mint_and_transfer(treasury_cap, 1000, tx_context::sender(ctx), ctx);
    }

    entry fun transfer_half_candies(from: &mut Coin<CANDY>, to: &mut Coin<CANDY>, ctx: &mut TxContext) {
    let half_coins = coin::take(coin::balance_mut(from), coin::balance(from) / 2, ctx);
    coin::put(coin::balance_mut(to), half_coins);
    }
    
}







//BurningCoins.move 

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
