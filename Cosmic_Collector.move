/*
https://explorer.aptoslabs.com/account/0xb1f4afa3ba948a570499706b00124653cf54627fcdc421de1517d98f2eeb41f8/modules/run/cosmic_collector/transfer_cosmic_object?network=testnet
*/

module cosmic_addr::cosmic_collector {
    use std::string::{String, utf8};
    use std::signer;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // Error codes
    const ENO_COSMIC_OBJECT: u64 = 1;
    const EOBJECT_NOT_OWNED: u64 = 2;

    // Cosmic object types
    const STAR: u8 = 0;
    const PLANET: u8 = 1;
    const ASTEROID: u8 = 2;

    struct CosmicObject has key {
        name: String,
        object_type: u8,
    }

    struct CollectionEvent has drop, store {
        collector: address,
        object_name: String,
    }

    struct CollectorProfile has key {
        collection_events: EventHandle<CollectionEvent>,
    }

    public entry fun initialize_collector(account: &signer) {
        let collector_addr = signer::address_of(account);
        if (!exists<CollectorProfile>(collector_addr)) {
            move_to(account, CollectorProfile {
                collection_events: account::new_event_handle<CollectionEvent>(account),
            });
        };
    }

    public entry fun create_cosmic_object(creator: &signer, name: String, object_type: u8) acquires CollectorProfile {
        let creator_address = signer::address_of(creator);
        let constructor_ref = object::create_object(creator_address);
        let object_signer = object::generate_signer(&constructor_ref);
        
        move_to(&object_signer, CosmicObject {
            name: name,
            object_type,
        });

        let collection_events = &mut borrow_global_mut<CollectorProfile>(creator_address).collection_events;
        event::emit_event(collection_events, CollectionEvent {
            collector: creator_address,
            object_name: name,
        });
    }

    public entry fun transfer_cosmic_object(
        from: &signer,
        to: address,
        object: Object<CosmicObject>
    ) {
        assert!(object::is_owner(object, signer::address_of(from)), EOBJECT_NOT_OWNED);
        object::transfer(from, object, to);
    }

    #[view]
    public fun get_cosmic_object_info(object: Object<CosmicObject>): (String, u8) acquires CosmicObject {
        let cosmic_object = borrow_global<CosmicObject>(object::object_address(&object));
        (cosmic_object.name, cosmic_object.object_type)
    }

    #[view]
    public fun get_object_type_name(object_type: u8): String {
        if (object_type == STAR) {
            utf8(b"Star")
        } else if (object_type == PLANET) {
            utf8(b"Planet")
        } else if (object_type == ASTEROID) {
            utf8(b"Asteroid")
        } else {
            utf8(b"Unknown")
        }
    }
}
