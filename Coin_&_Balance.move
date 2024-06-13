module Tb {
    //structs

    //Public getter for the coin value
    public fun value<T>(self: &Coin<T>): u64 {
        balance::value(&self.balance)
    }

    //Get immutable reference to the balance of a coin
    public fun balance<T>(coin: &Coin<T>): &Balance<T> {
        &coin.balance
    }

    //Get a mutable reference to the balance of a coin 
    public fun balance_mut<T>(coin: &mut Coin<T>): &mut Balance<T> {
        &mut coin.balance
    }

    //Wrap a balance into a COin to make it transferable
    public fun from_balance<T>(balance: Balance<T>, ctx: &mut TxContext): Coin<T> {
        Coin { id: object::new(ctx), balance }
    }

    //Destruct a coin wrapper and keep the balance.
    public fun into_balance<T>(coin: Coin<T>): Balance<T> {
        let Coin { id, balance} = coin;
        object::delete(id);
        balance
    } 
}
