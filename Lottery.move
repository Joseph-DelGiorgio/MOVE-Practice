module Lottery {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::SUI;
    use 0x1::Random;

    struct Lottery {
        pot: u64,
        participants: vector<address>,
        max_participants: u64,
    }

    public fun new_lottery(admin: &signer, max_participants: u64): address {
        let admin_address = Signer::address_of(admin);
        let lottery = Lottery {
            pot: 0,
            participants: vector::empty(),
            max_participants,
        };
        let lottery_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, lottery);
        lottery_address
    }

    public fun enter_lottery(lottery_address: address, participant: &signer) {
        let lottery = &mut borrow_global_mut<Lottery>(lottery_address);
        assert!(vector::length(&lottery.participants) < lottery.max_participants, 1);
        
        let participant_address = Signer::address_of(participant);
        vector::push_back(&mut lottery.participants, participant_address);
        
        let amount = 1_000; // Amount of SUI tokens to enter the lottery
        SUI::transfer(participant, lottery_address, amount);
        lottery.pot += amount;

        if (vector::length(&lottery.participants) == lottery.max_participants) {
            let winner = choose_winner(&lottery.participants);
            distribute_pot(lottery, winner);
        }
    }

    fun choose_winner(participants: &vector<address>): address {
        let random_index = Random::u64() % vector::length(participants) as u64;
        *vector::borrow(participants, random_index as usize)
    }

    fun distribute_pot(lottery: &mut Lottery, winner: address) {
        SUI::transfer(Account::new_signer(winner), winner, lottery.pot);
        lottery.pot = 0;
        lottery.participants = vector::empty();
    }

    public fun end_lottery(admin: &signer, lottery_address: address) {
        let admin_address = Signer::address_of(admin);
        let lottery = borrow_global<Lottery>(lottery_address);
        let participants = &lottery.participants;
        
        if (!vector::is_empty(participants)) {
            let winner = choose_winner(participants);
            distribute_pot(&mut lottery, winner);
        }

        move_to(&admin, Lottery { pot: 0, participants: vector::empty(), max_participants: 0 });
    }

    public fun get_lottery_info(lottery_address: address): (u64, vector<address>, u64) {
        let lottery = borrow_global<Lottery>(lottery_address);
        (lottery.pot, lottery.participants, lottery.max_participants)
    }
}
