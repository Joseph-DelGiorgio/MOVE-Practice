module coffee_shop::loyalty_points {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // Errors
    const EInsufficientPoints: u64 = 0;
    const EInvalidRedemptionAmount: u64 = 1;

    // Constants
    const POINTS_PER_SUI: u64 = 10; // 10 points per 1 SUI spent
    const SUI_PER_POINT: u64 = 100; // 0.01 SUI per point when redeeming

    // Structs
    struct LoyaltyCard has key {
        id: UID,
        points: u64,
        owner: address,
    }

    struct ShopOwner has key {
        id: UID,
    }

    // Functions
    public fun create_loyalty_card(ctx: &mut TxContext) {
        let loyalty_card = LoyaltyCard {
            id: object::new(ctx),
            points: 0,
            owner: tx_context::sender(ctx),
        };
        transfer::transfer(loyalty_card, tx_context::sender(ctx));
    }

    public fun earn_points(card: &mut LoyaltyCard, payment: &Coin<SUI>, ctx: &mut TxContext) {
        let amount = coin::value(payment);
        let points_earned = amount * POINTS_PER_SUI / 100_000_000; // Convert from SUI to points
        card.points = card.points + points_earned;
    }

    public fun redeem_points(
        card: &mut LoyaltyCard, 
        points_to_redeem: u64, 
        shop_owner: &ShopOwner,
        ctx: &mut TxContext
    ) {
        assert!(card.points >= points_to_redeem, EInsufficientPoints);
        assert!(points_to_redeem > 0, EInvalidRedemptionAmount);

        let sui_amount = points_to_redeem * SUI_PER_POINT;
        let redeemed_coin = coin::mint_for_testing(sui_amount, ctx); // In production, use a real mint function

        card.points = card.points - points_to_redeem;
        transfer::transfer(redeemed_coin, card.owner);
    }

    public fun check_balance(card: &LoyaltyCard): u64 {
        card.points
    }

    // Initialize function to create the ShopOwner object
    fun init(ctx: &mut TxContext) {
        transfer::transfer(ShopOwner { id: object::new(ctx) }, tx_context::sender(ctx));
    }
}
