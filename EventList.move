module EventList::EventList {
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::signer;

    // Define the structure of an Event
    struct Event has copy, drop, store {
        id: u64,
        description: vector<u8>,
    }

    // Define the EventList structure
    struct EventList has key {
        events: vector<Event>,
        event_handler: event::EventHandle<EventTriggeredEvent>,
    }

    // Define an Event Triggered Event
    struct EventTriggeredEvent has copy, drop, store {
        event_id: u64,
        description: vector<u8>,
    }

    // Initialize the EventList resource in the contract owner's account
    public fun initialize_event_list(account: &signer) {
        let event_list = EventList {
            events: vector::empty<Event>(),
            event_handler: account::new_event_handle<EventTriggeredEvent>(account),
        };
        move_to(account, event_list);
    }

    // Add an event to the EventList
    public fun add_event(account: &signer, id: u64, description: vector<u8>) acquires EventList {
        let event_list = borrow_global_mut<EventList>(signer::address_of(account));
        let new_event = Event { id, description };
        vector::push_back(&mut event_list.events, new_event);
    }

    // Trigger an event by its ID
    public fun trigger_event(account: &signer, id: u64) acquires EventList {
        let event_list = borrow_global_mut<EventList>(signer::address_of(account));
        let event = vector::borrow(&event_list.events, id);
        let trigger_event = EventTriggeredEvent {
            event_id: event.id,
            description: *&event.description,
        };
        event::emit_event(&mut event_list.event_handler, trigger_event);
    }

    // View the event list
    public fun get_events(account: address): vector<Event> acquires EventList {
        let event_list = borrow_global<EventList>(account);
        *&event_list.events
    }
}
