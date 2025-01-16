/*
# SkyTrade Air Rights Smart Contract (Sui Move)

This Sui Move smart contract implements a system for managing and trading air rights parcels. It allows users to create, list, delist, and transfer air rights, with built-in payment handling using SUI coins.

## Key Features

- Create air rights parcels with specified cubic feet and price per cubic foot
- List and delist air rights parcels for sale
- Transfer air rights parcels between users with automatic payment handling
- Event emission for all major actions (creation, listing, delisting, transfer)

## Contract Structure

### Structs

1. `AirRightsParcel`: Represents an individual air rights parcel
2. `AirRightsRegistry`: Manages all air rights parcels

### Events

1. `AirRightsCreatedEvent`: Emitted when a new air rights parcel is created
2. `AirRightsTransferredEvent`: Emitted when an air rights parcel is transferred
3. `AirRightsListedEvent`: Emitted when an air rights parcel is listed for sale
4. `AirRightsDelistedEvent`: Emitted when an air rights parcel is delisted from sale

### Functions

1. `init`: Initializes the AirRightsRegistry (called once when publishing the module)
2. `create_air_rights`: Creates a new air rights parcel
3. `sell_and_transfer_air_rights`: Transfers an air rights parcel from seller to buyer with payment
4. `list_air_rights`: Lists an air rights parcel for sale
5. `delist_air_rights`: Removes an air rights parcel from sale listing

## Usage

1. Deploy the contract to the Sui network.
2. Users can create air rights parcels using `create_air_rights`.
3. Owners can list their parcels for sale with `list_air_rights`.
4. Buyers can purchase listed parcels using `sell_and_transfer_air_rights`.
5. Owners can remove their parcels from sale using `delist_air_rights`.

## Important Notes

- All functions include necessary assertions to ensure proper usage and ownership.
- The contract uses Sui's `Table` for efficient storage and retrieval of parcels.
- Payment is handled using Sui coins (SUI) with exact price matching.

## Testing

Unit tests should be written using Sui's testing framework to ensure all functions work as expected. Test cases should cover:

- Creating air rights parcels
- Listing and delisting parcels
- Transferring parcels with correct payment
- Handling of error cases (e.g., insufficient payment, unauthorized actions)

## Future Improvements

- Implement partial transfers of air rights (splitting parcels)
- Add support for different types of coins
- Implement a more sophisticated pricing model
- Add administrative functions for contract management

*/

module sky_trade::air_rights {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};

    // Structs
    struct AirRightsParcel has key, store {
        id: UID,
        owner: address,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
        is_listed: bool,
    }

    struct AirRightsRegistry has key {
        id: UID,
        parcels: Table<u64, AirRightsParcel>,
        next_id: u64,
    }

    // Events
    struct AirRightsCreatedEvent has copy, drop {
        parcel_id: u64,
        owner: address,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
    }

    struct AirRightsTransferredEvent has copy, drop {
        from: address,
        to: address,
        parcel_id: u64,
    }

    struct AirRightsListedEvent has copy, drop {
        owner: address,
        parcel_id: u64,
        price_per_cubic_foot: u64,
    }

    struct AirRightsDelistedEvent has copy, drop {
        owner: address,
        parcel_id: u64,
    }

    // Functions
    fun init(ctx: &mut TxContext) {
        let registry = AirRightsRegistry {
            id: object::new(ctx),
            parcels: table::new(ctx),
            next_id: 0,
        };
        transfer::share_object(registry);
    }

    public entry fun create_air_rights(
        registry: &mut AirRightsRegistry,
        cubic_feet: u64,
        price_per_cubic_foot: u64,
        ctx: &mut TxContext
    ) {
        assert!(cubic_feet > 0, 2);
        assert!(price_per_cubic_foot > 0, 3);

        let parcel_id = registry.next_id;
        registry.next_id = parcel_id + 1;

        let parcel = AirRightsParcel {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            cubic_feet,
            price_per_cubic_foot,
            is_listed: false,
        };

        table::add(&mut registry.parcels, parcel_id, parcel);

        event::emit(AirRightsCreatedEvent {
            parcel_id,
            owner: tx_context::sender(ctx),
            cubic_feet,
            price_per_cubic_foot,
        });
    }

    public entry fun sell_and_transfer_air_rights(
        registry: &mut AirRightsRegistry,
        parcel_id: u64,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let parcel = table::borrow_mut(&mut registry.parcels, parcel_id);
        assert!(parcel.is_listed, 5);

        let expected_price = parcel.cubic_feet * parcel.price_per_cubic_foot;
        assert!(coin::value(payment) == expected_price, 11);

        let seller = parcel.owner;
        let buyer = tx_context::sender(ctx);

        coin::transfer(payment, seller);

        parcel.owner = buyer;
        parcel.is_listed = false;

        event::emit(AirRightsTransferredEvent {
            from: seller,
            to: buyer,
            parcel_id,
        });
    }

    public entry fun list_air_rights(
        registry: &mut AirRightsRegistry,
        parcel_id: u64,
        price_per_cubic_foot: u64,
        ctx: &mut TxContext
    ) {
        let parcel = table::borrow_mut(&mut registry.parcels, parcel_id);
        assert!(parcel.owner == tx_context::sender(ctx), 6);
        assert!(price_per_cubic_foot > 0, 7);

        parcel.is_listed = true;
        parcel.price_per_cubic_foot = price_per_cubic_foot;

        event::emit(AirRightsListedEvent {
            owner: tx_context::sender(ctx),
            parcel_id,
            price_per_cubic_foot,
        });
    }

    public entry fun delist_air_rights(
        registry: &mut AirRightsRegistry,
        parcel_id: u64,
        ctx: &mut TxContext
    ) {
        let parcel = table::borrow_mut(&mut registry.parcels, parcel_id);
        assert!(parcel.owner == tx_context::sender(ctx), 8);
        assert!(parcel.is_listed, 9);

        parcel.is_listed = false;

        event::emit(AirRightsDelistedEvent {
            owner: tx_context::sender(ctx),
            parcel_id,
        });
    }

    // Tests would need to be adjusted for Sui's testing framework
}
