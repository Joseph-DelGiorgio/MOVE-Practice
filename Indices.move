module CryptoIndex {

    use sui::deepbook;
    use sui::coin;
    use sui::tx_context;
    use sui::math;

    /// Struct to store index data
    struct CryptoIndex has key {
        name: vector<u8>,               // Name of the index
        assets: vector<coin::Coin>,     // List of assets in the index
        weights: vector<u64>,           // Weights assigned to each asset
        total_value: u64,               // Total value of the index in base currency (e.g., USD)
    }

    /// Event emitted when an index is created
    struct IndexCreatedEvent has drop {
        name: vector<u8>,
        total_value: u64,
    }

    /// Event emitted when an index is rebalanced
    struct IndexRebalancedEvent has drop {
        name: vector<u8>,
        new_total_value: u64,
    }

    /// Create a new crypto index
    public fun create_index(
        ctx: &mut tx_context::TxContext,
        name: vector<u8>,
        assets: vector<coin::Coin>,
        weights: vector<u64>
    ): CryptoIndex {
        assert!(assets.length() == weights.length(), "Assets and weights must match");
        
        let total_value = calculate_index_value(&assets, &weights, ctx);

        // Emit an event for index creation
        tx_context::emit_event(
            ctx,
            IndexCreatedEvent { name: name.clone(), total_value },
        );

        CryptoIndex { name, assets, weights, total_value }
    }

    /// Fetch liquidity data from DeepBook for a specific asset
    public fun fetch_liquidity(asset: &coin::Coin, ctx: &mut tx_context::TxContext): u64 {
        let liquidity_data = deepbook::get_liquidity(asset, ctx);
        liquidity_data
    }

    /// Calculate the value of the index based on asset prices and weights
    public fun calculate_index_value(
        assets: &vector<coin::Coin>,
        weights: &vector<u64>,
        ctx: &mut tx_context::TxContext
    ): u64 {
        let mut total_value = 0;
        
        let num_assets = assets.length();
        
        let i = 0;
        while (i < num_assets) {
            let asset_price = fetch_liquidity(&assets[i], ctx); // Fetch asset price from DeepBook
            let weighted_value = math::mul(asset_price, weights[i]);
            total_value = math::add(total_value, weighted_value);
            i = math::add(i, 1);
        }

        total_value
    }

    /// Rebalance the index based on updated DeepBook liquidity data
    public fun rebalance_index(index: &mut CryptoIndex, ctx: &mut tx_context::TxContext) {
        let new_total_value = calculate_index_value(&index.assets, &index.weights, ctx);

        // Update the total value of the index
        index.total_value = new_total_value;

        // Emit an event for rebalancing
        tx_context::emit_event(
            ctx,
            IndexRebalancedEvent { name: index.name.clone(), new_total_value },
        );
    }

    /// Add a new asset to the index with a specified weight
    public fun add_asset_to_index(
        index: &mut CryptoIndex,
        asset: coin::Coin,
        weight: u64,
    ) {
        index.assets.push(asset);
        index.weights.push(weight);
    }

    /// Remove an asset from the index by its position
    public fun remove_asset_from_index(
        index: &mut CryptoIndex,
        position: u64,
    ) {
        assert!(position < index.assets.length(), "Invalid position");
        
        // Remove the asset and its corresponding weight
        vector::remove(&mut index.assets, position);
        vector::remove(&mut index.weights, position);
    }
}

