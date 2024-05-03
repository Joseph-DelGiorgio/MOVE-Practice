module nft_tutorial::nft {
    use sui::object::{Self, UID};
    use sui ::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string::String;

    struct NFT has key, store{
        id: UID,
        name: String,
        description: String,
    }

    public entry fun mint(name: String, description: String, ctx: &mut TxContext){
        //create the new NFT
        let nft : NFT = NFT{
            id: UID :
        }
    }
}
