// Define a module to store the coin and its functions
module coin::m {
    use sui::coin::{Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{TxContext};

    // Struct to store the coin
    struct MyCoin has drop {}

    // Function to create the coin and its TreasuryCap
    fun init(ctx: &mut TxContext) {
        let (treasury_cap, metadata) = TreasuryCap::create(&MyCoin {}, 0, ctx);
        transfer::share_object(metadata);
    }

    // Function to mint new coins
    public fun mint(treasury_cap: &mut TreasuryCap<MyCoin>, amount: u64, ctx: &mut TxContext) {
        TreasuryCap::mint(treasury_cap, amount, ctx);
    }

    // Function to transfer coins between addresses
    public fun transfer(coin: Coin<MyCoin>, recipient: &mut TxContext) {
        transfer::transfer(coin, recipient);
    }
}
