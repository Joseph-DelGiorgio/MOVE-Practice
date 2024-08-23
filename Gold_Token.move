module my_wallet::gold {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};

    /// Represents a Gold-backed token.
    public struct GOLD has drop {}

    /// Initializes the Gold token with the appropriate metadata and sends the treasury cap to the deployer.
    fun init(witness: GOLD, ctx: &mut TxContext) {
        // Create the GOLD currency with metadata appropriate for a gold-backed token.
        let (treasury, metadata) = coin::create_currency(
            witness,
            9, // Number of decimal places for the token.
            b"GLD", // Symbol for the Gold-backed token.
            b"Gold", // Name of the token.
            b"A gold-backed digital asset", // Description of the token.
            option::some(url::new_unsafe_from_bytes(b"https://example.com/gold.png")), // Replace with a URL pointing to an image of gold.
            ctx
        );

        // Freeze the metadata so that it cannot be altered.
        transfer::public_freeze_object(metadata);

        // Transfer the treasury cap to the deployer of the contract.
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Allows the treasury cap holder to mint more GOLD tokens.
    public entry fun mint(
        treasury: &mut coin::TreasuryCap<GOLD>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury, amount, recipient, ctx);
    }
}
