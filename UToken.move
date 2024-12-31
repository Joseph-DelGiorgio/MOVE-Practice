module UniqueToken {

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::Balance;
    use sui::coin::{Coin, TreasuryCapability};

    /// Struct representing our unique token
    struct UniqueToken has key {
        id: UID,
        balance: Balance<u64>,
    }

    /// Events for logging activities
    struct MintEvent has drop {
        amount: u64,
        recipient: address,
    }

    struct TransferEvent has drop {
        amount: u64,
        sender: address,
        recipient: address,
    }

    struct BurnEvent has drop {
        amount: u64,
        burner: address,
    }

    /// Initialize the module with an initial supply of tokens
    public fun initialize(ctx: &mut TxContext): UniqueToken {
        let id = object::new(ctx);
        let balance = Balance::zero();
        UniqueToken { id, balance }
    }

    /// Mint new tokens to a specified address
    public fun mint(
        treasury_capability: &TreasuryCapability,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) acquires UniqueToken {
        assert!(amount > 0, 0);

        let token = borrow_global_mut<UniqueToken>(recipient);
        Balance::credit(&mut token.balance, amount);

        emit MintEvent { amount, recipient };
    }

    /// Transfer tokens from one address to another
    public fun transfer(
        sender: &signer,
        recipient: address,
        amount: u64
    ) acquires UniqueToken {
        assert!(amount > 0, 0);

        let sender_token = borrow_global_mut<UniqueToken>(signer::address_of(sender));
        let recipient_token = borrow_global_mut<UniqueToken>(recipient);

        Balance::withdraw(&mut sender_token.balance, amount);
        Balance::credit(&mut recipient_token.balance, amount);

        emit TransferEvent { amount, sender: signer::address_of(sender), recipient };
    }

    /// Burn tokens from the caller's account
    public fun burn(
        burner: &signer,
        amount: u64
    ) acquires UniqueToken {
        assert!(amount > 0, 0);

        let token = borrow_global_mut<UniqueToken>(signer::address_of(burner));
        
        Balance::withdraw(&mut token.balance, amount);

        emit BurnEvent { amount, burner: signer::address_of(burner) };
    }
}
