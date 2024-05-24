module The_Capys::myCapy {

    struct Capy has key, store {
        id: UID,
        gen: u64,
        url: Url,
        genes: Genes,
        item_count: u8,
        attributes: vector<Attributes>,
    }

    //Wearable Item, Has special display in capy.art application. 
    struct CapyItem has key, store {
        id: UID,
        url: Url,
        type: String,
        name: String,
    }

    //Capy Car
    struct Car has key, sotre {
        id: UID,
        stats: Stats,
    }

    // Attach an Item to Capy. Function is generic and allows any app to attach items to
    // Capys buts the total count of items has to be lower than 255.

    public entry fun add_item<T: key + store>(capy: &mut Capy, item: T) {
        emit(ItemAdded<T> {
            capy_id: object::id(capy),
            item_id: object::id(&item),
        });

        dof::add(&mut capy.id, object::id(&item), item);
    }
}

module intro_df::capy_car {

    use capy::capy::{Self, Capy};
    use intro_df::car::Car;

    /// Add a dynamic object field of a `Car` (child) to a `Capy` (parent)
    public entry fun ride_car(capy: &mut Capy, car: Car) {
        capy::add_item(capy, car);
    }
    
}

module The_Capys::table_EX {
    
    //tables store homogenous, non objects
    struct Table<phantom K: copy+ drop + store, phantom V: store> has key, store {
        // the ID of this table
        id: UID,
        // the number of key-value pairs in the table
        size: u64,
    }

    struct Bag has key, store {
        //ID of this bag
        id: UID,
        // the number of key value pairs in the bag
        size: u64,
    }

    struct ObjectTable<phantom: K: copy + drop + store, phantom V: key + store> has key, store {
        //ID of this table
        id: UID,
        //the number of key value pairs in the table
        size: u64,
    }

}
