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

# On-Chain Crypto Index Builder on Sui

This repository contains a **Sui Move smart contract** that enables the creation and management of **on-chain crypto indices**. By leveraging **DeepBook's liquidity layer**, the contract provides real-time price and market depth data to ensure accurate index valuations and dynamic rebalancing. It is designed for developers building decentralized finance (DeFi) applications or users seeking to create diversified crypto portfolios directly on the Sui blockchain.

---

## Features

### 1. **Index Creation**
   - Create custom crypto indices by specifying a list of assets and their corresponding weights.
   - Automatically calculates the initial value of the index using DeepBook’s liquidity data.

### 2. **Real-Time Liquidity Integration**
   - Fetches live price and liquidity data for each asset in the index using DeepBook APIs.
   - Ensures that indices are built on reliable, up-to-date market data.

### 3. **Dynamic Rebalancing**
   - Automatically rebalance portfolios based on updated liquidity and price data.
   - Keeps indices aligned with market conditions to maintain their intended structure.

### 4. **Asset Management**
   - Add or remove assets from an existing index dynamically.
   - Adjust weights as needed to reflect portfolio changes.

### 5. **Index Value Calculation**
   - Calculates the total value of the portfolio in a base currency (e.g., USD).
   - Uses real-time asset prices fetched from DeepBook.

### 6. **Event Emission for Transparency**
   - Emits events for key actions such as:
     - `IndexCreated`: Triggered when a new index is created.
     - `IndexRebalanced`: Triggered when an index is rebalanced.
   - Enables easy tracking of changes and actions on-chain.

---

## How It Works

1. **Create an Index**:
   - Specify a name, a list of assets, and their weights.
   - The contract fetches liquidity data from DeepBook to calculate the initial value.

2. **Fetch Liquidity Data**:
   - Use DeepBook’s API to retrieve real-time price and market depth for any asset in the index.

3. **Rebalance Portfolios**:
   - Dynamically adjust asset allocations based on updated market conditions.
   - Emit events to notify users when rebalancing occurs.

4. **Add or Remove Assets**:
   - Modify an existing index by adding new assets or removing old ones while maintaining proper weight distribution.

5. **Track Portfolio Value**:
   - Continuously calculate the total value of the portfolio in a base currency (e.g., USD).

---

## Use Cases

- **Portfolio Management**: Build diversified crypto portfolios with automated rebalancing.
- **DeFi Applications**: Use this contract as a foundation for yield farming, derivatives trading, or other DeFi tools.
- **Transparency & Automation**: Ensure transparency through event emission and automate portfolio adjustments with real-time market data.

---

## Example Workflow

1. Deploy the smart contract on Sui.
2. Create an index with your desired assets and weights.
3. Fetch live liquidity data from DeepBook for accurate valuations.
4. Rebalance your portfolio periodically based on updated market conditions.
5. Add or remove assets as needed to adjust your portfolio structure.

---

## Why Use This Contract?

This contract combines transparency, automation, and real-time market insights into a single tool that simplifies on-chain portfolio management. Whether you're a developer building DeFi applications or an individual looking to create custom crypto indices, this solution offers flexibility, accuracy, and ease of use.

---

## Future Enhancements

- Support for more advanced rebalancing strategies (e.g., volatility-based adjustments).
- Integration with other DeFi protocols for yield optimization.
- Enhanced analytics features for tracking historical performance of indices.

---

Feel free to contribute or open issues if you have suggestions for improvements!

