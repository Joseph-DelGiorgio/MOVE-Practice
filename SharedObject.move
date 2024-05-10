struct SharedObject has key {
   id: UID,
}


struct OwnedObject has key {
   id: UID,
}


public fun create_shared_object(ctx: &mut TxContext) {
 let shared_object = SharedObject {
     id: object::new(ctx),
 };
 transfer::share_object(shared_object);
}


public fun create_owned_object(ctx: &mut TxContext) {
 let owned_object = OwnedObject {
     id: object::new(ctx),
 };
 transfer::transfer(owned_object, tx_context::sender(ctx));
}
