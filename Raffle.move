module RaffleSystem {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::SUI;
    use 0x1::Vector;
    use 0x1::Errors;
    use 0x1::Event;
    use 0x1::Hash;

    struct Raffle {
        id: u64,
        creator: address,
        ticket_price: u64,
        prize_pool: u64,
        participants: vector<address>,
    }

    struct RaffleSystem {
        raffles: vector<Raffle>,
        next_raffle_id: u64,
    }

    event WinnerSelectedEvent {
        raffle_id: u64,
        winner: address,
    }

    public fun new_raffle_system(admin: &signer): address {
        let raffle_system = RaffleSystem {
            raffles: vector::empty(),
            next_raffle_id: 0,
        };
        let raffle_system_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, raffle_system);
        raffle_system_address
    }

    public fun create_raffle(raffle_system_address: address, creator: &signer, ticket_price: u64) {
        let creator_address = Signer::address_of(creator);
        let raffle_system = &mut borrow_global_mut<RaffleSystem>(raffle_system_address);

        let raffle = Raffle {
            id: raffle_system.next_raffle_id,
            creator: creator_address,
            ticket_price,
            prize_pool: 0,
            participants: vector::empty(),
        };

        raffle_system.next_raffle_id += 1;
        vector::push_back(&mut raffle_system.raffles, raffle);
    }

    public fun buy_ticket(raffle_system_address: address, buyer: &signer, raffle_id: u64) {
        let buyer_address = Signer::address_of(buyer);
        let raffle_system = &mut borrow_global_mut<RaffleSystem>(raffle_system_address);
        let raffle = &mut find_raffle_mut(&mut raffle_system.raffles, raffle_id);

        assert!(SUI::balance_of(buyer_address) >= raffle.ticket_price, 1);
        SUI::transfer(buyer, raffle_system_address, raffle.ticket_price);

        raffle.prize_pool += raffle.ticket_price;
        vector::push_back(&mut raffle.participants, buyer_address);
    }

    public fun select_winner(raffle_system_address: address, admin: &signer, raffle_id: u64) {
        let raffle_system = &mut borrow_global_mut<RaffleSystem>(raffle_system_address);
        let raffle = &mut find_raffle_mut(&mut raffle_system.raffles, raffle_id);

        let num_participants = vector::length(&raffle.participants);
        assert!(num_participants > 0, 2);

        let random_index = Hash::random_u64() % num_participants as u64;
        let winner_address = raffle.participants[random_index];

        SUI::transfer(admin, winner_address, raffle.prize_pool);
        raffle.prize_pool = 0;

        Event::emit<WinnerSelectedEvent>(WinnerSelectedEvent {
            raffle_id: raffle_id,
            winner: winner_address,
        });
    }

    public fun get_raffles(raffle_system_address: address): vector<(u64, address, u64, u64, vector<address>)> {
        let raffle_system = borrow_global<RaffleSystem>(raffle_system_address);
        let mut raffle_list: vector<(u64, address, u64, u64, vector<address>)> = vector::empty();

        for raffle in &raffle_system.raffles {
            vector::push_back(
                &mut raffle_list,
                (raffle.id, raffle.creator, raffle.ticket_price, raffle.prize_pool, raffle.participants.clone()),
            );
        }

        raffle_list
    }

    fun find_raffle(raffles: &vector<Raffle>, id: u64): &Raffle {
        let raffle_opt = vector::find(raffles, move |raff| raff.id == id);
        assert!(raffle_opt.is_some(), Errors::not_found(0));
        raffle_opt.borrow().unwrap()
    }

    fun find_raffle_mut(raffles: &mut vector<Raffle>, id: u64): &mut Raffle {
        let raffle_opt = vector::find_mut(raffles, move |raff| raff.id == id);
        assert!(raffle_opt.is_some(), Errors::not_found(0));
        raffle_opt.borrow_mut().unwrap()
    }
}
