module 0xYourAddress::casino {

    use std::signer;
    use std::error;
    use std::random;
    use std::event;
    use std::vector;

    const MIN_BET: u64 = 1;

    /// Event to log bet details
    struct BetEvent has key, store {
        player: address,
        amount: u64,
        result: bool,
    }

    /// Struct to hold the state of the casino
    struct Casino has key {
        owner: address,
        funds: u64,
    }

    /// Initialize the casino with the owner and initial funds
    public fun init(owner: &signer, initial_funds: u64): address {
        let casino = Casino {
            owner: signer::address_of(owner),
            funds: initial_funds,
        };
        let casino_address = object::create(&casino);
        casino_address
    }

    /// Place a bet
    public fun place_bet(casino: &mut Casino, player: &signer, amount: u64): bool {
        // Ensure the bet is at least the minimum bet amount
        if (amount < MIN_BET) {
            error::abort(0); // Abort if bet amount is too low
        }

        // Generate a random number
        let random_value = random::rand();
        let win = random_value % 2 == 0;

        // Process the bet result
        if (win) {
            // Player wins, casino pays out
            if (casino.funds < amount) {
                error::abort(1); // Abort if casino cannot cover the bet
            }
            casino.funds = casino.funds - amount;
            let player_address = signer::address_of(player);
            object::transfer(amount, player_address);
        } else {
            // Player loses, casino takes the bet
            casino.funds = casino.funds + amount;
        }

        // Emit event
        event::emit(&BetEvent {
            player: signer::address_of(player),
            amount,
            result: win,
        });

        win
    }

    /// Check the funds of the casino
    public fun check_funds(casino: &Casino): u64 {
        casino.funds
    }

    /// Withdraw funds from the casino
    public fun withdraw(casino: &mut Casino, owner: &signer, amount: u64) {
        // Ensure only the owner can withdraw
        let owner_address = signer::address_of(owner);
        assert!(owner_address == casino.owner, 2);

        // Ensure sufficient funds
        if (casino.funds < amount) {
            error::abort(3); // Abort if insufficient funds
        }

        casino.funds = casino.funds - amount;
        object::transfer(amount, owner_address);
    }
}
