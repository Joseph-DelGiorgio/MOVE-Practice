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
    use std::string::{Self, String};
    use std::vector;

    // Structs
    struct CustomerProfile has key {
        id: UID,
        email: String,
        name: String,
        dietary_restrictions: vector<String>,
        favorite_orders: Table<String, Order>,
        loyalty_points: u64,
    }

    struct Order has store {
        item_name: String,
        customizations: VecMap<String, String>,
        price: u64,
    }

    struct Restaurant has key {
        id: UID,
        name: String,
        menu: Table<String, u64>, // item name to price
    }

    // Events
    struct ProfileCreated has copy, drop {
        customer_email: String,
    }

    struct OrderPlaced has copy, drop {
        customer_email: String,
        restaurant_name: String,
        item_name: String,
        price: u64,
    }

    // Error codes
    const EProfileAlreadyExists: u64 = 0;
    const EInsufficientPayment: u64 = 1;
    const EItemNotFound: u64 = 2;

    // Functions
    public fun create_profile(email: String, name: String, ctx: &mut TxContext) {
        let profile = CustomerProfile {
            id: object::new(ctx),
            email,
            name,
            dietary_restrictions: vector::empty(),
            favorite_orders: table::new(ctx),
            loyalty_points: 0,
        };
        transfer::transfer(profile, tx_context::sender(ctx));
        event::emit(ProfileCreated { customer_email: email });
    }

    public fun add_dietary_restriction(profile: &mut CustomerProfile, restriction: String) {
        vector::push_back(&mut profile.dietary_restrictions, restriction);
    }

    public fun add_favorite_order(
        profile: &mut CustomerProfile, 
        restaurant_name: String, 
        item_name: String, 
        customizations: VecMap<String, String>,
        price: u64
    ) {
        let order = Order { item_name, customizations, price };
        table::add(&mut profile.favorite_orders, restaurant_name, order);
    }

    public fun place_order(
        profile: &mut CustomerProfile,
        restaurant: &Restaurant,
        item_name: String,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&restaurant.menu, &item_name), EItemNotFound);
        let price = *table::borrow(&restaurant.menu, &item_name);
        assert!(coin::value(payment) >= price, EInsufficientPayment);

        let paid = coin::split(payment, price, ctx);
        transfer::public_transfer(paid, tx_context::sender(ctx)); // Transfer to restaurant owner

        profile.loyalty_points = profile.loyalty_points + (price / 100); // 1 point per $1 spent

        event::emit(OrderPlaced {
            customer_email: profile.email,
            restaurant_name: restaurant.name,
            item_name,
            price,
        });
    }

    public fun get_profile_info(profile: &CustomerProfile): (String, String, vector<String>, u64) {
        (profile.email, profile.name, profile.dietary_restrictions, profile.loyalty_points)
    }

    public fun get_favorite_order(profile: &CustomerProfile, restaurant_name: &String): (String, VecMap<String, String>, u64) {
        let order = table::borrow(&profile.favorite_orders, restaurant_name);
        (order.item_name, order.customizations, order.price)
    }

    // Restaurant functions
    public fun create_restaurant(name: String, ctx: &mut TxContext) {
        let restaurant = Restaurant {
            id: object::new(ctx),
            name,
            menu: table::new(ctx),
        };
        transfer::share_object(restaurant);
    }

    public fun add_menu_item(restaurant: &mut Restaurant, item_name: String, price: u64) {
        table::add(&mut restaurant.menu, item_name, price);
    }
}
