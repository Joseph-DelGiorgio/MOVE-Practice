module examples::if {
    use sui::object::UID;
    use sui::tx_context::{Self, TxContext};

    //Dedclaring the example object:
    struct ExampleObject has key {
        id: UID,
        num: u8,
    }

    //Initializing the constructor

    fun main(ctx: &mut TxContext) {

        //Try switching to false
        let a = true;
        let b = if (a) {
            10
        } else {
            20
        };

        let obj = ExampleObject {
            id: object::new(ctx),
            num: b,
        }
    }
}
