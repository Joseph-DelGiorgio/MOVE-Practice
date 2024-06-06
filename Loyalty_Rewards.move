module 0x1::loyalty_rewards {

    use sui::coin::{Coin, TreasuryCap, transfer};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::vector;

    struct RewardPoint has key, store {
        id: UID,
        owner: address,
        balance: u64,
    }

    struct Reward {
        id: UID,
        description: String,
        cost: u64,
    }

    struct LoyaltyProgram has key {
        id: UID,
        owner: address,
        rewards: vector::Vector<Reward>,
        issued_points: vector::Vector<RewardPoint>,
    }

    public entry fun init_loyalty_program(ctx: &mut TxContext): LoyaltyProgram {
        let rewards = vector::empty<Reward>();
        let issued_points = vector::empty<RewardPoint>();
        LoyaltyProgram {
            id: object::new<UID>(ctx),
            owner: tx_context::sender(ctx),
            rewards,
            issued_points,
        }
    }

    public entry fun create_reward(
        program: &mut LoyaltyProgram,
        description: String,
        cost: u64,
        ctx: &mut TxContext
    ) {
        let reward = Reward {
            id: object::new<UID>(ctx),
            description,
            cost,
        };
        vector::push_back(&mut program.rewards, reward);
    }

    public entry fun issue_points(
        program: &mut LoyaltyProgram,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let reward_point = RewardPoint {
            id: object::new<UID>(ctx),
            owner: to,
            balance: amount,
        };
        vector::push_back(&mut program.issued_points, reward_point);
    }

    public entry fun redeem_points(
        program: &mut LoyaltyProgram,
        reward_id: u64,
        points_id: u64,
        ctx: &mut TxContext
    ) {
        let reward_index = find_reward(&program.rewards, reward_id);
        let reward = &vector::borrow(&program.rewards, reward_index);

        let points_index = find_points(&program.issued_points, points_id);
        let reward_point = &mut vector::borrow_mut(&mut program.issued_points, points_index);

        assert!(reward_point.owner == tx_context::sender(ctx), 0);
        assert!(reward_point.balance >= reward.cost, 0);

        reward_point.balance -= reward.cost;
    }

    fun find_reward(rewards: &vector::Vector<Reward>, reward_id: u64): u64 {
        let len = vector::length(rewards);
        let mut i = 0;
        while (i < len) {
            let reward = &vector::borrow(rewards, i);
            if (reward.id == reward_id) {
                return i;
            }
            i = i + 1;
        }
        assert!(false, 0); // Reward not found
        0 // Default return to satisfy the function signature, will never reach here due to assert
    }

    fun find_points(points: &vector::Vector<RewardPoint>, points_id: u64): u64 {
        let len = vector::length(points);
        let mut i = 0;
        while (i < len) {
            let point = &vector::borrow(points, i);
            if (point.id == points_id) {
                return i;
            }
            i = i + 1;
        }
        assert!(false, 0); // Points not found
        0 // Default return to satisfy the function signature, will never reach here due to assert
    }

    public fun get_rewards(program: &LoyaltyProgram): &vector::Vector<Reward> {
        &program.rewards
    }

    public fun get_points(program: &LoyaltyProgram, owner: address): vector::Vector<RewardPoint> {
        let mut owner_points = vector::empty<RewardPoint>();
        let points = &program.issued_points;
        let len = vector::length(points);
        let mut i = 0;
        while (i < len) {
            let point = &vector::borrow(points, i);
            if (point.owner == owner) {
                vector::push_back(&mut owner_points, *point);
            }
            i = i + 1;
        }
        owner_points
    }
}
