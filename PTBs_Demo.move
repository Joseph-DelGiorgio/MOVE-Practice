module example::ptb_demo {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // Struct to represent a user's position
    struct Position has key {
        id: UID,
        amount: u64,
    }

    // Struct to represent a referral ticket (HotPotato)
    struct ReferralTicket has store {
        discount: u64,
    }

    // Function to create a new position
    public fun create_position(ctx: &mut TxContext) {
        let position = Position {
            id: object::new(ctx),
            amount: 0,
        };
        transfer::transfer(position, tx_context::sender(ctx));
    }

    // Function to unstake from boost pool
    public fun unstake(position: &mut Position) {
        // Simulating unstaking logic
        position.amount = 0;
    }

    // Function to claim referral ticket
    public fun claim_referral_ticket(): ReferralTicket {
        ReferralTicket { discount: 10 }
    }

    // Function to borrow with referral
    public fun borrow_with_referral(position: &mut Position, ticket: ReferralTicket, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        // Use the ticket (it will be consumed)
        let ReferralTicket { discount: _ } = ticket;
        
        // Simulating borrowing logic
        position.amount += amount;
        
        // Return borrowed coins
        coin::mint_for_testing(amount, ctx)
    }

    // Function to stake back to boost pool
    public fun stake(position: &mut Position, amount: u64) {
        position.amount += amount;
    }

    // Main entry function demonstrating PTB
    public entry fun perform_complex_operation(
        position: &mut Position,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // 1. Unstake
        unstake(position);

        // 2. Claim referral ticket
        let ticket = claim_referral_ticket();

        // 3-9. Update oracle (simulated)
        // In a real scenario, you would call external oracle functions here

        // 10-15. Update prices (simulated)
        // In a real scenario, you would update prices based on oracle data

        // 16. Borrow with referral
        let borrowed_coins = borrow_with_referral(position, ticket, amount, ctx);

        // 17-18. Transfer borrowed coins
        transfer::public_transfer(borrowed_coins, tx_context::sender(ctx));

        // 19. Stake back
        stake(position, amount);
    }
}
