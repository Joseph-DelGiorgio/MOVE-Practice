module sky_trade::air_rights {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};

    // Structs
    struct AirRightsParcel has key, store {
        id: UID,
        owner: address,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
        is_listed: bool,
    }

    struct AirRightsRegistry has key {
        id: UID,
        parcels: Table<u64, AirRightsParcel>,
        next_id: u64,
    }

    // Events
    struct AirRightsCreatedEvent has copy, drop {
        parcel_id: u64,
        owner: address,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
    }

    struct AirRightsTransferredEvent has copy, drop {
        from: address,
        to: address,
        parcel_id: u64,
    }

    struct AirRightsListedEvent has copy, drop {
        owner: address,
        parcel_id: u64,
        price_per_cubic_foot: u64,
    }

    struct AirRightsDelistedEvent has copy, drop {
        owner: address,
        parcel_id: u64,
    }

    // Functions
    fun init(ctx: &mut TxContext) {
        let registry = AirRightsRegistry {
            id: object::new(ctx),
            parcels: table::new(ctx),
            next_id: 0,
        };
        transfer::share_object(registry);
    }

    public entry fun create_air_rights(
        registry: &mut AirRightsRegistry,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
        ctx: &mut TxContext
    ) {
        assert!(cubic_feet > 0, 2);
        assert!(price_per_cubic_foot > 0, 3);

        let parcel_id = registry.next_id;
        registry.next_id = parcel_id + 1;

        let parcel = AirRightsParcel {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            cubic_feet,
            price_per_cubic_foot,
            is_listed: false,
        };

        table::add(&mut registry.parcels, parcel_id, parcel);

        event::emit(AirRightsCreatedEvent {
            parcel_id,
            owner: tx_context::sender(ctx),
            cubic_feet,
            price_per_cubic_foot,
        });
    }

    public entry fun sell_and_transfer_air_rights(
        registry: &mut AirRightsRegistry,
        parcel_id: u64,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let parcel = table::borrow_mut(&mut registry.parcels, parcel_id);
        assert!(parcel.is_listed, 5);

        let expected_price = parcel.cubic_feet * parcel.price_per_cubic_foot;
        assert!(coin::value(payment) == expected_price, 11);

        let seller = parcel.owner;
        let buyer = tx_context::sender(ctx);

        coin::transfer(payment, seller);

        parcel.owner = buyer;
        parcel.is_listed = false;

        event::emit(AirRightsTransferredEvent {
            from: seller,
            to: buyer,
            parcel_id,
        });
    }

    public entry fun list_air_rights(
        registry: &mut AirRightsRegistry,
        parcel_id: u64,
        price_per_cubic_foot: u64,
        ctx: &mut TxContext
    ) {
        let parcel = table::borrow_mut(&mut registry.parcels, parcel_id);
        assert!(parcel.owner == tx_context::sender(ctx), 6);
        assert!(price_per_cubic_foot > 0, 7);

        parcel.is_listed = true;
        parcel.price_per_cubic_foot = price_per_cubic_foot;

        event::emit(AirRightsListedEvent {
            owner: tx_context::sender(ctx),
            parcel_id,
            price_per_cubic_foot,
        });
    }

    public entry fun delist_air_rights(
        registry: &mut AirRightsRegistry,
        parcel_id: u64,
        ctx: &mut TxContext
    ) {
        let parcel = table::borrow_mut(&mut registry.parcels, parcel_id);
        assert!(parcel.owner == tx_context::sender(ctx), 8);
        assert!(parcel.is_listed, 9);

        parcel.is_listed = false;

        event::emit(AirRightsDelistedEvent {
            owner: tx_context::sender(ctx),
            parcel_id,
        });
    }

    // Tests would need to be adjusted for Sui's testing framework
}
