module crypto_index_fund::index_fund {

    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::vec_map::{Self, VecMap};
    use sui::table::{Self, Table};
    use std::vector;
    use SupraOracle::SupraSValueFeed::{get_price, get_prices, extract_price, OracleHolder, Price};

    const BTC_INDEX: u32 = 0;
    const ETH_INDEX: u32 = 1;
    const XRP_INDEX: u32 = 14;
    const ADA_INDEX: u32 = 16;
    const MATIC_INDEX: u32 = 20;

    struct IndexFundToken has key, store {
        id: UID, 
        crypto_assets: Table<u32, u128>, 
    }

    struct IndexFund has key, store {
        id: UID, 
        balance: Balance<SUI>,
        pairs: vector<u32>,
    }

    fun init(ctx: &mut TxContext) {
        // vector of crypto pairs to query the oracle for
        let pairs: vector<u32> = vector[BTC_INDEX, ETH_INDEX, XRP_INDEX, ADA_INDEX, MATIC_INDEX];

        // initialize the fund balance to 0
        let index_fund = IndexFund {
        id: object::new(ctx),
        balance: balance::zero(),
        pairs,
        };
        transfer::share_object(index_fund);
    }

    public entry fun deposit_investment(oracle_holder: &OracleHolder, index_fund: &mut IndexFund, deposit_amount: Coin<SUI>, ctx: &mut TxContext) {

    // convert coin into balance 
    let deposit_balance_sui: Balance<SUI> = coin::into_balance(deposit_amount);
    // get deposit_amount in sui and then convert to u128 for math operations
    let deposit_amount_sui: u128 = (balance::value(&deposit_balance_sui) as u128);

    // add deposit balance to fund balance
    balance::join(&mut index_fund.balance, deposit_balance_sui);

    // query oracle for SUI_USD price 
    let (sui_usd_price,_,_,_) = get_price(oracle_holder, 90);

    let adjusted_sui_usd_price: u128 = convert_to_9_decimal_places(sui_usd_price);

    // calculate deposit amount in USD 
    let deposit_amount_usd: u128 = adjusted_sui_usd_price * deposit_amount_sui; 

    // divide by 5 to get investment amount per crypto as it is equally weighted
    let investment_amount_per_crypto: u128 = deposit_amount_usd / 5;

    // query oracle for all 5 crypto assets in fund 
    let price_holder: VecMap<u32, u128> = get_crypto_prices(oracle_holder, index_fund.pairs);

    // calculate investment proportions for each and then divide by the price of each crypto in USD
    let btc: u128 = investment_amount_per_crypto / *vec_map::get(&price_holder, &BTC_INDEX);
    let eth: u128 = investment_amount_per_crypto / *vec_map::get(&price_holder, &ETH_INDEX);
    let xrp: u128 = investment_amount_per_crypto / *vec_map::get(&price_holder, &XRP_INDEX);
    let ada: u128 = investment_amount_per_crypto / *vec_map::get(&price_holder, &ADA_INDEX);
    let matic: u128 = investment_amount_per_crypto / *vec_map::get(&price_holder, &MATIC_INDEX);

    let crypto_assets: Table<u32, u128> = table::new<u32, u128>(ctx);

    table::add(&mut crypto_assets, BTC_INDEX, btc);
    table::add(&mut crypto_assets, ETH_INDEX, eth);
    table::add(&mut crypto_assets, XRP_INDEX, xrp);
    table::add(&mut crypto_assets, ADA_INDEX, ada);
    table::add(&mut crypto_assets, MATIC_INDEX, matic);

    // mint NFT and send to user
    let index_token = IndexFundToken {
        id: object::new(ctx),
        crypto_assets,
    };

    transfer::public_transfer(index_token, tx_context::sender(ctx));

    }

    public entry fun withdraw_investment(oracle_holder: &OracleHolder, index_fund: &mut IndexFund, index_token: IndexFundToken, ctx: &mut TxContext) {
  
        // query oracle for all 5 cryptos in fund
        let price_holder: VecMap<u32, u128> = get_crypto_prices(oracle_holder, index_fund.pairs);

        // calculate the total USD value of the IndexFundToken

        let btc_usd_value: u128 = *table::borrow(&index_token.crypto_assets, BTC_INDEX) * *vec_map::get(&price_holder, &BTC_INDEX);
        let eth_usd_value: u128 = *table::borrow(&index_token.crypto_assets, ETH_INDEX) * *vec_map::get(&price_holder, &ETH_INDEX);
        let xrp_usd_value: u128 = *table::borrow(&index_token.crypto_assets, XRP_INDEX) * *vec_map::get(&price_holder, &XRP_INDEX);
        let ada_usd_value: u128 = *table::borrow(&index_token.crypto_assets, ADA_INDEX) * *vec_map::get(&price_holder, &ADA_INDEX);
        let matic_usd_value: u128 = *table::borrow(&index_token.crypto_assets, MATIC_INDEX) * *vec_map::get(&price_holder, &MATIC_INDEX);

        let total_usd_value: u128 = btc_usd_value + eth_usd_value + xrp_usd_value + ada_usd_value + matic_usd_value;

        // query oracle for SUI_USD price 
        let (sui_usd_price,_,_,_) = get_price(oracle_holder, 90);

        let adjusted_sui_usd_price: u128 = convert_to_9_decimal_places(sui_usd_price);

        // convert total USD value to SUI 
        let total_sui: u64 = ((total_usd_value / adjusted_sui_usd_price) as u64); 

        // subtract the withdrawal amount from the fund balance
        let index_token_balance: Balance<SUI> = balance::split(&mut index_fund.balance, total_sui);

        // convert balance into coin for transfer
        let total_coin_sui: Coin<SUI> = coin::from_balance(index_token_balance, ctx);

        // transfer the total value in SUI back to the sender
        transfer::public_transfer(total_coin_sui, tx_context::sender(ctx));

        // burn the IndexFundToken
        let IndexFundToken { id,  crypto_assets } = index_token;
        table::drop(crypto_assets);
        object::delete(id);
    }

    fun get_crypto_prices(oracle_holder: &OracleHolder, pairs: vector<u32>): VecMap<u32, u128> {

        let crypto_prices: vector<Price> = get_prices(oracle_holder, pairs);

        let price_holder: VecMap<u32, u128> = vec_map::empty<u32, u128>(); 

        let length: u64 = vector::length(&crypto_prices);
        let idx: u64 = 0;

        while (idx < length) {
            let price = vector::borrow(&crypto_prices, idx);
            let (pair, value, _decimal, _timestamp, _round) = extract_price(price);
            let adjusted_value: u128 = convert_to_9_decimal_places(value);
            vec_map::insert(&mut price_holder, pair, adjusted_value);
            idx = idx + 1;
        };
        price_holder
    }

}
