module airdrop::simple_airdrop {
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct AirdropCap has key {
        id: UID,
    }

    public fun initialize(ctx: &mut TxContext) {
        let cap = AirdropCap {
            id: object::new(ctx),
        };
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    public entry fun airdrop<T>(
        _: &AirdropCap,
        coin: &mut Coin<T>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let split_coin = coin::split(coin, amount, ctx);
        transfer::transfer(split_coin, recipient);
    }
}
