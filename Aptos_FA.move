module aptos_asset::fungible_asset {
    // Importing the necessary modules
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    // Importing functionalities for fungible assets, including self-reference, minting, transferring, burning, metadata, and fungible asset utilities.

    use aptos_framework::object::{Self, Object};
    // Importing object management functionalities, including self-reference and object handling.

    use aptos_framework::primary_fungible_store;
    // Importing the primary fungible store module.

    use std::error;
    // Importing standard error handling functionalities.

    use std::signer;
    // Importing functionalities for handling signers.

    use std::string::utf8;
    // Importing functionalities for UTF-8 string manipulation.

    use std::option;
    // Importing functionalities for handling optional values.

    /// Only fungible asset metadata owner can make changes.
    // Constants
    const ENOT_OWNER: u64 = 1;
    // Error code indicating that the action is not allowed because the user is not the owner of the fungible asset metadata.

    const ASSET_SYMBOL: vector<u8> = b"META";
    // Symbol for the fungible asset, represented as a vector of bytes.

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef, // Reference for minting assets
        transfer_ref: TransferRef, // Reference for transferring assets
        burn_ref: BurnRef, // Reference for burning assets
    }
}

