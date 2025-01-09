module retailer::advanced_store {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::event;

    // Structs
    struct Item has key, store {
        id: UID,
        name: vector<u8>,
        price: u64,
        quantity: u64,
        category: vector<u8>,
    }

    struct Store has key {
        id: UID,
        owner: address,
        balance: Coin<SUI>,
        inventory: Table<vector<u8>, Item>,
        total_sales: u64,
        discount_rate: u64, // Percentage (0-100)
    }

    struct CustomerAccount has key {
        id: UID,
        address: address,
        loyalty_points: u64,
    }

    // Events
    struct ItemAdded has copy, drop {
        name: vector<u8>,
        price: u64,
        quantity: u64,
    }

    struct ItemPurchased has copy, drop {
        name: vector<u8>,
        price: u64,
        quantity: u64,
        buyer: address,
    }

    // Error codes
    const E_NOT_OWNER: u64 = 0;
    const E_INSUFFICIENT_FUNDS: u64 = 1;
    const E_ITEM_NOT_FOUND: u64 = 2;
    const E_INSUFFICIENT_STOCK: u64 = 3;

    // Functions
    public fun create_store(ctx: &mut TxContext) {
        let store = Store {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            balance: coin::zero(ctx),
            inventory: table::new(ctx),
            total_sales: 0,
            discount_rate: 0,
        };
        transfer::share_object(store);
    }

    public fun add_item(
        store: &mut Store,
        name: vector<u8>,
        price: u64,
        quantity: u64,
        category: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == store.owner, E_NOT_OWNER);
        let item = Item {
            id: object::new(ctx),
            name: name,
            price,
            quantity,
            category,
        };
        table::add(&mut store.inventory, name, item);
        event::emit(ItemAdded { name, price, quantity });
    }

    public fun buy_item(
        store: &mut Store,
        item_name: vector<u8>,
        quantity: u64,
        payment: &mut Coin<SUI>,
        customer: &mut CustomerAccount,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&store.inventory, item_name), E_ITEM_NOT_FOUND);
        let item = table::borrow_mut(&mut store.inventory, item_name);
        assert!(item.quantity >= quantity, E_INSUFFICIENT_STOCK);

        let price_per_item = apply_discount(item.price, store.discount_rate);
        let total_price = price_per_item * quantity;
        assert!(coin::value(payment) >= total_price, E_INSUFFICIENT_FUNDS);

        // Process payment
        let paid = coin::split(payment, total_price, ctx);
        coin::join(&mut store.balance, paid);

        // Update inventory
        item.quantity = item.quantity - quantity;
        store.total_sales = store.total_sales + total_price;

        // Update customer loyalty points (1 point per 10 coins spent)
        customer.loyalty_points = customer.loyalty_points + (total_price / 10);

        event::emit(ItemPurchased {
            name: item.name,
            price: price_per_item,
            quantity,
            buyer: customer.address,
        });
    }

    public fun set_discount(store: &mut Store, discount_rate: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == store.owner, E_NOT_OWNER);
        assert!(discount_rate <= 100, 0); // Ensure discount is a valid percentage
        store.discount_rate = discount_rate;
    }

    public fun withdraw(store: &mut Store, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == store.owner, E_NOT_OWNER);
        let amount = coin::value(&store.balance);
        let withdrawn = coin::split(&mut store.balance, amount, ctx);
        transfer::public_transfer(withdrawn, store.owner);
    }

    public fun create_customer_account(ctx: &mut TxContext) {
        let customer = CustomerAccount {
            id: object::new(ctx),
            address: tx_context::sender(ctx),
            loyalty_points: 0,
        };
        transfer::transfer(customer, tx_context::sender(ctx));
    }

    // Helper function to apply discount
    fun apply_discount(price: u64, discount_rate: u64): u64 {
        price - (price * discount_rate / 100)
    }

    // Getter functions for viewing store and item details
    public fun get_item_details(store: &Store, item_name: vector<u8>): (u64, u64, vector<u8>) {
        let item = table::borrow(&store.inventory, item_name);
        (item.price, item.quantity, item.category)
    }

    public fun get_store_stats(store: &Store): (u64, u64) {
        (store.total_sales, store.discount_rate)
    }
}
