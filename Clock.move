use sui::clock;

struct TimeEvent has copy, drop {
    timestamp_ms: u64,
}
    
public entry fun get_time(clock: &Clock) {
    event::emit(TimeEvent { timestamp_ms: clock::timestamp_ms(clock) });
}
