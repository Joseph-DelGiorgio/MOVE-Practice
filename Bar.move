module bar::alcoholic_bar {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use std::string::{Self, String};
    use std::vector;

    // Structs
    struct Bar has key {
        id: UID,
        owner: address,
        inventory: Table<ID, Beverage>,
        license: LiquorLicense,
        sales: u64,
        loyalty_program: Table<address, LoyaltyPoints>,
    }

    struct Beverage has key, store {
        id: UID,
        name: String,
        beverage_type: u8, // 0: Beer, 1: Wine, 2: Spirit
        brand: String,
        abv: u64, // Alcohol by volume, stored as percentage * 100
        price: u64,
        stock: u64,
        expiration: u64,
    }

    struct LiquorLicense has store {
        license_number: String,
        expiration_date: u64,
    }

    struct LoyaltyPoints has store {
        points: u64,
    }

    struct AgeVerification has key {
        id: UID,
        customer: address,
        verified: bool,
        verification_time: u64,
    }

    // Events
    struct DrinkServed has copy, drop {
        beverage_id: ID,
        customer: address,
        price: u64,
        timestamp: u64,
    }

    // Constants
    const BEER: u8 = 0;
    const WINE: u8 = 1;
    const SPIRIT: u8 = 2;

    // Error codes
    const EInsufficientStock: u64 = 0;
    const EInvalidAge: u64 = 1;
    const EInsufficientPayment: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EExpiredLicense: u64 = 4;
    const EExpiredBeverage: u64 = 5;

    // Functions
    public fun create_bar(license_number: String, license_expiration: u64, ctx: &mut TxContext) {
        let bar = Bar {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            inventory: table::new(ctx),
            license: LiquorLicense { license_number, expiration_date: license_expiration },
            sales: 0,
            loyalty_program: table::new(ctx),
        };
        transfer::share_object(bar);
    }

    public fun add_beverage(
        bar: &mut Bar,
        name: String,
        beverage_type: u8,
        brand: String,
        abv: u64,
        price: u64,
        stock: u64,
        expiration: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == bar.owner, EUnauthorized);
        let beverage = Beverage {
            id: object::new(ctx),
            name,
            beverage_type,
            brand,
            abv,
            price,
            stock,
            expiration,
        };
        let beverage_id = object::id(&beverage);
        table::add(&mut bar.inventory, beverage_id, beverage);
    }

    public fun verify_age(customer: address, birth_date: u64, clock: &Clock, ctx: &mut TxContext) {
        let current_time = clock::timestamp_ms(clock);
        let age = (current_time - birth_date) / (1000 * 60 * 60 * 24 * 365);
        let verification = AgeVerification {
            id: object::new(ctx),
            customer,
            verified: age >= 21,
            verification_time: current_time,
        };
        transfer::public_transfer(verification, customer);
    }

    public fun serve_drink(
        bar: &mut Bar,
        beverage_id: ID,
        payment: &mut Coin<SUI>,
        age_verification: &AgeVerification,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(age_verification.verified, EInvalidAge);
        assert!(clock::timestamp_ms(clock) < bar.license.expiration_date, EExpiredLicense);

        let beverage = table::borrow_mut(&mut bar.inventory, beverage_id);
        assert!(beverage.stock > 0, EInsufficientStock);
        assert!(clock::timestamp_ms(clock) < beverage.expiration, EExpiredBeverage);
        assert!(coin::value(payment) >= beverage.price, EInsufficientPayment);

        let price = beverage.price;
        let paid = coin::split(payment, price, ctx);
        transfer::public_transfer(paid, bar.owner);

        beverage.stock = beverage.stock - 1;
        bar.sales = bar.sales + price;

        // Update loyalty points
        let customer = tx_context::sender(ctx);
        if (table::contains(&bar.loyalty_program, customer)) {
            let loyalty = table::borrow_mut(&mut bar.loyalty_program, customer);
            loyalty.points = loyalty.points + 1;
        } else {
            table::add(&mut bar.loyalty_program, customer, LoyaltyPoints { points: 1 });
        }

        event::emit(DrinkServed {
            beverage_id,
            customer,
            price,
            timestamp: clock::timestamp_ms(clock),
        });
    }

    public fun get_beverage_info(bar: &Bar, beverage_id: ID): (String, u8, String, u64, u64, u64) {
        let beverage = table::borrow(&bar.inventory, beverage_id);
        (beverage.name, beverage.beverage_type, beverage.brand, beverage.abv, beverage.price, beverage.stock)
    }

    public fun get_loyalty_points(bar: &Bar, customer: address): u64 {
        if (table::contains(&bar.loyalty_program, customer)) {
            table::borrow(&bar.loyalty_program, customer).points
        } else {
            0
        }
    }

    public fun update_license(bar: &mut Bar, new_expiration: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == bar.owner, EUnauthorized);
        bar.license.expiration_date = new_expiration;
    }

    public fun get_bar_stats(bar: &Bar): (u64, u64) {
        (bar.sales, table::length(&bar.inventory))
    }
}
