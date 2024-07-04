module kentucky_derby::horse_race {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::event;
    use std::string::{String, utf8};
    use std::vector;

    // Struct to represent a horse
    struct Horse has store {
        name: String,
        number: u8,
        speed: u8,
        position: u64
    }

    // Struct to represent the Kentucky Derby race
    struct KentuckyDerby has key {
        id: UID,
        horses: Table<u8, Horse>,
        race_started: bool,
        race_finished: bool,
        track_length: u64
    }

    // Events
    struct HorseAdded has copy, drop {
        name: String,
        number: u8
    }

    struct RaceStarted has copy, drop {
        timestamp: u64
    }

    struct RaceFinished has copy, drop {
        winner_name: String,
        winner_number: u8,
        finish_time: u64
    }

    // Errors
    const ERaceNotStarted: u64 = 0;
    const ERaceAlreadyStarted: u64 = 1;
    const ERaceFinished: u64 = 2;
    const EHorseAlreadyExists: u64 = 3;

    // Create a new Kentucky Derby race
    public fun create_race(track_length: u64, ctx: &mut TxContext) {
        let race = KentuckyDerby {
            id: object::new(ctx),
            horses: table::new(ctx),
            race_started: false,
            race_finished: false,
            track_length
        };
        transfer::share_object(race);
    }

    // Add a horse to the race
    public fun add_horse(
        race: &mut KentuckyDerby,
        name: vector<u8>,
        number: u8,
        speed: u8,
        ctx: &mut TxContext
    ) {
        assert!(!race.race_started, ERaceAlreadyStarted);
        assert!(!table::contains(&race.horses, &number), EHorseAlreadyExists);
        
        let horse = Horse {
            name: utf8(name),
            number,
            speed,
            position: 0
        };
        table::add(&mut race.horses, number, horse);
        
        event::emit(HorseAdded { name: utf8(name), number });
    }

    // Start the race
    public fun start_race(race: &mut KentuckyDerby, clock: &Clock) {
        assert!(!race.race_started, ERaceAlreadyStarted);
        race.race_started = true;
        event::emit(RaceStarted { timestamp: clock::timestamp_ms(clock) });
    }

    // Simulate the race progress
    public fun progress_race(race: &mut KentuckyDerby, clock: &Clock) {
        assert!(race.race_started, ERaceNotStarted);
        assert!(!race.race_finished, ERaceFinished);

        let numbers = table::keys(&race.horses);
        let i = 0;
        let len = vector::length(&numbers);
        
        while (i < len) {
            let number = *vector::borrow(&numbers, i);
            let horse = table::borrow_mut(&mut race.horses, number);
            horse.position = horse.position + (horse.speed as u64);
            
            if (horse.position >= race.track_length) {
                race.race_finished = true;
                event::emit(RaceFinished {
                    winner_name: horse.name,
                    winner_number: horse.number,
                    finish_time: clock::timestamp_ms(clock)
                });
                break
            };
            i = i + 1;
        };
    }

    // Get the current position of a horse
    public fun get_horse_position(race: &KentuckyDerby, number: u8): u64 {
        let horse = table::borrow(&race.horses, number);
        horse.position
    }

    // Check if the race is finished
    public fun is_race_finished(race: &KentuckyDerby): bool {
        race.race_finished
    }
}

//V2

module KentuckyDerby::HorseRaceBetting {

    use 0x1::Signer;
    use 0x1::Event;
    use 0x1::Vector;
    use 0x1::Coin;

    // Struct to store horse details
    struct Horse has copy, drop, store {
        name: vector<u8>,
        number: u64,
        distance_run: u64,
        finished: bool
    }

    // Struct to store bet details
    struct Bet has copy, drop, store {
        bettor: address,
        horse_number: u64,
        amount: u64
    }

    // Event to signal the start of the race
    struct RaceStarted has copy, drop, store {}

    // Event to signal the end of the race and the winner
    struct RaceFinished has copy, drop, store {
        winner_number: u64
    }

    // Struct to store race state
    struct RaceState has key {
        horses: vector<Horse>,
        race_distance: u64,
        race_in_progress: bool,
        winner_number: u64,
        bets: vector<Bet>
    }

