module EventTicketingSystem {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Vector;
    use 0x1::Errors;
    use 0x1::Event;
    use 0x1::String;
    use 0x1::Coin;

    struct Event {
        id: u64,
        organizer: address,
        name: String,
        date: u64,
        location: String,
        ticket_price: u64,
        total_tickets: u64,
        tickets_sold: u64,
    }

    struct Ticket {
        event_id: u64,
        owner: address,
    }

    struct EventTicketingSystem {
        events: vector<Event>,
        tickets: vector<Ticket>,
        next_event_id: u64,
    }

    event EventCreatedEvent {
        event_id: u64,
        organizer: address,
        name: String,
        date: u64,
        location: String,
        ticket_price: u64,
        total_tickets: u64,
    }

    event TicketPurchasedEvent {
        event_id: u64,
        buyer: address,
        ticket_id: u64,
    }

    public fun new_event_ticketing_system(admin: &signer): address {
        let event_ticketing_system = EventTicketingSystem {
            events: vector::empty(),
            tickets: vector::empty(),
            next_event_id: 0,
        };
        let event_ticketing_system_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, event_ticketing_system);
        event_ticketing_system_address
    }

    public fun create_event(event_ticketing_system_address: address, organizer: &signer, name: String, date: u64, location: String, ticket_price: u64, total_tickets: u64) {
        let organizer_address = Signer::address_of(organizer);
        let event_ticketing_system = &mut borrow_global_mut<EventTicketingSystem>(event_ticketing_system_address);

        let event = Event {
            id: event_ticketing_system.next_event_id,
            organizer: organizer_address,
            name,
            date,
            location,
            ticket_price,
            total_tickets,
            tickets_sold: 0,
        };

        event_ticketing_system.next_event_id += 1;
        vector::push_back(&mut event_ticketing_system.events, event);

        Event::emit<EventCreatedEvent>(EventCreatedEvent {
            event_id: event.id,
            organizer: organizer_address,
            name: event.name,
            date: event.date,
            location: event.location,
            ticket_price: event.ticket_price,
            total_tickets: event.total_tickets,
        });
    }

    public fun purchase_ticket(event_ticketing_system_address: address, buyer: &signer, event_id: u64) {
        let buyer_address = Signer::address_of(buyer);
        let event_ticketing_system = &mut borrow_global_mut<EventTicketingSystem>(event_ticketing_system_address);
        let event = &mut find_event_mut(&mut event_ticketing_system.events, event_id);

        assert!(event.tickets_sold < event.total_tickets, Errors::invalid_argument(1));
        assert!(Coin::balance(buyer_address) >= event.ticket_price, Errors::insufficient_balance(0));

        Coin::transfer(&buyer, event.organizer, event.ticket_price);
        event.tickets_sold += 1;

        let ticket = Ticket {
            event_id: event.id,
            owner: buyer_address,
        };

        vector::push_back(&mut event_ticketing_system.tickets, ticket);

        Event::emit<TicketPurchasedEvent>(TicketPurchasedEvent {
            event_id: event.id,
            buyer: buyer_address,
            ticket_id: event.tickets_sold - 1,
        });
    }

    public fun verify_ticket(event_ticketing_system_address: address, event_id: u64, ticket_id: u64): bool {
        let event_ticketing_system = borrow_global<EventTicketingSystem>(event_ticketing_system_address);
        let ticket = &find_ticket(&event_ticketing_system.tickets, event_id, ticket_id);

        ticket.owner == Signer::address_of(ticket.owner)
    }

    fun find_event(events: &vector<Event>, id: u64): &Event {
        let event_opt = vector::find(events, move |event| event.id == id);
        assert!(event_opt.is_some(), Errors::not_found(0));
        event_opt.borrow().unwrap()
    }

    fun find_event_mut(events: &mut vector<Event>, id: u64): &mut Event {
        let event_opt = vector::find_mut(events, move |event| event.id == id);
        assert!(event_opt.is_some(), Errors::not_found(0));
        event_opt.borrow_mut().unwrap()
    }

    fun find_ticket(tickets: &vector<Ticket>, event_id: u64, ticket_id: u64): &Ticket {
        let ticket_opt = vector::find(tickets, move |ticket| ticket.event_id == event_id && ticket_id == ticket_id);
        assert!(ticket_opt.is_some(), Errors::not_found(1));
        ticket_opt.borrow().unwrap()
    }
}
