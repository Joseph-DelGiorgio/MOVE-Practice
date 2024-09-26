module airbnb::dynamic_rental {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};

    /// Error codes
    const EInvalidDuration: u64 = 0;
    const EInsufficientPayment: u64 = 1;
    const EPropertyNotAvailable: u64 = 2;
    const ENotOwner: u64 = 3;
    const EInvalidPriceAdjustment: u64 = 4;

    /// Represents a rental property
    struct Property has key {
        id: UID,
        owner: address,
        base_price_per_day: u64,
        is_available: bool,
        bookings: Table<u64, Booking>,
        price_adjustments: Table<u64, u64>, // timestamp to price adjustment percentage
    }

    /// Represents a booking
    struct Booking has store {
        renter: address,
        start_time: u64,
        end_time: u64,
        total_price: u64,
    }

    /// Events
    struct PropertyListed has copy, drop {
        property_id: ID,
        owner: address,
        base_price_per_day: u64,
    }

    struct PropertyBooked has copy, drop {
        property_id: ID,
        renter: address,
        start_time: u64,
        end_time: u64,
        total_price: u64,
    }

    /// Creates and lists a new property
    public entry fun list_property(
        base_price_per_day: u64,
        ctx: &mut TxContext
    ) {
        let property = Property {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            base_price_per_day,
            is_available: true,
            bookings: table::new(ctx),
            price_adjustments: table::new(ctx),
        };

        transfer::share_object(property);

        sui::event::emit(PropertyListed {
            property_id: object::uid_to_inner(&property.id),
            owner: property.owner,
            base_price_per_day,
        });
    }

    /// Books a property for a specified duration
    public entry fun book_property(
        property: &mut Property,
        payment: &mut Coin<SUI>,
        start_time: u64,
        end_time: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(start_time > current_time && end_time > start_time, EInvalidDuration);
        assert!(property.is_available, EPropertyNotAvailable);

        let duration = (end_time - start_time) / (24 * 60 * 60 * 1000); // Convert to days
        let total_price = calculate_total_price(property, start_time, duration);

        assert!(coin::value(payment) >= total_price, EInsufficientPayment);

        // Transfer payment to property owner
        let paid = coin::split(payment, total_price, ctx);
        transfer::public_transfer(paid, property.owner);

        // Create and store booking
        let booking = Booking {
            renter: tx_context::sender(ctx),
            start_time,
            end_time,
            total_price,
        };
        table::add(&mut property.bookings, object::new(ctx), booking);

        // Update property availability
        property.is_available = false;

        sui::event::emit(PropertyBooked {
            property_id: object::uid_to_inner(&property.id),
            renter: booking.renter,
            start_time,
            end_time,
            total_price,
        });
    }

    /// Calculates the total price for a booking
    fun calculate_total_price(property: &Property, start_time: u64, duration: u64): u64 {
        let base_price = property.base_price_per_day * duration;
        let mut adjusted_price = base_price;

        let i = 0;
        while (i < duration) {
            let day_timestamp = start_time + (i * 24 * 60 * 60 * 1000);
            if (table::contains(&property.price_adjustments, day_timestamp)) {
                let adjustment = *table::borrow(&property.price_adjustments, day_timestamp);
                adjusted_price = adjusted_price + ((base_price * adjustment) / 100);
            };
            i = i + 1;
        };

        adjusted_price
    }

    /// Allows property owner to adjust pricing for specific dates
    public entry fun adjust_pricing(
        property: &mut Property,
        timestamp: u64,
        adjustment_percentage: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == property.owner, ENotOwner);
        assert!(adjustment_percentage <= 200, EInvalidPriceAdjustment); // Max 200% increase

        table::add(&mut property.price_adjustments, timestamp, adjustment_percentage);
    }

    /// Allows property owner to remove a price adjustment
    public entry fun remove_price_adjustment(
        property: &mut Property,
        timestamp: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == property.owner, ENotOwner);
        table::remove(&mut property.price_adjustments, timestamp);
    }
}
