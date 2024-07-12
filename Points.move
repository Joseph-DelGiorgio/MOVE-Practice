module loyalty_points::loyalty_program {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // Errors
    const EInsufficientPoints: u64 = 0;

    // Loyalty Program struct
    struct LoyaltyProgram has key {
        id: UID,
        points_balance: Balance<SUI>,
    }

    // User's Loyalty Card
    struct LoyaltyCard has key, store {
        id: UID,
        points: u64,
        owner: address,
    }

    // Events
    struct PointsEarned has copy, drop {
        user: address,
        points: u64,
    }

    struct PointsRedeemed has copy, drop {
        user: address,
        points: u64,
    }

    // Initialize the Loyalty Program
    fun init(ctx: &mut TxContext) {
        let loyalty_program = LoyaltyProgram {
            id: object::new(ctx),
            points_balance: balance::zero(),
        };
        transfer::share_object(loyalty_program);
    }

    // Create a new Loyalty Card for a user
    public entry fun create_loyalty_card(ctx: &mut TxContext) {
        let loyalty_card = LoyaltyCard {
            id: object::new(ctx),
            points: 0,
            owner: tx_context::sender(ctx),
        };
        transfer::transfer(loyalty_card, tx_context::sender(ctx));
    }

    // Earn points
    public entry fun earn_points(
        program: &mut LoyaltyProgram,
        card: &mut LoyaltyCard,
        payment: &mut Coin<SUI>,
        points_to_earn: u64,
        ctx: &mut TxContext
    ) {
        let payment_amount = (points_to_earn as u64) * 100; // 1 point = 100 SUI
        let payment_balance = coin::split(payment, payment_amount, ctx);
        balance::join(&mut program.points_balance, coin::into_balance(payment_balance));
        
        card.points = card.points + points_to_earn;

        sui::event::emit(PointsEarned {
            user: tx_context::sender(ctx),
            points: points_to_earn,
        });
    }

    // Redeem points
    public entry fun redeem_points(
        program: &mut LoyaltyProgram,
        card: &mut LoyaltyCard,
        points_to_redeem: u64,
        ctx: &mut TxContext
    ) {
        assert!(card.points >= points_to_redeem, EInsufficientPoints);
        
        let reward_amount = (points_to_redeem as u64) * 90; // 10% bonus on redemption
        let reward_coin = coin::take(&mut program.points_balance, reward_amount, ctx);
        
        transfer::public_transfer(reward_coin, tx_context::sender(ctx));
        card.points = card.points - points_to_redeem;

        sui::event::emit(PointsRedeemed {
            user: tx_context::sender(ctx),
            points: points_to_redeem,
        });
    }

    // View functions
    public fun get_points(card: &LoyaltyCard): u64 {
        card.points
    }

    public fun get_program_balance(program: &LoyaltyProgram): u64 {
        balance::value(&program.points_balance)
    }
}
