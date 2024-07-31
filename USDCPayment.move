module prison_transfer::money_transfer {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;

    // Errors
    const EInsufficientBalance: u64 = 0;
    const EInvalidAmount: u64 = 1;

    // Events
    struct TransferEvent has copy, drop {
        from: address,
        to: address,
        amount: u64,
    }

    // Structs
    struct Wallet has key {
        id: UID,
        balance: Balance<SUI>,
        owner: address,
    }

    // Functions
    public fun create_wallet(ctx: &mut TxContext) {
        let wallet = Wallet {
            id: object::new(ctx),
            balance: balance::zero(),
            owner: tx_context::sender(ctx),
        };
        transfer::transfer(wallet, tx_context::sender(ctx));
    }

    public fun deposit(wallet: &mut Wallet, coin: Coin<SUI>, ctx: &mut TxContext) {
        let amount = coin::value(&coin);
        balance::join(&mut wallet.balance, coin::into_balance(coin));
        event::emit(TransferEvent {
            from: tx_context::sender(ctx),
            to: wallet.owner,
            amount,
        });
    }

    public fun withdraw(wallet: &mut Wallet, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        assert!(amount > 0, EInvalidAmount);
        assert!(balance::value(&wallet.balance) >= amount, EInsufficientBalance);
        
        let coin = coin::take(&mut wallet.balance, amount, ctx);
        event::emit(TransferEvent {
            from: wallet.owner,
            to: tx_context::sender(ctx),
            amount,
        });
        coin
    }

    public fun transfer(from: &mut Wallet, to: &mut Wallet, amount: u64, ctx: &mut TxContext) {
        let coin = withdraw(from, amount, ctx);
        deposit(to, coin, ctx);
    }

    public fun balance(wallet: &Wallet): u64 {
        balance::value(&wallet.balance)
    }
}
