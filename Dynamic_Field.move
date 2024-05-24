module Dynamic_Fields {
//example of object wrapping:
struct Hero has key {
    id: UID,
    name: String,
    level: u64,
    hitpoints: u64,
    xrp: u64,
    url: Url,
    sword: Sword //Option: swords: vector<Sword>,
}

//Whats wrong with this approach? 
//...
//Dynamic fields can only be added to another object
//The example below adds a dynamic field to the object 'object &mut UID' at field specified by 'name: Name'
//Aborts with 'EFieldAlreadyExists' if the object already has that field with that name. 

//Dynamic Field:

public fun add<Name: copy + drop + store, Value: store>(
    //we use &mut UID in several spots for access control 
    object: &mut UID,
    name: Name,
    value: Value,
)

//Dynamic Object Field: (difference is the 'key' added to store for Value)

public fun add<Name: copy + drop + store, Value: key + store>(
    //we use &mut UID in several spots for access control 
    object: &mut UID,
    name: Name,
    value: Value,
)

//Intro to Dynamic Fields

module intro_df {
    use sui::dynamic_field as field;
    use sui::dynamic_object_field_as ofield;

    //parent struct
    struct Parent has key {
        id: UID,
    }

    // Dynamic Field child struct type containing a counter
    struct DFChild has store {
        count: u64,
    }

    //Dynamic object field child struct type containing a counter
    struct DOFChild has key, store {
        id: UID,
        count: u64,
    }

    //Adds a DFChild to the parent object under the provided name
    public fun add_dfchild(parent: &mut Parent, child: DFChild, name: vector<u8>) {
        field::add(&mut parent.id, name, child);
    }

    //Adds a DOFChild to the parent under the provided name
    public entry fun add_dofchild(parent: &mut Parent, child: DOFChild, name: vector<u8>) {
        ofield::add(&mut parent.id, name, child);
    }


    //Mutate a DOFChild directly
    public entry fun mutate_dofchild(child: &mut DOFChild) {
        child.count = child.count + 1;
    }

    //Mutate a DFCHILD directly 
    public fun mutate_dfchild(child: &mut DFChild) {
        child.count = child.count +1;
    }

    //Mutate a DFChilds counter via its parent object
    public entry fun mutate_dfchild_via_parent(parent: &mut Parent, child_name: vector<u8>) {
        let child = field::borrow_mut<vector<u8>, DFChild> (&mut parent.id, child_name);
        child.count = child.count + 1;
    }

    //Mutate a DOFChild counter via its parent object 
    public entry fun mutate_dofchild_via_parent(parent: Parent, child_name: vector<u8>) {
        mutate_dofchild(ofield::borrow_mut<vector<u8>, DOFChild>(
            &mut parent.id,
            child_name,
        ));
    }

}

}

module intro_df::car {
    use sui::transfer;
    use sui::url::{Self, Url};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field_as ofield;

    struct Car has key {
        id: UID,
        stats: Stats,
    }

    struct Stats has store {
        speed: u8,
        accerleration: u8,
        handling: u8,
    }

    struct Decal has key, store {
        id: UID,
        url: Url,
    }

    public entry fun create_car(ctx: &mut TxContext) {
        let car = Car {
            id: object::new(ctx),
            stats: Stats {
                speed: 50,
                accerleration: 50,
                handling: 50,
            }
        };
        transfer::transfer(car, tx_context::sender(ctx));
    }

    public entry fun create_decal(url: vector<u8>, ctx: &mut TxContext) {
        let decal = Decal {
            id: object::new(ctx),
            url: url::new_unsafe_from_bytes(url)
        };
        transfer::transfer(decal, tx_context::sender(ctx));
    }
}



module 0x123::sui_fren {
    use sui::object::{Self, UID};
    use std::string::String;
    use sui::dynamic_field;
    
    struct SuiFren has key, store {
        id: UID,
        generation: u64,
        birthdate: u64,
        attributes: vector<String>,
    }

    struct Hat has store {
        color: String,
    }

    public fun color_hat(sui_fren: &mut SuiFren, color: String) {
        if (dynamic_field::exists_(&sui_fren.id, string::utf8(HAT_KEY))) {
            let hat: &mut Hat = dynamic_field::borrow_mut(&mut sui_fren.id, string::utf8(HAT_KEY));
            hat.color = color;
        } else {
            dynamic_field::add(&mut sui_fren.id, string::utf8(HAT_KEY), Hat { color });
        }
    }
}
