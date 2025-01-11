module retailer::advanced_retail_system {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self, VecMap};

    // Structs
    struct Item has store {
        name: vector<u8>,
        base_price: u64,
        quantity: u64,
        category: vector<u8>,
        description: vector<u8>,
    }

    struct Store has key {
        id: UID,
        owner: address,
        balance: Balance<SUI>,
        inventory: Table<vector<u8>, Item>,
        total_sales: u64,
        global_discount_rate: u64,
        category_discounts: VecMap<vector<u8>, u64>,
        promotions: Table<vector<u8>, Promotion>,
    }

    struct CustomerAccount has key {
        id: UID,
        address: address,
        loyalty_points: u64,
        tier: u8,
        purchase_history: Table<u64, PurchaseRecord>,
    }

    struct Promotion has store {
        name: vector<u8>,
        discount_rate: u64,
        start_time: u64,
        end_time: u64,
        applicable_items: vector<vector<u8>>,
    }

    struct PurchaseRecord has store {
        timestamp: u64,
        item_name: vector<u8>,
        quantity: u64,
        price_paid: u64,
    }

    // Events
    struct ItemAdded has copy, drop {
        name: vector<u8>,
        base_price: u64,
        quantity: u64,
        category: vector<u8>,
    }

    struct ItemPurchased has copy, drop {
        name: vector<u8>,
        price: u64,
        quantity: u64,
        buyer: address,
    }

    struct PromotionCreated has copy, drop {
        name: vector<u8>,
        discount_rate: u64,
        start_time: u64,
        end_time: u64,
    }

    // Error codes
    const E_NOT_OWNER: u64 = 0;
    const E_INSUFFICIENT_FUNDS: u64 = 1;
    const E_ITEM_NOT_FOUND: u64 = 2;
    const E_INSUFFICIENT_STOCK: u64 = 3;
    const E_INVALID_DISCOUNT: u64 = 4;
    const E_INVALID_PROMOTION: u64 = 5;

    // Constants
    const TIER_1_THRESHOLD: u64 = 1000;
    const TIER_2_THRESHOLD: u64 = 5000;
    const TIER_3_THRESHOLD: u64 = 10000;

    // Functions
    public fun create_store(ctx: &mut TxContext) {
        let store = Store {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            balance: balance::zero(),
            inventory: table::new(ctx),
            total_sales: 0,
            global_discount_rate: 0,
            category_discounts: vec_map::empty(),
            promotions: table::new(ctx),
        };
        transfer::share_object(store);
    }

    public fun add_item(
        store: &mut Store,
        name: vector<u8>,
        base_price: u64,
        quantity: u64,
        category: vector<u8>,
        description: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == store.owner, E_NOT_OWNER);
        let item = Item {
            name: name,
            base_price,
            quantity,
            category,
            description,
        };
        table::add(&mut store.inventory, name, item);
        event::emit(ItemAdded { name, base_price, quantity, category });
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

        let final_price = calculate_final_price(store, item, quantity, customer.tier, clock);
        assert!(coin::value(payment) >= final_price, E_INSUFFICIENT_FUNDS);

        // Process payment
        let paid = coin::split(payment, final_price, ctx);
        balance::join(&mut store.balance, coin::into_balance(paid));

        // Update inventory
        item.quantity = item.quantity - quantity;
        store.total_sales = store.total_sales + final_price;

        // Update customer loyalty points and purchase history
        update_customer_account(customer, item_name, quantity, final_price, clock);

        event::emit(ItemPurchased {
            name: item.name,
            price: final_price / quantity,
            quantity,
            buyer: customer.address,
        });
    }

    public fun create_promotion(
        store: &mut Store,
        name: vector<u8>,
        discount_rate: u64,
        start_time: u64,
        end_time: u64,
        applicable_items: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == store.owner, E_NOT_OWNER);
        assert!(discount_rate <= 100, E_INVALID_DISCOUNT);
        assert!(start_time < end_time, E_INVALID_PROMOTION);

        let promotion = Promotion {
            name: name,
            discount_rate,
            start_time,
            end_time,
            applicable_items,
        };
        table::add(&mut store.promotions, name, promotion);

        event::emit(PromotionCreated { name, discount_rate, start_time, end_time });
    }

    public fun set_category_discount(
        store: &mut Store,
        category: vector<u8>,
        discount_rate: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == store.owner, E_NOT_OWNER);
        assert!(discount_rate <= 100, E_INVALID_DISCOUNT);
        vec_map::insert(&mut store.category_discounts, category, discount_rate);
    }

    public fun withdraw(store: &mut Store, amount: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == store.owner, E_NOT_OWNER);
        assert!(balance::value(&store.balance) >= amount, E_INSUFFICIENT_FUNDS);
        let withdrawn = coin::from_balance(balance::split(&mut store.balance, amount), ctx);
        transfer::public_transfer(withdrawn, store.owner);
    }

    public fun create_customer_account(ctx: &mut TxContext) {
        let customer = CustomerAccount {
            id: object::new(ctx),
            address: tx_context::sender(ctx),
            loyalty_points: 0,
            tier: 0,
            purchase_history: table::new(ctx),
        };
        transfer::transfer(customer, tx_context::sender(ctx));
    }

    // Helper functions
    fun calculate_final_price(
        store: &Store,
        item: &Item,
        quantity: u64,
        customer_tier: u8,
        clock: &Clock
    ): u64 {
        let base_price = item.base_price * quantity;
        let discounted_price = apply_discounts(store, item, base_price, clock);
        apply_tier_discount(discounted_price, customer_tier)
    }

    fun apply_discounts(store: &Store, item: &Item, price: u64, clock: &Clock): u64 {
        let current_time = clock::timestamp_ms(clock);
        let mut final_price = price;

        // Apply global discount
        final_price = final_price - (final_price * store.global_discount_rate / 100);

        // Apply category discount if exists
        if (vec_map::contains(&store.category_discounts, &item.category)) {
            let category_discount = *vec_map::get(&store.category_discounts, &item.category);
            final_price = final_price - (final_price * category_discount / 100);
        }

        // Apply promotion if applicable
        let promotions = &store.promotions;
        let i = 0;
        while (i < table::length(promotions)) {
            let promotion = table::borrow(promotions, table::keys(promotions)[i]);
            if (current_time >= promotion.start_time && current_time <= promotion.end_time) {
                if (vector::contains(&promotion.applicable_items, &item.name)) {
                    final_price = final_price - (final_price * promotion.discount_rate / 100);
                    break;
                }
            };
            i = i + 1;
        };

        final_price
    }

    fun apply_tier_discount(price: u64, tier: u8): u64 {
        price - (price * (tier as u64) * 5 / 100)
    }

    fun update_customer_account(
        customer: &mut CustomerAccount,
        item_name: vector<u8>,
        quantity: u64,
        price_paid: u64,
        clock: &Clock
    ) {
        // Update loyalty points (1 point per coin spent)
        customer.loyalty_points = customer.loyalty_points + price_paid;

        // Update customer tier
        if (customer.loyalty_points >= TIER_3_THRESHOLD) {
            customer.tier = 3;
        } else if (customer.loyalty_points >= TIER_2_THRESHOLD) {
            customer.tier = 2;
        } else if (customer.loyalty_points >= TIER_1_THRESHOLD) {
            customer.tier = 1;
        };

        // Record purchase
        let purchase_id = table::length(&customer.purchase_history);
        let record = PurchaseRecord {
            timestamp: clock::timestamp_ms(clock),
            item_name,
            quantity,
            price_paid,
        };
        table::add(&mut customer.purchase_history, purchase_id, record);
    }

    // Getter functions
    public fun get_item_details(store: &Store, item_name: vector<u8>): (u64, u64, vector<u8>, vector<u8>) {
        let item = table::borrow(&store.inventory, item_name);
        (item.base_price, item.quantity, item.category, item.description)
    }

    public fun get_store_stats(store: &Store): (u64, u64) {
        (store.total_sales, balance::value(&store.balance))
    }

    public fun get_customer_info(customer: &CustomerAccount): (u64, u8) {
        (customer.loyalty_points, customer.tier)
    }
}
