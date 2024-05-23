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
        ofield::add(&mut parent.id, name, child);
    }

    //Adds a DOFChild to the parent under the provided name
    public entry fun add_dofchild(parent: &mut Parent, child: DOFChild, name: vector<u8>) {
        ofield::add(&mut parent.id, name, child);
    }

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
