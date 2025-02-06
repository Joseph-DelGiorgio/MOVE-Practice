module equity_tokenization::equity {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

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
    }

    /// Struct representing a fractional ownership
    struct FractionalOwnership has key, store {
        id: UID,
        equity_id: UID,
        owner: address,
        shares: u64,
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

    /// Error codes
    const E_NOT_LISTED: u64 = 1;
    const E_INSUFFICIENT_SHARES: u64 = 2;
    const E_INSUFFICIENT_PAYMENT: u64 = 3;

    /// Function to list a new equity on-chain
    public fun list_equity(
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
        
        let ownership = FractionalOwnership {
            id: object::new(ctx),
            equity_id: object::uid_to_inner(&equity.id),
            owner: tx_context::sender(ctx),
            shares,
        };
        
        event::emit(SharesTransferred {
            equity_id: object::uid_to_inner(&equity.id),
            from: object::id_address(equity),
            to: tx_context::sender(ctx),
            shares,
        });
        
        ownership
    }

    /// Function to transfer fractional ownership
    public fun transfer_shares(
        ownership: &mut FractionalOwnership,
        new_owner: address,
        shares: u64,
        ctx: &mut TxContext
    ) {
        assert!(ownership.shares >= shares, E_INSUFFICIENT_SHARES);
        ownership.shares = ownership.shares - shares;
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
            transfer::transfer(ownership, tx_context::sender(ctx));
        }
    }

    /// Function to withdraw proceeds from equity sales
    public fun withdraw_proceeds(equity: &mut Equity, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        let withdrawn = balance::split(&mut equity.proceeds, amount);
        coin::from_balance(withdrawn, ctx)
    }
}
