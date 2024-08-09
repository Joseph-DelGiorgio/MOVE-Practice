module my_addr::faa {
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object;
    use std::option;
    use std::string;
    
    const MY_TOKEN_SYMBOL: vector<u8> = b"FAA";
    
    fun init_module(module_signer: &signer) {
        let metadata_constructor_ref = &object::create_named_object(module_signer, MY_TOKEN_SYMBOL);
        let max_supply = option::none();
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_constructor_ref,
            max_supply,
            string::utf8(b"Asset A"),
            string::utf8(MY_TOKEN_SYMBOL),
            6,
            string::utf8(b"https://example.com/icon.png"),
            string::utf8(b"https://example.com"),
        );
    }

    let mint_ref = fungible_asset::generate_mint_ref(metadata_constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(metadata_constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(metadata_constructor_ref);
}
