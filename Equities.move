module equity_tokenization::equity {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};

    /// Struct representing a tokenized equity
    struct Equity has key, store {
        id: UID,
        ticker: vector<u8>,
        company_name: vector<u8>,
        total_shares: u64,
        available_shares: u64,
        price_per_share: u64,
        is_listed: bool,
        proceeds: Balance<SUI>,
        owner: address,
        dividend_pool: Balance<SUI>,
        last_dividend_timestamp: u64,
        shareholders: Table<address, u64>,
    }

    /// Struct representing a fractional ownership
    struct FractionalOwnership has key, store {
        id: UID,
        equity_id: UID,
        owner: address,
        shares: u64,
    }

    /// Capability for administrative actions
    struct AdminCap has key, store {
        id: UID,
    }

    /// Event emitted when a new equity is listed
    struct EquityListed has copy, drop {
        equity_id: UID,
        ticker: vector<u8>,
        company_name: vector<u8>,
        total_shares: u64,
        price_per_share: u64,
    }

    /// Event emitted when shares are transferred
    struct SharesTransferred has copy, drop {
        equity_id: UID,
        from: address,
        to: address,
        shares: u64,
    }

    /// Event emitted when dividends are distributed
    struct DividendsDistributed has copy, drop {
        equity_id: UID,
        total_amount: u64,
        timestamp: u64,
    }

    /// Error codes
    const E_NOT_LISTED: u64 = 1;
    const E_INSUFFICIENT_SHARES: u64 = 2;
    const E_INSUFFICIENT_PAYMENT: u64 = 3;
    const E_NOT_AUTHORIZED: u64 = 4;
    const E_INVALID_AMOUNT: u64 = 5;

    /// Initialize the module
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    /// Function to list a new equity on-chain
    public fun list_equity(
        _: &AdminCap,
        ticker: vector<u8>,
        company_name: vector<u8>,
        total_shares: u64,
        price_per_share: u64,
        ctx: &mut TxContext
    ): Equity {
        let equity = Equity {
            id: object::new(ctx),
            ticker,
            company_name,
            total_shares,
            available_shares: total_shares,
            price_per_share,
            is_listed: true,
            proceeds: balance::zero(),
            owner: tx_context::sender(ctx),
            dividend_pool: balance::zero(),
            last_dividend_timestamp: 0,
            shareholders: table::new(ctx),
        };
        event::emit(EquityListed {
            equity_id: object::uid_to_inner(&equity.id),
            ticker: equity.ticker,
            company_name: equity.company_name,
            total_shares,
            price_per_share,
        });
        equity
    }

    /// Function to purchase shares of an equity
    public fun purchase_shares(
        equity: &mut Equity,
        payment: &mut Coin<SUI>,
        shares: u64,
        ctx: &mut TxContext
    ): FractionalOwnership {
        assert!(equity.is_listed, E_NOT_LISTED);
        assert!(equity.available_shares >= shares, E_INSUFFICIENT_SHARES);
        
        let required_payment = equity.price_per_share * shares;
        assert!(coin::value(payment) >= required_payment, E_INSUFFICIENT_PAYMENT);

        let paid = coin::split(payment, required_payment, ctx);
        balance::join(&mut equity.proceeds, coin::into_balance(paid));

        equity.available_shares = equity.available_shares - shares;
        
        let buyer = tx_context::sender(ctx);
        if (table::contains(&equity.shareholders, buyer)) {
            let existing_shares = table::remove(&mut equity.shareholders, buyer);
            table::add(&mut equity.shareholders, buyer, existing_shares + shares);
        } else {
            table::add(&mut equity.shareholders, buyer, shares);
        };
        
        let ownership = FractionalOwnership {
            id: object::new(ctx),
            equity_id: object::uid_to_inner(&equity.id),
            owner: buyer,
            shares,
        };
        
        event::emit(SharesTransferred {
            equity_id: object::uid_to_inner(&equity.id),
            from: object::id_address(equity),
            to: buyer,
            shares,
        });
        
        ownership
    }

    /// Function to transfer fractional ownership
    public fun transfer_shares(
        equity: &mut Equity,
        ownership: &mut FractionalOwnership,
        new_owner: address,
        shares: u64,
        ctx: &mut TxContext
    ) {
        assert!(ownership.shares >= shares, E_INSUFFICIENT_SHARES);
        ownership.shares = ownership.shares - shares;
        
        // Update shareholders table
        let sender = tx_context::sender(ctx);
        let sender_shares = table::remove(&mut equity.shareholders, sender) - shares;
        if (sender_shares > 0) {
            table::add(&mut equity.shareholders, sender, sender_shares);
        }
        
        if (table::contains(&equity.shareholders, new_owner)) {
            let existing_shares = table::remove(&mut equity.shareholders, new_owner);
            table::add(&mut equity.shareholders, new_owner, existing_shares + shares);
        } else {
            table::add(&mut equity.shareholders, new_owner, shares);
        }
        
        let new_ownership = FractionalOwnership {
            id: object::new(ctx),
            equity_id: ownership.equity_id,
            owner: new_owner,
            shares,
        };
        event::emit(SharesTransferred {
            equity_id: ownership.equity_id,
            from: ownership.owner,
            to: new_owner,
            shares,
        });
        transfer::transfer(new_ownership, new_owner);
        
        if (ownership.shares == 0) {
            transfer::transfer(ownership, sender);
        }
    }

    /// Function to withdraw proceeds from equity sales
    public fun withdraw_proceeds(equity: &mut Equity, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        assert!(tx_context::sender(ctx) == equity.owner, E_NOT_AUTHORIZED);
        assert!(balance::value(&equity.proceeds) >= amount, E_INSUFFICIENT_PAYMENT);
        let withdrawn = balance::split(&mut equity.proceeds, amount);
        coin::from_balance(withdrawn, ctx)
    }

    /// Function to distribute dividends
    public fun distribute_dividends(
        equity: &mut Equity,
        clock: &Clock,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == equity.owner, E_NOT_AUTHORIZED);
        let amount = coin::value(payment);
        assert!(amount > 0, E_INVALID_AMOUNT);
        
        let dividend_payment = coin::split(payment, amount, ctx);
        balance::join(&mut equity.dividend_pool, coin::into_balance(dividend_payment));
        
        equity.last_dividend_timestamp = clock::timestamp_ms(clock);
        
        event::emit(DividendsDistributed {
            equity_id: object::uid_to_inner(&equity.id),
            total_amount: amount,
            timestamp: equity.last_dividend_timestamp,
        });
    }

    /// Function for shareholders to claim their dividends
    public fun claim_dividends(
        equity: &mut Equity,
        ownership: &FractionalOwnership,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let claimant = tx_context::sender(ctx);
        assert!(ownership.owner == claimant, E_NOT_AUTHORIZED);
        
        let total_dividend_pool = balance::value(&equity.dividend_pool);
        let claimant_shares = ownership.shares;
        let claimant_dividend = (total_dividend_pool * claimant_shares) / equity.total_shares;
        
        let claimed_amount = balance::split(&mut equity.dividend_pool, claimant_dividend);
        coin::from_balance(claimed_amount, ctx)
    }

    /// Function to update the share price
    public fun update_share_price(equity: &mut Equity, _: &AdminCap, new_price: u64) {
        equity.price_per_share = new_price;
    }

    /// Function to delist an equity
    public fun delist_equity(equity: &mut Equity, _: &AdminCap) {
        equity.is_listed = false;
    }

    /// Function to get the current share price
    public fun get_share_price(equity: &Equity): u64 {
        equity.price_per_share
    }

    /// Function to get the available shares
    public fun get_available_shares(equity: &Equity): u64 {
        equity.available_shares
    }

    /// Function to get the total shares
    public fun get_total_shares(equity: &Equity): u64 {
        equity.total_shares
    }

    /// Function to get the list of shareholders
    public fun get_shareholders(equity: &Equity): VecMap<address, u64> {
        let shareholders = vec_map::empty();
        let keys = table::keys(&equity.shareholders);
        let values = table::values(&equity.shareholders);
        let i = 0;
        while (i < vector::length(&keys)) {
            vec_map::insert(&mut shareholders, *vector::borrow(&keys, i), *vector::borrow(&values, i));
            i = i + 1;
        };
        shareholders
    }
}


/*
Here are the new features and improvements:
Added an AdminCap struct and init function to create an admin capability for privileged operations.
Enhanced the Equity struct with:
owner field to track the equity issuer
dividend_pool to hold dividends for distribution
last_dividend_timestamp to record the last dividend distribution
shareholders table to keep track of all shareholders and their holdings
Updated purchase_shares and transfer_shares to maintain the shareholders table.
Added a distribute_dividends function to allow the equity owner to distribute dividends to shareholders.
Added a claim_dividends function for shareholders to claim their dividends.
Added update_share_price and delist_equity functions for administrative control.
Added getter functions:
get_share_price
get_available_shares
get_total_shares
get_shareholders
Improved error handling with more specific error codes.
Added a DividendsDistributed event to track dividend distributions.
Used the Clock object for timestamp recording in dividend distribution.
These additions provide a more comprehensive equity tokenization system with dividend distribution capabilities, improved administrative controls,
and better tracking of shareholders. The contract now offers more functionality while maintaining security and adhering to Sui Move best practices.
*/

