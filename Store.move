module retailer::store {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    struct Item has key, store {
        id: UID,
        name: vector<u8>,
        price: u64,
    }

    struct Store has key {
        id: UID,
        owner: address,
        balance: Coin<SUI>,
    }

    public fun create_store(ctx: &mut TxContext) {
        let store = Store {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            balance: coin::zero(ctx),
        };
        transfer::share_object(store);
    }

    public fun add_item(store: &mut Store, name: vector<u8>, price: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == store.owner, 0);
        let item = Item {
            id: object::new(ctx),
            name,
            price,
        };
        transfer::share_object(item);
    }

    public fun buy_item(store: &mut Store, item: &Item, payment: &mut Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(payment) >= item.price, 1);
        let paid = coin::split(payment, item.price, ctx);
        coin::join(&mut store.balance, paid);
    }

    public fun withdraw(store: &mut Store, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == store.owner, 2);
        let amount = coin::value(&store.balance);
        let withdrawn = coin::split(&mut store.balance, amount, ctx);
        transfer::public_transfer(withdrawn, store.owner);
    }
}
