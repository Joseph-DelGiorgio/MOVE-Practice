module scientific_computing::compute_rewards {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use std::vector;

    // Error codes
    const E_INVALID_DIFFICULTY: u64 = 0;
    const E_INVALID_PROOF: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;

    // Constants
    const INITIAL_REWARD: u64 = 1000;
    const DIFFICULTY_ADJUSTMENT_INTERVAL: u64 = 100;
    const TARGET_COMPLETION_TIME: u64 = 600; // 10 minutes

    struct ComputeTask has key {
        id: UID,
        difficulty: u64,
        data_hash: vector<u8>,
        reward: u64,
        completed: bool
    }

    struct NetworkState has key {
        id: UID,
        total_tasks: u64,
        current_difficulty: u64,
        last_adjustment_time: u64,
        treasury: Balance<SUI>,
        tasks_since_adjustment: u64
    }

    struct Proof has copy, drop {
        nonce: u64,
        result_hash: vector<u8>,
        computation_time: u64
    }

    // Initialize the network state
    fun init(ctx: &mut TxContext) {
        let network_state = NetworkState {
            id: object::new(ctx),
            total_tasks: 0,
            current_difficulty: 1,
            last_adjustment_time: 0,
            treasury: balance::zero(),
            tasks_since_adjustment: 0
        };
        transfer::share_object(network_state);
    }

    // Create a new compute task
    public fun create_task(
        state: &mut NetworkState,
        payment: Coin<SUI>,
        data_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let payment_balance = coin::into_balance(payment);
        assert!(balance::value(&payment_balance) >= INITIAL_REWARD, E_INSUFFICIENT_BALANCE);
        
        balance::join(&mut state.treasury, payment_balance);

        let task = ComputeTask {
            id: object::new(ctx),
            difficulty: state.current_difficulty,
            data_hash,
            reward: INITIAL_REWARD,
            completed: false
        };

        state.total_tasks = state.total_tasks + 1;
        transfer::share_object(task);
    }

    // Submit computation proof and claim reward
    public fun submit_proof(
        state: &mut NetworkState,
        task: &mut ComputeTask,
        proof: Proof,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(!task.completed, E_INVALID_PROOF);
        // Verify proof would go here in production
        verify_proof(&proof, task.difficulty, task.data_hash);
        
        task.completed = true;
        state.tasks_since_adjustment = state.tasks_since_adjustment + 1;

        // Adjust difficulty if needed
        if (state.tasks_since_adjustment >= DIFFICULTY_ADJUSTMENT_INTERVAL) {
            adjust_difficulty(state, clock);
        }

        // Calculate and transfer reward
        let reward_amount = calculate_reward(task.difficulty, proof.computation_time);
        assert!(balance::value(&state.treasury) >= reward_amount, E_INSUFFICIENT_BALANCE);
        
        let reward_balance = balance::split(&mut state.treasury, reward_amount);
        coin::from_balance(reward_balance, ctx)
    }

    // Internal function to verify computation proof
    fun verify_proof(proof: &Proof, difficulty: u64, data_hash: vector<u8>) {
        // In production, this would verify:
        // 1. Proof of work meets difficulty requirement
        // 2. Result hash matches expected format
        // 3. Computation time is reasonable
        // For demo purposes, we just check some basic conditions
        assert!(proof.computation_time > 0, E_INVALID_PROOF);
        assert!(vector::length(&proof.result_hash) > 0, E_INVALID_PROOF);
    }

    // Adjust difficulty based on network conditions
    fun adjust_difficulty(state: &mut NetworkState, clock: &Clock) {
        let current_time = clock::timestamp_ms(clock);
        let time_diff = current_time - state.last_adjustment_time;
        
        if (time_diff == 0) return;

        let avg_completion_time = time_diff / state.tasks_since_adjustment;
        
        if (avg_completion_time < TARGET_COMPLETION_TIME) {
            state.current_difficulty = state.current_difficulty + 1;
        } else if (avg_completion_time > TARGET_COMPLETION_TIME && state.current_difficulty > 1) {
            state.current_difficulty = state.current_difficulty - 1;
        };

        state.last_adjustment_time = current_time;
        state.tasks_since_adjustment = 0;
    }

    // Calculate reward based on difficulty and computation time
    fun calculate_reward(difficulty: u64, computation_time: u64): u64 {
        // Basic reward formula: base_reward * difficulty * (1 + computation_time_bonus)
        let base_reward = INITIAL_REWARD;
        let time_bonus = if (computation_time > 0) {
            computation_time / 1000 // Simple bonus based on computation time
        } else {
            0
        };
        
        base_reward * difficulty * (100 + time_bonus) / 100
    }

    #[test]
    fun test_create_task() {
        use sui::test_scenario;
        
        let scenario = test_scenario::begin(@0x1);
        let ctx = test_scenario::ctx(&mut scenario);
        
        // Initialize network state
        init(ctx);
        
        // Create test data
        let data_hash = vector::empty<u8>();
        vector::push_back(&mut data_hash, 1);
        
        // Test task creation
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let state = test_scenario::take_shared<NetworkState>(&scenario);
            let payment = coin::mint_for_testing(INITIAL_REWARD, ctx);
            
            create_task(&mut state, payment, data_hash, ctx);
            assert!(state.total_tasks == 1, 0);
            
            test_scenario::return_shared(state);
        };
        
        test_scenario::end(scenario);
    }
}
