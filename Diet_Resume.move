/*
Diet_Resume.move is designed to manage customer profiles and restaurant interactions in a decentralized restaurant management system. 

Here's a breakdown of its components:

Imports: The contract uses various Sui and standard libraries for object management,
transfers, context handling, data structures, and coin operations.


Structs:
CustomerProfile: Represents a customer's profile with personal info, dietary restrictions, favorite orders, and loyalty points.
Order: Represents a specific order with item name, customizations, and price.
Restaurant: Represents a restaurant with a name and menu (items and prices).


Events:
ProfileCreated: Emitted when a new customer profile is created.
OrderPlaced: Emitted when an order is placed, containing order details.
Error codes: Define specific error scenarios like insufficient payment or item not found.


Functions:
create_profile: Creates a new customer profile and transfers it to the sender.
add_dietary_restriction: Adds a dietary restriction to a customer's profile.
add_favorite_order: Adds a favorite order to a customer's profile for a specific restaurant.
place_order: Processes an order, handles payment, updates loyalty points, and emits an event.
get_profile_info: Retrieves basic information from a customer's profile.
get_favorite_order: Retrieves a customer's favorite order for a specific restaurant.
create_restaurant: Creates a new restaurant object.
add_menu_item: Adds a new item to a restaurant's menu.
This contract provides a foundation for managing customer profiles, favorite orders, 
and restaurant menus in a decentralized manner, utilizing Sui's object-centric model and Move's safety features.
*/


