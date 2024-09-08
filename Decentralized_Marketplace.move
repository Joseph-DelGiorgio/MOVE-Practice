module my_addr::decentralized_marketplace {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;

    struct Listing has store {
        seller: address,
        price: u64,
        description: vector<u8>,
        active: bool,
    }

    struct Marketplace has key {
        listings: Table<u64, Listing>,
        listing_count: u64,
        fee_percentage: u64,
        fee_collector: address,
    }

    struct UserProfile has key {
        sold_items: u64,
        bought_items: u64,
    }

    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_LISTING_NOT_FOUND: u64 = 3;
    const E_LISTING_NOT_ACTIVE: u64 = 4;
    const E_INSUFFICIENT_FUNDS: u64 = 5;
    const E_NOT_SELLER: u64 = 6;
    const E_INVALID_FEE_PERCENTAGE: u64 = 7;

    public fun initialize(account: &signer, fee_percentage: u64) {
        let account_addr = signer::address_of(account);
        assert!(!exists<Marketplace>(account_addr), E_ALREADY_INITIALIZED);
        assert!(fee_percentage <= 1000, E_INVALID_FEE_PERCENTAGE); // Max 10% fee

        move_to(account, Marketplace {
            listings: table::new(),
            listing_count: 0,
            fee_percentage,
            fee_collector: account_addr,
        });
    }

    public fun create_listing(account: &signer, price: u64, description: vector<u8>) acquires Marketplace {
        let account_addr = signer::address_of(account);
        let marketplace = borrow_global_mut<Marketplace>(@my_addr);

        let listing_id = marketplace.listing_count + 1;
        table::add(&mut marketplace.listings, listing_id, Listing {
            seller: account_addr,
            price,
            description,
            active: true,
        });

        marketplace.listing_count = listing_id;
    }

    public fun buy_item(buyer: &signer, listing_id: u64) acquires Marketplace, UserProfile {
        let marketplace = borrow_global_mut<Marketplace>(@my_addr);
        assert!(table::contains(&marketplace.listings, listing_id), E_LISTING_NOT_FOUND);

        let listing = table::borrow_mut(&mut marketplace.listings, listing_id);
        assert!(listing.active, E_LISTING_NOT_ACTIVE);

        let buyer_addr = signer::address_of(buyer);
        assert!(coin::balance<AptosCoin>(buyer_addr) >= listing.price, E_INSUFFICIENT_FUNDS);

        let fee_amount = (listing.price * marketplace.fee_percentage) / 10000;
        let seller_amount = listing.price - fee_amount;

        coin::transfer<AptosCoin>(buyer, listing.seller, seller_amount);
        coin::transfer<AptosCoin>(buyer, marketplace.fee_collector, fee_amount);

        listing.active = false;

        // Update user profiles
        if (!exists<UserProfile>(listing.seller)) {
            move_to(&signer::create_signer_with_capability(
                &account::create_signer_capability(listing.seller)
            ), UserProfile { sold_items: 0, bought_items: 0 });
        }
        if (!exists<UserProfile>(buyer_addr)) {
            move_to(buyer, UserProfile { sold_items: 0, bought_items: 0 });
        }

        let seller_profile = borrow_global_mut<UserProfile>(listing.seller);
        seller_profile.sold_items = seller_profile.sold_items + 1;

        let buyer_profile = borrow_global_mut<UserProfile>(buyer_addr);
        buyer_profile.bought_items = buyer_profile.bought_items + 1;
    }

    public fun cancel_listing(seller: &signer, listing_id: u64) acquires Marketplace {
        let marketplace = borrow_global_mut<Marketplace>(@my_addr);
        assert!(table::contains(&marketplace.listings, listing_id), E_LISTING_NOT_FOUND);

        let listing = table::borrow_mut(&mut marketplace.listings, listing_id);
        assert!(listing.seller == signer::address_of(seller), E_NOT_SELLER);

        listing.active = false;
    }

    public fun get_listing_info(listing_id: u64): (address, u64, vector<u8>, bool) acquires Marketplace {
        let marketplace = borrow_global<Marketplace>(@my_addr);
        assert!(table::contains(&marketplace.listings, listing_id), E_LISTING_NOT_FOUND);

        let listing = table::borrow(&marketplace.listings, listing_id);
        (listing.seller, listing.price, *&listing.description, listing.active)
    }

    public fun get_user_stats(user_addr: address): (u64, u64) acquires UserProfile {
        assert!(exists<UserProfile>(user_addr), 0);
        let profile = borrow_global<UserProfile>(user_addr);
        (profile.sold_items, profile.bought_items)
    }
}
