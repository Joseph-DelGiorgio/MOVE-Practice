module sui_place::place {
    
    use std::vector;

    struct Place has key, store {
        id: UID,
    }

struct map has key, store {
    id: ID,
}

    struct Quadrant has key, store {
        id: UID,
        quadrant_id: u8,
        board: vector<vector<u32>>
    }

    fun init(ctx: &mut TxContext) {
        //todo
    }

    public fun set_pixel_at(place: &mut Place, x: u64, y: u64, color: u32) {
        //
    }

    public fun get_quadrants(place: &mut Place): vector<address> {

    }

    
}
