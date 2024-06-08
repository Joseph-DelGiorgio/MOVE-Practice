module 0x1::digital_asset_marketplace {

    use sui::coin::{Coin, TreasuryCap, transfer};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::vector;
    use sui::event;

    struct Asset has key, store {
        id: UID,
        owner: address,
        name: String,
        description: String,
        price: u64,
        is_listed: bool,
    }

    struct Marketplace has key {
        id: UID,
        assets: vector::Vector<Asset>,
    }

    public entry fun init_marketplace(ctx: &mut TxContext): Marketplace {
        let assets = vector::empty<Asset>();
        Marketplace {
            id: object::new<UID>(ctx),
            assets,
        }
    }

    public entry fun list_asset(
        marketplace: &mut Marketplace,
        name: String,
        description: String,
        price: u64,
        ctx: &mut TxContext
    ) {
        let asset = Asset {
            id: object::new<UID>(ctx),
            owner: tx_context::sender(ctx),
            name,
            description,
            price,
            is_listed: true,
        };
        vector::push_back(&mut marketplace.assets, asset);
    }

    public entry fun buy_asset(
        marketplace: &mut Marketplace,
        asset_id: u64,
        payment: Coin,
        ctx: &mut TxContext
    ) {
        let index = find_asset(&marketplace.assets, asset_id);
        let asset = &mut vector::borrow_mut(&mut marketplace.assets, index);

        assert!(asset.is_listed, 0); // Ensure the asset is listed for sale
        assert!(tx_context::value_of(payment) >= asset.price, 0); // Ensure sufficient payment

        let seller = asset.owner;
        asset.owner = tx_context::sender(ctx);
        asset.is_listed = false;

        transfer(payment, seller, ctx); // Transfer payment to seller
    }

    public entry fun delist_asset(
        marketplace: &mut Marketplace,
        asset_id: u64,
        ctx: &mut TxContext
    ) {
        let index = find_asset(&marketplace.assets, asset_id);
        let asset = &mut vector::borrow_mut(&mut marketplace.assets, index);

        assert!(asset.owner == tx_context::sender(ctx), 0); // Only owner can delist

        asset.is_listed = false;
    }

    fun find_asset(assets: &vector::Vector<Asset>, asset_id: u64): u64 {
        let len = vector::length(assets);
        let mut i = 0;
        while (i < len) {
            let asset = &vector::borrow(assets, i);
            if (asset.id == asset_id) {
                return i;
            }
            i = i + 1;
        }
        assert!(false, 0); // Asset not found
        0 // Default return to satisfy the function signature, will never reach here due to assert
    }

    public fun get_listed_assets(marketplace: &Marketplace): vector::Vector<Asset> {
        let mut listed_assets = vector::empty<Asset>();
        let assets = &marketplace.assets;
        let len = vector::length(assets);
        let mut i = 0;
        while (i < len) {
            let asset = &vector::borrow(assets, i);
            if (asset.is_listed) {
                vector::push_back(&mut listed_assets, *asset);
            }
            i = i + 1;
        }
        listed_assets
    }

    public fun get_user_assets(marketplace: &Marketplace, user: address): vector::Vector<Asset> {
        let mut user_assets = vector::empty<Asset>();
        let assets = &marketplace.assets;
        let len = vector::length(assets);
        let mut i = 0;
        while (i < len) {
            let asset = &vector::borrow(assets, i);
            if (asset.owner == user) {
                vector::push_back(&mut user_assets, *asset);
            }
            i = i + 1;
        }
        user_assets
    }
}
