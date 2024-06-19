module PaymentApp {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::SUI;
    use 0x1::Vector;
    use 0x1::Errors;

    struct Account {
        owner: address,
        balance: u64,
    }

    struct PaymentApp {
        accounts: vector<Account>,
    }

    public fun new_payment_app(admin: &signer): address {
        let payment_app = PaymentApp {
            accounts: vector::empty(),
        };
        let payment_app_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, payment_app);
        payment_app_address
    }

    public fun create_account(payment_app_address: address, user: &signer) {
        let user_address = Signer::address_of(user);
        let payment_app = &mut borrow_global_mut<PaymentApp>(payment_app_address);
        
        let account = Account {
            owner: user_address,
            balance: 0,
        };

        vector::push_back(&mut payment_app.accounts, account);
    }

    public fun deposit(payment_app_address: address, user: &signer, amount: u64) {
        let user_address = Signer::address_of(user);
        let payment_app = &mut borrow_global_mut<PaymentApp>(payment_app_address);
        
        let account = &mut find_account_mut(&mut payment_app.accounts, user_address);
        account.balance += amount;

        SUI::transfer(user, payment_app_address, amount);
    }

    public fun transfer(payment_app_address: address, from: &signer, to_address: address, amount: u64) {
        let from_address = Signer::address_of(from);
        let payment_app = &mut borrow_global_mut<PaymentApp>(payment_app_address);
        
        let from_account = &mut find_account_mut(&mut payment_app.accounts, from_address);
        let to_account = &mut find_account_mut(&mut payment_app.accounts, to_address);
        
        assert!(from_account.balance >= amount, 1);
        from_account.balance -= amount;
        to_account.balance += amount;
    }

    public fun get_balance(payment_app_address: address, user: &signer): u64 {
        let user_address = Signer::address_of(user);
        let payment_app = borrow_global<PaymentApp>(payment_app_address);
        
        let account = find_account(&payment_app.accounts, user_address);
        account.balance
    }

    fun find_account(accounts: &vector<Account>, owner: address): &Account {
        let account_opt = vector::find(accounts, move |acc| acc.owner == owner);
        assert!(account_opt.is_some(), Errors::not_found(0));
        account_opt.borrow().unwrap()
    }

    fun find_account_mut(accounts: &mut vector<Account>, owner: address): &mut Account {
        let account_opt = vector::find_mut(accounts, move |acc| acc.owner == owner);
        assert!(account_opt.is_some(), Errors::not_found(0));
        account_opt.borrow_mut().unwrap()
    }
}

/*
Explanation
Account Structure: Represents a user account with an owner address and a balance.
PaymentApp Structure: Contains a vector of accounts.
new_payment_app: Initializes a new payment application with an empty list of accounts.
create_account: Allows a user to create an account in the payment application.
deposit: Enables a user to deposit funds into their account by transferring the specified amount of SUI tokens to the payment application.
transfer: Allows a user to transfer funds from their account to another user's account within the payment application.
get_balance: Returns the balance of the user's account.
find_account: Helper function to find an account by owner address.
find_account_mut: Helper function to find a mutable reference to an account by owner address.
*/


