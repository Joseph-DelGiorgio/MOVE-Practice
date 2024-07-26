module natural_assets::advanced_rwa_tokenization {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::string::{String, utf8};
    use std::option::{Self, Option};
    use sui::vec_map::{Self, VecMap};
    use sui::vec_set::{Self, VecSet};

    // Define custom coin types
    struct NAT {} // Natural Asset Token
    struct CCT {} // Carbon Credit Token
    struct USDC {} // Stablecoin for liquidity pools

    // Struct to represent a Natural Asset
    struct NaturalAsset has key, store {
        id: UID,
        asset_type: String,
        name: String,
        location: String,
        area: u64,  // in square kilometers
        token_supply: Balance<NAT>,
        valuation: u64, // in USD
        sustainability_score: u8, // 0-100
        carbon_credits: Balance<CCT>,
        last_audit_timestamp: u64,
        regulatory_compliance: Table<String, bool>,
        metadata: VecMap<String, String>,
        fractional_ownership: Table<address, u64>,
        authorized_validators: VecSet<address>,
    }

    // Liquidity Pool for NAT/USDC
    struct LiquidityPool has key {
        id: UID,
        nat_balance: Balance<NAT>,
        usdc_balance: Balance<USDC>,
        lp_tokens: Balance<LPT>,
        fee_percentage: u64, // in basis points (1/10000)
    }

    // LP Token for the liquidity pool
    struct LPT has drop {}

    // Capability for administering the system
    struct AdminCap has key { id: UID }

    // Registry to keep track of all natural assets
    struct NaturalAssetRegistry has key {
        id: UID,
        assets: Table<ID, NaturalAsset>,
        total_valuation: u64,
        total_carbon_credits: u64,
        asset_count: u64,
    }

    // Struct for asset valuation requests
    struct ValuationRequest has key {
        id: UID,
        asset_id: ID,
        requester: address,
        status: String, // "Pending", "Approved", "Rejected"
        proposed_valuation: u64,
        validator: Option<address>,
    }

    // Events
    struct AssetTokenized has copy, drop {
        asset_id: ID,
        asset_type: String,
        name: String,
        token_supply: u64,
        valuation: u64,
    }

    struct AssetRevalued has copy, drop {
        asset_id: ID,
        old_valuation: u64,
        new_valuation: u64,
        validator: address,
    }

    struct SustainabilityScoreUpdated has copy, drop {
        asset_id: ID,
        old_score: u8,
        new_score: u8,
    }

    struct CarbonCreditsIssued has copy, drop {
        asset_id: ID,
        amount: u64,
    }

    struct FractionalOwnershipChanged has copy, drop {
        asset_id: ID,
        owner: address,
        amount: u64,
    }

    struct LiquidityAdded has copy, drop {
        provider: address,
        nat_amount: u64,
        usdc_amount: u64,
        lp_tokens_minted: u64,
    }

    struct LiquidityRemoved has copy, drop {
        provider: address,
        nat_amount: u64,
        usdc_amount: u64,
        lp_tokens_burned: u64,
    }

    struct Swap has copy, drop {
        trader: address,
        nat_amount: u64,
        usdc_amount: u64,
        is_nat_to_usdc: bool,
    }

    // Error codes
    const EInvalidAssetType: u64 = 0;
    const EInsufficientTokens: u64 = 1;
    const EInvalidScore: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EInvalidValuation: u64 = 4;
    const EInsufficientLiquidity: u64 = 5;
    const ESlippageExceeded: u64 = 6;

    // Initialize the module
    fun init(ctx: &mut TxContext) {
        // Create and share the registry
        transfer::share_object(NaturalAssetRegistry {
            id: object::new(ctx),
            assets: table::new(ctx),
            total_valuation: 0,
            total_carbon_credits: 0,
            asset_count: 0,
        });

        // Create and transfer the admin capability
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        // Initialize NAT
        let (treasury_cap, metadata) = coin::create_currency(
            NAT {},
            9, // Decimals
            b"NAT", // Symbol
            b"Natural Asset Token", // Name
            b"Token representing ownership in natural assets", // Description
            option::none(), // Icon URL
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

        // Initialize CCT
        let (cc_treasury_cap, cc_metadata) = coin::create_currency(
            CCT {},
            6, // Decimals
            b"CCT", // Symbol
            b"Carbon Credit Token", // Name
            b"Token representing carbon credits", // Description
            option::none(), // Icon URL
            ctx
        );
        transfer::public_freeze_object(cc_metadata);
        transfer::public_transfer(cc_treasury_cap, tx_context::sender(ctx));

        // Create and share the liquidity pool
        transfer::share_object(LiquidityPool {
            id: object::new(ctx),
            nat_balance: balance::zero(),
            usdc_balance: balance::zero(),
            lp_tokens: balance::zero(),
            fee_percentage: 30, // 0.3% fee
        });
    }

    // Function to tokenize a new natural asset
    public fun tokenize_asset(
        registry: &mut NaturalAssetRegistry,
        treasury_cap: &mut TreasuryCap<NAT>,
        asset_type: vector<u8>,
        name: vector<u8>,
        location: vector<u8>,
        area: u64,
        initial_valuation: u64,
        initial_sustainability_score: u8,
        metadata: VecMap<String, String>,
        ctx: &mut TxContext
    ) {
        let asset_type_str = utf8(asset_type);
        assert!(
            asset_type_str == utf8(b"Lake") || 
            asset_type_str == utf8(b"River") || 
            asset_type_str == utf8(b"Forest") ||
            asset_type_str == utf8(b"Wetland") ||
            asset_type_str == utf8(b"Coral Reef"),
            EInvalidAssetType
        );

        assert!(initial_sustainability_score <= 100, EInvalidScore);

        let token_supply = (initial_valuation / 100) as u64; // 1 token = $100 of value

        let asset = NaturalAsset {
            id: object::new(ctx),
            asset_type: asset_type_str,
            name: utf8(name),
            location: utf8(location),
            area,
            token_supply: balance::zero(),
            valuation: initial_valuation,
            sustainability_score: initial_sustainability_score,
            carbon_credits: balance::zero(),
            last_audit_timestamp: clock::timestamp_ms(clock),
            regulatory_compliance: table::new(ctx),
            metadata,
            fractional_ownership: table::new(ctx),
            authorized_validators: vec_set::empty(),
        };

        // Mint tokens for the asset
        coin::mint_balance(treasury_cap, token_supply, &mut asset.token_supply);

        let asset_id = object::id(&asset);
        table::add(&mut registry.assets, asset_id, asset);
        registry.total_valuation = registry.total_valuation + initial_valuation;
        registry.asset_count = registry.asset_count + 1;

        event::emit(AssetTokenized {
            asset_id,
            asset_type: asset_type_str,
            name: utf8(name),
            token_supply,
            valuation: initial_valuation,
        });
    }

    // Function to update asset valuation
    public fun update_valuation(
        registry: &mut NaturalAssetRegistry,
        asset_id: ID,
        new_valuation: u64,
        validator: address,
        ctx: &mut TxContext
    ) {
        let asset = table::borrow_mut(&mut registry.assets, asset_id);
        assert!(vec_set::contains(&asset.authorized_validators, &validator), EUnauthorized);

        let old_valuation = asset.valuation;
        asset.valuation = new_valuation;
        registry.total_valuation = registry.total_valuation - old_valuation + new_valuation;

        asset.last_audit_timestamp = clock::timestamp_ms(clock);

        event::emit(AssetRevalued {
            asset_id,
            old_valuation,
            new_valuation,
            validator,
        });
    }

    // Function to update sustainability score
    public fun update_sustainability_score(
        registry: &mut NaturalAssetRegistry,
        asset_id: ID,
        new_score: u8,
        validator: address,
    ) {
        assert!(new_score <= 100, EInvalidScore);
        let asset = table::borrow_mut(&mut registry.assets, asset_id);
        assert!(vec_set::contains(&asset.authorized_validators, &validator), EUnauthorized);

        let old_score = asset.sustainability_score;
        asset.sustainability_score = new_score;

        event::emit(SustainabilityScoreUpdated {
            asset_id,
            old_score,
            new_score,
        });
    }

    // Function to issue carbon credits
    public fun issue_carbon_credits(
        registry: &mut NaturalAssetRegistry,
        cc_treasury_cap: &mut TreasuryCap<CCT>,
        asset_id: ID,
        amount: u64,
        validator: address,
        ctx: &mut TxContext
    ) {
        let asset = table::borrow_mut(&mut registry.assets, asset_id);
        assert!(vec_set::contains(&asset.authorized_validators, &validator), EUnauthorized);

        coin::mint_balance(cc_treasury_cap, amount, &mut asset.carbon_credits);
        registry.total_carbon_credits = registry.total_carbon_credits + amount;

        event::emit(CarbonCreditsIssued {
            asset_id,
            amount,
        });
    }

    // Function to add liquidity to the NAT/USDC pool
    public fun add_liquidity(
        pool: &mut LiquidityPool,
        nat_amount: Coin<NAT>,
        usdc_amount: Coin<USDC>,
        ctx: &mut TxContext
    ): Coin<LPT> {
        let nat_value = coin::value(&nat_amount);
        let usdc_value = coin::value(&usdc_amount);

        balance::join(&mut pool.nat_balance, coin::into_balance(nat_amount));
        balance::join(&mut pool.usdc_balance, coin::into_balance(usdc_amount));

        // Mint LP tokens (simplified calculation)
        let lp_amount = (nat_value + usdc_value) / 2;
        let lp_tokens = balance::split(&mut pool.lp_tokens, lp_amount);

        event::emit(LiquidityAdded {
            provider: tx_context::sender(ctx),
            nat_amount: nat_value,
            usdc_amount: usdc_value,
            lp_tokens_minted: lp_amount,
        });

        coin::from_balance(lp_tokens, ctx)
    }

    // Function to remove liquidity from the NAT/USDC pool
    public fun remove_liquidity(
        pool: &mut LiquidityPool,
        lp_tokens: Coin<LPT>,
        ctx: &mut TxContext
    ): (Coin<NAT>, Coin<USDC>) {
        let lp_amount = coin::value(&lp_tokens);
        balance::join(&mut pool.lp_tokens, coin::into_balance(lp_tokens));

        let total_lp = balance::value(&pool.lp_tokens);
        let nat_share = (balance::value(&pool.nat_balance) * lp_amount) / total_lp;
        let usdc_share = (balance::value(&pool.usdc_balance) * lp_amount) / total_lp;

        event::emit(LiquidityRemoved {
            provider: tx_context::sender(ctx),
            nat_amount: nat_share,
            usdc_amount: usdc_share,
            lp_tokens_burned: lp_amount,
        });

        (
            coin::from_balance(balance::split(&mut pool.nat_balance, nat_share), ctx),
            coin::from_balance(balance::split(&mut pool.usdc_balance, usdc_share), ctx)
        )
    }

    // Function to swap NAT for USDC
    public fun swap_nat_for_usdc(
        pool: &mut LiquidityPool,
        nat_in: Coin<NAT>,
        min_usdc_out: u64,
        ctx: &mut TxContext
    ): Coin<USDC> {
        let nat_amount = coin::value(&nat_in);
        balance::join(&mut pool.nat_balance, coin::into_balance(nat_in));

        let (usdc_out, _) = calculate_swap(pool, nat_amount, true);
        assert!(usdc_out >= min_usdc_out, ESlippageExceeded);

        event::emit(Swap {
            trader: tx_context::sender(ctx),
            nat_amount,
            usdc_amount: usdc_out,
            is_nat_to_usdc: true,
        });

        coin::from_balance(balance::split(&mut pool.usdc_balance, usdc_out), ctx)
    }

    // Function to swap USDC for NAT
    public fun swap_usdc_for_nat(
        pool: &mut LiquidityPool,
        usdc_in: Coin<USDC>,
        min_nat_out: u64,
        ctx: &mut TxContext
    ): Coin<NAT> {
        let usdc_amount = coin::value(&usdc_in);
        balance::join(&mut pool.usdc_balance, coin::into_balance(usdc_in));

        let (nat_out, _) = calculate_swap(pool, usdc_amount, false);
        assert!(nat_out >= min_nat_out, ESlippageExceeded);

        event::emit(Swap {
            trader: tx_context::sender(ctx),
            nat_amount: nat_out,
            usdc_amount,
            is_nat_to_usdc: false,
        });

        coin::from_balance(balance::split(&mut pool.nat_balance, nat_out), ctx)
    }

    // Internal function to calculate swap amounts
    fun calculate_swap(pool: &LiquidityPool, amount_in: u64, is_nat_to_usdc: bool): (u64, u64) {
        let (reserve_in, reserve_out) = if (is_nat_to_usdc) {
            (balance::value(&pool.nat_balance), balance::value(&pool.usdc_balance))
        } else {
            (balance::value(&pool.usdc_balance), balance::value(&pool.nat_balance))
        };

        let amount_in_with_fee = amount_in * (10000 - pool.fee_percentage);
        let numerator = amount_in_with_fee * reserve_out;
        let denominator = (reserve_in * 10000) + amount_in_with_fee;
        let amount_out = numerator / denominator;

        (amount_out, amount_in - amount_out)
    }

// Function to update fractional ownership
    public fun update_fractional_ownership(
        asset: &mut NaturalAsset,
        owner: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        if (table::contains(&asset.fractional_ownership, owner)) {
            let current_amount = table::remove(&mut asset.fractional_ownership, owner);
            table::add(&mut asset.fractional_ownership, owner, current_amount + amount);
        } else {
            table::add(&mut asset.fractional_ownership, owner, amount);
        };

        event::emit(FractionalOwnershipChanged {
            asset_id: object::id(asset),
            owner,
            amount,
        });
    }

    // Function to get fractional ownership details
    public fun get_fractional_ownership(asset: &NaturalAsset, owner: address): u64 {
        if (table::contains(&asset.fractional_ownership, owner)) {
            *table::borrow(&asset.fractional_ownership, owner)
        } else {
            0
        }
    }

    // Function to update asset metadata
    public fun update_asset_metadata(
        _admin_cap: &AdminCap,
        asset: &mut NaturalAsset,
        key: String,
        value: String,
    ) {
        vec_map::insert(&mut asset.metadata, key, value);
    }

    // Function to get asset metadata
    public fun get_asset_metadata(asset: &NaturalAsset, key: &String): Option<String> {
        vec_map::get(&asset.metadata, key)
    }

    // Function to add authorized validator
    public fun add_authorized_validator(
        _admin_cap: &AdminCap,
        asset: &mut NaturalAsset,
        validator: address,
    ) {
        vec_set::insert(&mut asset.authorized_validators, validator);
    }

    // Function to remove authorized validator
    public fun remove_authorized_validator(
        _admin_cap: &AdminCap,
        asset: &mut NaturalAsset,
        validator: address,
    ) {
        vec_set::remove(&mut asset.authorized_validators, &validator);
    }

    // Function to check if a validator is authorized
    public fun is_authorized_validator(asset: &NaturalAsset, validator: address): bool {
        vec_set::contains(&asset.authorized_validators, &validator)
    }

    // Function to update liquidity pool fee
    public fun update_pool_fee(
        _admin_cap: &AdminCap,
        pool: &mut LiquidityPool,
        new_fee_percentage: u64,
    ) {
        assert!(new_fee_percentage <= 1000, EInvalidValuation); // Max 10% fee
        pool.fee_percentage = new_fee_percentage;
    }

    // Function to get pool details
    public fun get_pool_details(pool: &LiquidityPool): (u64, u64, u64, u64) {
        (
            balance::value(&pool.nat_balance),
            balance::value(&pool.usdc_balance),
            balance::value(&pool.lp_tokens),
            pool.fee_percentage
        )
    }

    // Function to get asset details
    public fun get_asset_details(asset: &NaturalAsset): (String, String, String, u64, u64, u64, u8, u64) {
        (
            asset.asset_type,
            asset.name,
            asset.location,
            asset.area,
            balance::value(&asset.token_supply),
            asset.valuation,
            asset.sustainability_score,
            balance::value(&asset.carbon_credits)
        )
    }

    // Function to check regulatory compliance
    public fun check_compliance(asset: &NaturalAsset, regulation: vector<u8>): bool {
        *table::borrow(&asset.regulatory_compliance, utf8(regulation))
    }

    // Function to update regulatory compliance
    public fun update_regulatory_compliance(
        _admin_cap: &AdminCap,
        asset: &mut NaturalAsset,
        regulation: vector<u8>,
        is_compliant: bool,
    ) {
        table::upsert(&mut asset.regulatory_compliance, utf8(regulation), is_compliant);
    }

    
    // Function to get total statistics from the registry
    public fun get_registry_stats(registry: &NaturalAssetRegistry): (u64, u64, u64) {
        (registry.total_valuation, registry.total_carbon_credits, registry.asset_count)
    }
}