    // Initialize the race with a certain distance
    public fun initialize_race(account: &signer, race_distance: u64): address {
        let race = RaceState {
            horses: Vector::empty<Horse>(),
            race_distance,
            race_in_progress: false,
            winner_number: 0,
            bets: Vector::empty<Bet>()
        };
        let race_address = move_to<RaceState>(account, race);
        race_address
    }

    // Add a horse to the race
    public fun add_horse(account: &signer, race_address: address, name: vector<u8>, number: u64) {
        let race = borrow_global_mut<RaceState>(race_address);
        assert!(!race.race_in_progress, 0, "Race is already in progress");
        let horse = Horse {
            name,
            number,
            distance_run: 0,
            finished: false
        };
        Vector::push_back<Horse>(&mut race.horses, horse);
    }

    // Place a bet on a horse
    public fun place_bet(account: &signer, race_address: address, horse_number: u64, amount: u64) {
        let race = borrow_global_mut<RaceState>(race_address);
        assert!(!race.race_in_progress, 0, "Race is already in progress");
        
        // Transfer the bet amount to the contract
        Coin::burn_from<Coin>(Signer::address_of(account), amount);

        let bet = Bet {
            bettor: Signer::address_of(account),
            horse_number,
            amount
        };
        Vector::push_back<Bet>(&mut race.bets, bet);
    }

    // Start the race
    public fun start_race(account: &signer, race_address: address) {
        let race = borrow_global_mut<RaceState>(race_address);
        assert!(Vector::length(&race.horses) >= 2, 0, "Need at least 2 horses to start the race");
        assert!(!race.race_in_progress, 0, "Race is already in progress");
        
        race.race_in_progress = true;
        Event::emit<RaceStarted>(&RaceStarted {});
        
        simulate_race(race_address);
    }

    // Simulate the race
    fun simulate_race(race_address: address) {
        let race = borrow_global_mut<RaceState>(race_address);
        let winning_distance = race.race_distance;
        
        while (race.race_in_progress) {
            let len = Vector::length(&race.horses);
            let mut i = 0;
            while (i < len) {
                let horse = &mut Vector::borrow_mut<Horse>(&mut race.horses, i);
                if (!horse.finished) {
                    horse.distance_run = horse.distance_run + (Rand::rand() % 100);
                    if (horse.distance_run >= winning_distance) {
                        race.race_in_progress = false;
                        race.winner_number = horse.number;
                        horse.finished = true;
                        Event::emit<RaceFinished>(&RaceFinished {
                            winner_number: horse.number
                        });
                        distribute_rewards(race_address);
                        break;
                    }
                }
                i = i + 1;
            }
        }
    }

    // Distribute rewards to the winning bets
    fun distribute_rewards(race_address: address) {
        let race = borrow_global_mut<RaceState>(race_address);
        let winner_number = race.winner_number;
        let mut total_bets = 0;
        let mut total_winning_bets = 0;

        // Calculate total bet amounts and total winning bet amounts
        let len = Vector::length(&race.bets);
        let mut i = 0;
        while (i < len) {
            let bet = &Vector::borrow<Bet>(&race.bets, i);
            total_bets = total_bets + bet.amount;
            if (bet.horse_number == winner_number) {
                total_winning_bets = total_winning_bets + bet.amount;
            }
            i = i + 1;
        }

        // Distribute rewards to the winners
        i = 0;
        while (i < len) {
            let bet = &Vector::borrow<Bet>(&race.bets, i);
            if (bet.horse_number == winner_number) {
                let reward = (bet.amount * total_bets) / total_winning_bets;
                Coin::mint_to<Coin>(bet.bettor, reward);
            }
            i = i + 1;
        }
    }

    // Get the winner of the race
    public fun get_winner(race_address: address): vector<u8> {
        let race = borrow_global<RaceState>(race_address);
        assert!(!race.race_in_progress, 0, "Race is still in progress");
        let len = Vector::length(&race.horses);
        let mut i = 0;
        while (i < len) {
            let horse = &Vector::borrow<Horse>(&race.horses, i);
            if (horse.number == race.winner_number) {
                return horse.name;
            }
            i = i + 1;
        }
        vector::empty<u8>()
    }
}



