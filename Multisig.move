module sui_multisig::MultiSigWallet {
    use std::signer;
    use std::vector;
    use std::account;
    use std::option;
    use std::hash;

    const REQUIRED_SIGNATURES: u64 = 3;
    const MAX_OWNERS: u64 = 5;

    struct Wallet has copy, drop, store {
        owners: vector::Vector<address>,
        required: u64,
        transactions: vector::Vector<Transaction>,
    }

    struct Transaction has copy, drop, store {
        to: address,
        value: u64,
        signatures: vector::Vector<address>,
        executed: bool,
    }

    public fun create_wallet(account: &signer, owners: vector::Vector<address>): Wallet {
        let owner_count = vector::length(&owners);
        assert!(owner_count <= MAX_OWNERS, 0);
        Wallet {
            owners,
            required: REQUIRED_SIGNATURES,
            transactions: vector::empty(),
        }
    }

    public fun submit_transaction(wallet: &mut Wallet, account: &signer, to: address, value: u64) {
        let sender = signer::address_of(account);
        assert!(is_owner(wallet, sender), 1);
        let tx = Transaction {
            to,
            value,
            signatures: vector::empty(),
            executed: false,
        };
        vector::push_back(&mut wallet.transactions, tx);
    }

    public fun confirm_transaction(wallet: &mut Wallet, account: &signer, tx_index: u64) {
        let sender = signer::address_of(account);
        assert!(is_owner(wallet, sender), 1);
        let tx = &mut vector::borrow_mut(&mut wallet.transactions, tx_index);
        assert!(!tx.executed, 2);
        assert!(!has_signed(tx, sender), 3);
        vector::push_back(&mut tx.signatures, sender);
    }

    public fun execute_transaction(wallet: &mut Wallet, account: &signer, tx_index: u64) {
        let sender = signer::address_of(account);
        assert!(is_owner(wallet, sender), 1);
        let tx = &mut vector::borrow_mut(&mut wallet.transactions, tx_index);
        assert!(vector::length(&tx.signatures) >= wallet.required, 4);
        assert!(!tx.executed, 2);
        // Logic for transferring tokens or executing the transaction
        tx.executed = true;
    }

    public fun is_owner(wallet: &Wallet, addr: address): bool {
        vector::contains(&wallet.owners, &addr)
    }

    public fun has_signed(tx: &Transaction, addr: address): bool {
        vector::contains(&tx.signatures, &addr)
    }
}
