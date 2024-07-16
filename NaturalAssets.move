/* 
Tokenized Natural Assets: Ecosystems like forests, coral reefs, or wetlands can be tokenized, allowing fractional ownership and investment in conservation.
Conservation Fund: A portion (10%) of each token purchase goes into a conservation fund, which is used to finance conservation efforts.
Asset Health Scoring: Each natural asset has a health score that is regularly updated by authorized stewards, providing transparency on the state of the ecosystem.
Conservation Tasks: Stewards can create conservation tasks with rewards. When completed, these tasks improve the asset's health score and reward the completer from the conservation fund.
Limited Supply: Each asset has a fixed number of tokens, reflecting the finite nature of natural resources.
Authorized Stewards: A group of authorized stewards oversee the assets, update health scores, and create conservation tasks, ensuring expert management.
Transparent Assessment: The last assessment timestamp is recorded, ensuring regular monitoring of the asset's health.
Event Emissions: Key actions emit events for off-chain tracking and transparency.

This system creates a unique blend of financial investment and environmental conservation, incentivizing token holders to support and monitor the health of natural assets. It could be further expanded with features like:

Quarterly dividends based on asset health improvements
Integration with IoT devices for automated health score updates
A governance system allowing token holders to vote on conservation priorities
Carbon credit generation based on asset health improvements 
*/

module natural_asset_market::ecosystem_tokens {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::dynamic_field as df;
    use std::string::{Self, String};
    use std::vector;

    // Errors
    const EInsufficientFunds: u64 = 0;
    const EAssetNotFound: u64 = 1;
    const EUnauthorized: u64 = 2;
    const EInvalidAmount: u64 = 3;

    // Structs
    struct Market has key {
        id: UID,
        assets: Table<ID, NaturalAsset>,
        conservation_fund: Coin<SUI>,
        stewards: vector<address>,
    }

    struct NaturalAsset has key, store {
        id: UID,
        name: String,
        location: String,
        asset_type: String,
        total_tokens: u64,
        available_tokens: u64,
        price_per_token: u64,
        health_score: u64,
        last_assessment: u64,
    }

    struct AssetToken has key, store {
        id: UID,
        asset_id: ID,
        amount: u64,
        owner: address,
    }

    struct ConservationTask has key, store {
        id: UID,
        asset_id: ID,
        description: String,
        reward: u64,
        completed: bool,
    }

    // Events
    struct AssetTokenized has copy, drop {
        asset_id: ID,
        name: String,
        total_tokens: u64,
    }

    struct TokensPurchased has copy, drop {
        asset_id: ID,
        buyer: address,
        amount: u64,
    }

    struct AssetHealthUpdated has copy, drop {
        asset_id: ID,
        new_health_score: u64,
    }

    // Initialize the market
    fun init(ctx: &mut TxContext) {
        let market = Market {
            id: object::new(ctx),
            assets: table::new(ctx),
            conservation_fund: coin::zero(ctx),
            stewards: vector::empty(),
        };
        transfer::share_object(market);
    }

    // Tokenize a new natural asset
    public entry fun tokenize_asset(
        market: &mut Market,
        name: vector<u8>,
        location: vector<u8>,
        asset_type: vector<u8>,
        total_tokens: u64,
        price_per_token: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let asset = NaturalAsset {
            id: object::new(ctx),
            name: string::utf8(name),
            location: string::utf8(location),
            asset_type: string::utf8(asset_type),
            total_tokens,
            available_tokens: total_tokens,
            price_per_token,
            health_score: 100, // Initial health score
            last_assessment: clock::timestamp_ms(clock),
        };

        let asset_id = object::id(&asset);
        table::add(&mut market.assets, asset_id, asset);

        event::emit(AssetTokenized {
            asset_id,
            name: string::utf8(name),
            total_tokens,
        });
    }

    // Purchase tokens for a natural asset
    public entry fun purchase_tokens(
        market: &mut Market,
        asset_id: ID,
        amount: u64,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let asset = table::borrow_mut(&mut market.assets, asset_id);
        assert!(asset.available_tokens >= amount, EInvalidAmount);

        let total_cost = amount * asset.price_per_token;
        assert!(coin::value(payment) >= total_cost, EInsufficientFunds);

        // Split payment into purchase amount and conservation fund contribution
        let purchase_payment = coin::split(payment, total_cost, ctx);
        let conservation_contribution = coin::value(&purchase_payment) / 10; // 10% goes to conservation fund
        let conservation_payment = coin::split(&mut purchase_payment, conservation_contribution, ctx);
        
        coin::join(&mut market.conservation_fund, conservation_payment);
        transfer::public_transfer(purchase_payment, tx_context::sender(ctx));

        asset.available_tokens = asset.available_tokens - amount;

        // Create and transfer AssetToken to buyer
        let token = AssetToken {
            id: object::new(ctx),
            asset_id,
            amount,
            owner: tx_context::sender(ctx),
        };
        transfer::transfer(token, tx_context::sender(ctx));

        event::emit(TokensPurchased {
            asset_id,
            buyer: tx_context::sender(ctx),
            amount,
        });
    }

    // Update asset health score (only by authorized stewards)
    public entry fun update_health_score(
        market: &mut Market,
        asset_id: ID,
        new_score: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(vector::contains(&market.stewards, &tx_context::sender(ctx)), EUnauthorized);
        assert!(new_score <= 100, EInvalidAmount);

        let asset = table::borrow_mut(&mut market.assets, asset_id);
        asset.health_score = new_score;
        asset.last_assessment = clock::timestamp_ms(clock);

        event::emit(AssetHealthUpdated {
            asset_id,
            new_health_score: new_score,
        });
    }

    // Create a conservation task
    public entry fun create_conservation_task(
        market: &mut Market,
        asset_id: ID,
        description: vector<u8>,
        reward: u64,
        ctx: &mut TxContext
    ) {
        assert!(vector::contains(&market.stewards, &tx_context::sender(ctx)), EUnauthorized);
        
        let task = ConservationTask {
            id: object::new(ctx),
            asset_id,
            description: string::utf8(description),
            reward,
            completed: false,
        };

        df::add(&mut market.id, object::id(&task), task);
    }

    // Complete a conservation task
    public entry fun complete_conservation_task(
        market: &mut Market,
        task_id: ID,
        ctx: &mut TxContext
    ) {
        let task: &mut ConservationTask = df::borrow_mut(&mut market.id, task_id);
        assert!(!task.completed, EInvalidAmount);

        task.completed = true;

        // Reward the task completer
        let reward = coin::split(&mut market.conservation_fund, task.reward, ctx);
        transfer::public_transfer(reward, tx_context::sender(ctx));

        // Increase asset health score
        let asset = table::borrow_mut(&mut market.assets, task.asset_id);
        asset.health_score = (asset.health_score + 5) % 101; // Increase by 5, max 100
    }

    // View functions
    public fun get_asset_info(market: &Market, asset_id: ID): (String, String, String, u64, u64, u64, u64) {
        let asset = table::borrow(&market.assets, asset_id);
        (
            asset.name,
            asset.location,
            asset.asset_type,
            asset.total_tokens,
            asset.available_tokens,
            asset.price_per_token,
            asset.health_score
        )
    }

    public fun get_conservation_fund_balance(market: &Market): u64 {
        coin::value(&market.conservation_fund)
    }
}