module restaurant_profile::customer_profile {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};

    // Structs
    struct CustomerProfile has key {
        id: UID,
        email: String,
        name: String,
        dietary_restrictions: vector<String>,
        favorite_orders: Table<String, Order>,
        loyalty_points: u64,
        last_order_timestamp: u64,
    }

    struct Order has store {
        item_name: String,
        customizations: VecMap<String, String>,
        price: u64,
        timestamp: u64,
    }

    struct Restaurant has key {
        id: UID,
        name: String,
        menu: Table<String, MenuItem>,
        owner: address,
    }

    struct MenuItem has store {
        price: u64,
        description: String,
        available: bool,
    }

    struct LoyaltyProgram has key {
        id: UID,
        points_per_dollar: u64,
        redemption_rate: u64, // How many points for $1 off
    }

    // Events
    struct ProfileCreated has copy, drop {
        customer_email: String,
        timestamp: u64,
    }

    struct OrderPlaced has copy, drop {
        customer_email: String,
        restaurant_name: String,
        item_name: String,
        price: u64,
        timestamp: u64,
    }

    struct LoyaltyPointsRedeemed has copy, drop {
        customer_email: String,
        points_redeemed: u64,
        discount_amount: u64,
        timestamp: u64,
    }

    // Error codes
    const EProfileAlreadyExists: u64 = 0;
    const EInsufficientPayment: u64 = 1;
    const EItemNotFound: u64 = 2;
    const EItemNotAvailable: u64 = 3;
    const EInsufficientLoyaltyPoints: u64 = 4;
    const EUnauthorized: u64 = 5;

    // Functions
    public fun create_profile(email: String, name: String, clock: &Clock, ctx: &mut TxContext) {
        let profile = CustomerProfile {
            id: object::new(ctx),
            email,
            name,
            dietary_restrictions: vector::empty(),
            favorite_orders: table::new(ctx),
            loyalty_points: 0,
            last_order_timestamp: 0,
        };
        transfer::transfer(profile, tx_context::sender(ctx));
        event::emit(ProfileCreated { 
            customer_email: email,
            timestamp: clock::timestamp_ms(clock),
        });
    }

    public fun add_dietary_restriction(profile: &mut CustomerProfile, restriction: String) {
        if (!vector::contains(&profile.dietary_restrictions, &restriction)) {
            vector::push_back(&mut profile.dietary_restrictions, restriction);
        }
    }

    public fun add_favorite_order(
        profile: &mut CustomerProfile, 
        restaurant_name: String, 
        item_name: String, 
        customizations: VecMap<String, String>,
        price: u64,
        clock: &Clock,
    ) {
        let order = Order { 
            item_name, 
            customizations, 
            price,
            timestamp: clock::timestamp_ms(clock),
        };
        if (table::contains(&profile.favorite_orders, restaurant_name)) {
            *table::borrow_mut(&mut profile.favorite_orders, restaurant_name) = order;
        } else {
            table::add(&mut profile.favorite_orders, restaurant_name, order);
        }
    }

    public fun place_order(
        profile: &mut CustomerProfile,
        restaurant: &Restaurant,
        item_name: String,
        payment: &mut Coin<SUI>,
        loyalty_program: &LoyaltyProgram,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&restaurant.menu, &item_name), EItemNotFound);
        let menu_item = table::borrow(&restaurant.menu, &item_name);
        assert!(menu_item.available, EItemNotAvailable);
        assert!(coin::value(payment) >= menu_item.price, EInsufficientPayment);

        let paid = coin::split(payment, menu_item.price, ctx);
        transfer::public_transfer(paid, restaurant.owner);

        let points_earned = (menu_item.price / 100) * loyalty_program.points_per_dollar;
        profile.loyalty_points = profile.loyalty_points + points_earned;
        profile.last_order_timestamp = clock::timestamp_ms(clock);

        event::emit(OrderPlaced {
            customer_email: profile.email,
            restaurant_name: restaurant.name,
            item_name,
            price: menu_item.price,
            timestamp: clock::timestamp_ms(clock),
        });
    }

    public fun redeem_loyalty_points(
        profile: &mut CustomerProfile,
        points_to_redeem: u64,
        loyalty_program: &LoyaltyProgram,
        clock: &Clock,
    ): u64 {
        assert!(profile.loyalty_points >= points_to_redeem, EInsufficientLoyaltyPoints);
        let discount = (points_to_redeem / loyalty_program.redemption_rate) * 100; // Convert to cents
        profile.loyalty_points = profile.loyalty_points - points_to_redeem;

        event::emit(LoyaltyPointsRedeemed {
            customer_email: profile.email,
            points_redeemed: points_to_redeem,
            discount_amount: discount,
            timestamp: clock::timestamp_ms(clock),
        });

        discount
    }

    public fun get_profile_info(profile: &CustomerProfile): (String, String, vector<String>, u64, u64) {
        (profile.email, profile.name, profile.dietary_restrictions, profile.loyalty_points, profile.last_order_timestamp)
    }

    public fun get_favorite_order(profile: &CustomerProfile, restaurant_name: &String): Option<(String, VecMap<String, String>, u64)> {
        if (table::contains(&profile.favorite_orders, restaurant_name)) {
            let order = table::borrow(&profile.favorite_orders, restaurant_name);
            option::some((order.item_name, order.customizations, order.price))
        } else {
            option::none()
        }
    }

    public fun create_restaurant(name: String, ctx: &mut TxContext) {
        let restaurant = Restaurant {
            id: object::new(ctx),
            name,
            menu: table::new(ctx),
            owner: tx_context::sender(ctx),
        };
        transfer::share_object(restaurant);
    }

    public fun add_menu_item(restaurant: &mut Restaurant, item_name: String, price: u64, description: String, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == restaurant.owner, EUnauthorized);
        let menu_item = MenuItem {
            price,
            description,
            available: true,
        };
        table::add(&mut restaurant.menu, item_name, menu_item);
    }

    public fun update_menu_item_availability(restaurant: &mut Restaurant, item_name: String, available: bool, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == restaurant.owner, EUnauthorized);
        assert!(table::contains(&restaurant.menu, &item_name), EItemNotFound);
        let menu_item = table::borrow_mut(&mut restaurant.menu, &item_name);
        menu_item.available = available;
    }

    public fun create_loyalty_program(points_per_dollar: u64, redemption_rate: u64, ctx: &mut TxContext) {
        let loyalty_program = LoyaltyProgram {
            id: object::new(ctx),
            points_per_dollar,
            redemption_rate,
        };
        transfer::share_object(loyalty_program);
    }
}

