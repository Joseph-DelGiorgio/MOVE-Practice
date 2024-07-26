module natural_assets::rwa_tokenization {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;
    use std::string::{String, utf8};

    // Define a custom coin type for our Natural Asset Token
    struct NAT {}

    // Struct to represent a Natural Asset
    struct NaturalAsset has key, store {
        id: UID,
        asset_type: String,
        name: String,
        location: String,
        area: u64,  // in square kilometers
        token_supply: Balance<NAT>
    }

    // Capability for minting NAT
    struct MintCapability has key { id: UID }

    // Registry to keep track of all natural assets
    struct NaturalAssetRegistry has key {
        id: UID,
        assets: Table<ID, NaturalAsset>
    }

    // Events
    struct AssetTokenized has copy, drop {
        asset_type: String,
        name: String,
        token_supply: u64
    }

    struct AssetTransferred has copy, drop {
        asset_id: ID,
        from: address,
        to: address
    }

    // Error codes
    const EInvalidAssetType: u64 = 0;
    const EInsufficientTokens: u64 = 1;

    // Initialize the module
    fun init(ctx: &mut TxContext) {
        // Create and share the registry
        transfer::share_object(NaturalAssetRegistry {
            id: object::new(ctx),
            assets: table::new(ctx)
        });

        // Create and transfer the mint capability to the module initializer
        transfer::transfer(MintCapability {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        // Register the NAT coin type
        coin::create_currency<NAT>(
            NAT {},
            9, // Decimals
            b"NAT", // Symbol
            b"Natural Asset Token", // Name
            b"Token representing ownership in natural assets", // Description
            option::none(), // Icon URL
            ctx
        );
    }

    // Function to tokenize a new natural asset
    public fun tokenize_asset(
        registry: &mut NaturalAssetRegistry,
        _capability: &MintCapability,
        asset_type: vector<u8>,
        name: vector<u8>,
        location: vector<u8>,
        area: u64,
        token_supply: u64,
        ctx: &mut TxContext
    ) {
        let asset_type_str = utf8(asset_type);
        assert!(
            asset_type_str == utf8(b"Lake") || 
            asset_type_str == utf8(b"River") || 
            asset_type_str == utf8(b"Forest"),
            EInvalidAssetType
        );

        let asset = NaturalAsset {
            id: object::new(ctx),
            asset_type: asset_type_str,
            name: utf8(name),
            location: utf8(location),
            area,
            token_supply: balance::zero<NAT>()
        };

        // Mint tokens for the asset
        let minted_balance = balance::create_with_value(coin::mint_balance<NAT>(token_supply, ctx));
        balance::join(&mut asset.token_supply, minted_balance);

        let asset_id = object::id(&asset);
        table::add(&mut registry.assets, asset_id, asset);

        event::emit(AssetTokenized {
            asset_type: asset_type_str,
            name: utf8(name),
            token_supply
        });
    }

    // Function to transfer ownership of a natural asset
    public fun transfer_asset(
        registry: &mut NaturalAssetRegistry,
        asset_id: ID,
        to: address,
        ctx: &mut TxContext
    ) {
        let asset = table::remove(&mut registry.assets, asset_id);
        event::emit(AssetTransferred {
            asset_id,
            from: tx_context::sender(ctx),
            to
        });
        transfer::transfer(asset, to);
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

    // Getter for asset details
    public fun get_asset_details(asset: &NaturalAsset): (String, String, String, u64, u64) {
        (
            asset.asset_type,
            asset.name,
            asset.location,
            asset.area,
            balance::value(&asset.token_supply)
        )
    }
}
