module SkyTrade::air_rights {
    use std::signer;
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::account;

    /// Struct representing an Air Rights Parcel
    struct AirRightsParcel has key, store {
        id: u64,
        owner: address,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
        is_listed: bool,
    }

    /// Resource holding all air rights for a particular account
    struct AirRightsRegistry has key {
        next_id: u64,
        parcels: vector<AirRightsParcel>,
        created_events: event::EventHandle<AirRightsCreatedEvent>,
        transferred_events: event::EventHandle<AirRightsTransferredEvent>,
        listed_events: event::EventHandle<AirRightsListedEvent>,
        delisted_events: event::EventHandle<AirRightsDelistedEvent>,
    }

    /// Events for logging
    struct AirRightsCreatedEvent has drop, store {
        parcel_id: u64,
        owner: address,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
    }

    struct AirRightsTransferredEvent has drop, store {
        from: address,
        to: address,
        parcel_id: u64,
    }

    struct AirRightsListedEvent has drop, store {
        owner: address,
        parcel_id: u64,
        price_per_cubic_foot: u64,
    }

    struct AirRightsDelistedEvent has drop, store {
        owner: address,
        parcel_id: u64,
    }

    /// Initialize the contract for the caller account
    public fun initialize(account: &signer) {
        let registry = AirRightsRegistry {
            next_id: 0,
            parcels: vector::empty(),
            created_events: account::new_event_handle<AirRightsCreatedEvent>(account),
            transferred_events: account::new_event_handle<AirRightsTransferredEvent>(account),
            listed_events: account::new_event_handle<AirRightsListedEvent>(account),
            delisted_events: account::new_event_handle<AirRightsDelistedEvent>(account),
        };
        move_to(account, registry);
    }

    /// Create a new air rights parcel
    public entry fun create_air_rights(account: &signer, cubic_feet: u64, price_per_cubic_foot: u64) acquires AirRightsRegistry {
        let account_address = signer::address_of(account);
        let registry = borrow_global_mut<AirRightsRegistry>(account_address);

        assert!(cubic_feet > 0, 2);
        assert!(price_per_cubic_foot > 0, 3);

        let parcel_id = registry.next_id;
        registry.next_id = parcel_id + 1;

        let parcel = AirRightsParcel {
            id: parcel_id,
            owner: account_address,
            cubic_feet,
            price_per_cubic_foot,
            is_listed: false,
        };

        vector::push_back(&mut registry.parcels, parcel);

        event::emit_event(&mut registry.created_events, AirRightsCreatedEvent {
            parcel_id,
            owner: account_address,
            cubic_feet,
            price_per_cubic_foot,
        });
    }

    /// Transfer ownership of an air rights parcel
    public entry fun transfer_air_rights(from: &signer, to: address, parcel_id: u64) acquires AirRightsRegistry {
        let from_address = signer::address_of(from);
        let registry = borrow_global_mut<AirRightsRegistry>(from_address);

        let index = get_parcel_index(&registry.parcels, parcel_id);
        let parcel = vector::borrow_mut(&mut registry.parcels, index);

        assert!(parcel.owner == from_address, 4);
        assert!(!parcel.is_listed, 5);  // Ensure the parcel is not listed for sale

        parcel.owner = to;

        event::emit_event(&mut registry.transferred_events, AirRightsTransferredEvent {
            from: from_address,
            to,
            parcel_id,
        });
    }

    /// List an air rights parcel for sale
    public entry fun list_air_rights(account: &signer, parcel_id: u64, price_per_cubic_foot: u64) acquires AirRightsRegistry {
        let account_address = signer::address_of(account);
        let registry = borrow_global_mut<AirRightsRegistry>(account_address);

        let index = get_parcel_index(&registry.parcels, parcel_id);
        let parcel = vector::borrow_mut(&mut registry.parcels, index);

        assert!(parcel.owner == account_address, 6);
        assert!(price_per_cubic_foot > 0, 7);

        parcel.is_listed = true;
        parcel.price_per_cubic_foot = price_per_cubic_foot;

        event::emit_event(&mut registry.listed_events, AirRightsListedEvent {
            owner: account_address,
            parcel_id,
            price_per_cubic_foot,
        });
    }

    /// Delist an air rights parcel
    public entry fun delist_air_rights(account: &signer, parcel_id: u64) acquires AirRightsRegistry {
        let account_address = signer::address_of(account);
        let registry = borrow_global_mut<AirRightsRegistry>(account_address);

        let index = get_parcel_index(&registry.parcels, parcel_id);
        let parcel = vector::borrow_mut(&mut registry.parcels, index);

        assert!(parcel.owner == account_address, 8);
        assert!(parcel.is_listed, 9);

        parcel.is_listed = false;

        event::emit_event(&mut registry.delisted_events, AirRightsDelistedEvent {
            owner: account_address,
            parcel_id,
        });
    }

    fun get_parcel_index(parcels: &vector<AirRightsParcel>, parcel_id: u64): u64 {
        let len = vector::length(parcels);
        let i = 0u64;

        while (i < len) {
            let parcel = vector::borrow(parcels, i);
            if (parcel.id == parcel_id) {
                return i
            };
            i = i + 1;
        };

        abort 10 // Parcel not found
    }
}
