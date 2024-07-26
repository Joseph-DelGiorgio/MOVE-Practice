module natural_assets::enhanced_rwa_tokenization {
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

    // Define custom coin types
    struct NAT {} // Natural Asset Token
    struct CCT {} // Carbon Credit Token

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
        regulatory_compliance: Table<String, bool>, // Key: regulation name, Value: compliance status
    }

    // Capability for administering the system
    struct AdminCap has key { id: UID }

    // Registry to keep track of all natural assets
    struct NaturalAssetRegistry has key {
        id: UID,
        assets: Table<ID, NaturalAsset>,
        total_valuation: u64,
        total_carbon_credits: u64,
    }

    // Struct for asset valuation requests
    struct ValuationRequest has key {
        id: UID,
        asset_id: ID,
        requester: address,
        status: String, // "Pending", "Approved", "Rejected"
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

    // Error codes
    const EInvalidAssetType: u64 = 0;
    const EInsufficientTokens: u64 = 1;
    const EInvalidScore: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EInvalidValuation: u64 = 4;

    // Initialize the module
    fun init(ctx: &mut TxContext) {
        // Create and share the registry
        transfer::share_object(NaturalAssetRegistry {
            id: object::new(ctx),
            assets: table::new(ctx),
            total_valuation: 0,
            total_carbon_credits: 0,
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
        };

        // Mint tokens for the asset
        coin::mint_balance(treasury_cap, token_supply, &mut asset.token_supply);

        let asset_id = object::id(&asset);
        table::add(&mut registry.assets, asset_id, asset);
        registry.total_valuation = registry.total_valuation + initial_valuation;

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
        _admin_cap: &AdminCap,
        asset_id: ID,
        new_valuation: u64,
        ctx: &mut TxContext
    ) {
        let asset = table::borrow_mut(&mut registry.assets, asset_id);
        let old_valuation = asset.valuation;
        asset.valuation = new_valuation;
        registry.total_valuation = registry.total_valuation - old_valuation + new_valuation;

        event::emit(AssetRevalued {
            asset_id,
            old_valuation,
            new_valuation,
        });
    }

    // Function to update sustainability score
    public fun update_sustainability_score(
        registry: &mut NaturalAssetRegistry,
        _admin_cap: &AdminCap,
        asset_id: ID,
        new_score: u8,
    ) {
        assert!(new_score <= 100, EInvalidScore);
        let asset = table::borrow_mut(&mut registry.assets, asset_id);
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
        _admin_cap: &AdminCap,
        asset_id: ID,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let asset = table::borrow_mut(&mut registry.assets, asset_id);
        coin::mint_balance(cc_treasury_cap, amount, &mut asset.carbon_credits);
        registry.total_carbon_credits = registry.total_carbon_credits + amount;

        event::emit(CarbonCreditsIssued {
            asset_id,
            amount,
        });
    }

    // Function to request asset valuation
    public fun request_valuation(
        asset_id: ID,
        ctx: &mut TxContext
    ) {
        let valuation_request = ValuationRequest {
            id: object::new(ctx),
            asset_id,
            requester: tx_context::sender(ctx),
            status: utf8(b"Pending"),
        };
        transfer::share_object(valuation_request);
    }

    // Function to approve or reject valuation request
    public fun process_valuation_request(
        _admin_cap: &AdminCap,
        request: &mut ValuationRequest,
        approve: bool,
    ) {
        if (approve) {
            request.status = utf8(b"Approved");
        } else {
            request.status = utf8(b"Rejected");
        };
    }

    // Function to get tokens from an asset
    public fun withdraw_tokens(
        asset: &mut NaturalAsset,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<NAT> {
        assert!(balance::value(&asset.token_supply) >= amount, EInsufficientTokens);
        coin::from_balance(balance::split(&mut asset.token_supply, amount), ctx)
    }

    // Function to deposit tokens back to an asset
    public fun deposit_tokens(asset: &mut NaturalAsset, tokens: Coin<NAT>) {
        let token_balance = coin::into_balance(tokens);
        balance::join(&mut asset.token_supply, token_balance);
    }

    // Function to withdraw carbon credits
    public fun withdraw_carbon_credits(
        asset: &mut NaturalAsset,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<CCT> {
        assert!(balance::value(&asset.carbon_credits) >= amount, EInsufficientTokens);
        coin::from_balance(balance::split(&mut asset.carbon_credits, amount), ctx)
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

    // Getter for asset details
    public fun get_asset_details(asset: &NaturalAsset): (String, String, String, u64, u64, u64, u8, u64, u64) {
        (
            asset.asset_type,
            asset.name,
            asset.location,
            asset.area,
            balance::value(&asset.token_supply),
            asset.valuation,
            asset.sustainability_score,
            balance::value(&asset.carbon_credits),
            asset.last_audit_timestamp
        )
    }

    // Function to check regulatory compliance
    public fun check_compliance(asset: &NaturalAsset, regulation: vector<u8>): bool {
        *table::borrow(&asset.regulatory_compliance, utf8(regulation))
    }
}
