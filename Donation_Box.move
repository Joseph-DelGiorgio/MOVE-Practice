module donation_box_addr::DonationBox {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    struct DonationBox has key {
        total_donations: u64,
        owner: address,
    }

    const E_NOT_OWNER: u64 = 1;

    public fun initialize(owner: &signer) {
        move_to(owner, DonationBox {
            total_donations: 0,
            owner: signer::address_of(owner),
        });
    }

    public entry fun donate(account: &signer, amount: u64) acquires DonationBox {
        let donation_box = borrow_global_mut<DonationBox>(@donation_box_addr);
        let coin = coin::withdraw<AptosCoin>(account, amount);
        coin::deposit(donation_box.owner, coin);
        donation_box.total_donations = donation_box.total_donations + amount;
    }

    #[view]
    public fun get_total_donations(): u64 acquires DonationBox {
        borrow_global<DonationBox>(@donation_box_addr).total_donations
    }

    public entry fun withdraw(account: &signer) acquires DonationBox {
        let account_addr = signer::address_of(account);
        assert!(account_addr == @donation_box_addr, E_NOT_OWNER);
        let donation_box = borrow_global_mut<DonationBox>(@donation_box_addr);
        let balance = donation_box.total_donations;
        let coin = coin::withdraw<AptosCoin>(account, balance);
        coin::deposit(account_addr, coin);
        donation_box.total_donations = 0;
    }
}
