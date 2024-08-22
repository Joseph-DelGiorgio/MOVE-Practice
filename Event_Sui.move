module example::events {
	use sui::object::{UID};
	use sui::tx_context::{Self, TxContext};
	use sui::transfer;
 
	// Object representing our hero
	struct Hero has key, store{
		id: UID,
		power: u8,
	}
	 
	// Object representing our hero's sword
	struct Sword has key {
		id: UID
	}
	
	// Object representing an event
	struct buySwordEvent has copy, drop {
	  owner: address,
	}

	// Function to buy a sword, if the user owns a hero
	public fun buy_sword (hero: Hero, ctx: &mut TxContext){
		let sword = Sword {
		id: object::new(ctx),
		};
		
	// Emitting an event with the address of the user who brought the sword
	event::emit(buySwordEvent {
      owner: tx_context::sender(ctx),
   });

	//Transfer the sword to the caller of this function
		transfer::transfer(sword, tx_context::sender(ctx));

	} 

}
