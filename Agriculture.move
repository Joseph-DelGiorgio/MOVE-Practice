module irrigation_system::smart_irrigation {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::event;

    struct IrrigationSystem has key {
        id: UID,
        owner: address,
        water_balance: u64,
        price_per_unit: u64,
        last_watered: u64,
    }

    struct WateringEvent has copy, drop {
        system_id: ID,
        amount: u64,
        timestamp: u64,
    }

    const E_INSUFFICIENT_WATER: u64 = 0;
    const E_INSUFFICIENT_PAYMENT: u64 = 1;

    public fun create_system(price: u64, ctx: &mut TxContext) {
        let system = IrrigationSystem {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            water_balance: 0,
            price_per_unit: price,
            last_watered: 0,
        };
        transfer::share_object(system);
    }

    public fun add_water(system: &mut IrrigationSystem, amount: u64, clock: &Clock, ctx: &mut TxContext) {
        system.water_balance = system.water_balance + amount;
        system.last_watered = clock::timestamp_ms(clock);
    }

    public fun water_field(
        system: &mut IrrigationSystem,
        amount: u64,
        payment: &mut Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(system.water_balance >= amount, E_INSUFFICIENT_WATER);
        let price = amount * system.price_per_unit;
        assert!(coin::value(payment) >= price, E_INSUFFICIENT_PAYMENT);

        system.water_balance = system.water_balance - amount;
        let paid = coin::split(payment, price, ctx);
        transfer::public_transfer(paid, system.owner);

        system.last_watered = clock::timestamp_ms(clock);

        event::emit(WateringEvent {
            system_id: object::uid_to_inner(&system.id),
            amount,
            timestamp: system.last_watered,
        });
    }

    public fun get_system_info(system: &IrrigationSystem): (u64, u64, u64) {
        (system.water_balance, system.price_per_unit, system.last_watered)
    }
}
