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
