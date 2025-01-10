module gym::weights_manager {

    struct Equipment has key {
        id: u64,
        name: vector<u8>,
        is_available: bool,
    }

    struct Reservation has key {
        user: address,
        equipment_id: u64,
        reserved_until: u64, // Timestamp
    }

    public fun create_equipment(
        id: u64,
        name: vector<u8>,
        ctx: &mut TxContext
    ): Equipment {
        Equipment { id, name, is_available: true }
    }

    public fun reserve_equipment(
        user: address,
        equipment_id: u64,
        duration: u64,
        ctx: &mut TxContext
    ): Reservation acquires Equipment {
        let equipment = borrow_global_mut<Equipment>(equipment_id);
        assert!(equipment.is_available, 1);
        equipment.is_available = false;

        Reservation {
            user,
            equipment_id,
            reserved_until: timestamp_now() + duration,
        }
    }

    public fun release_equipment(
        reservation_id: u64,
        ctx: &mut TxContext
    ) acquires Equipment {
        let reservation = borrow_global<Reservation>(reservation_id);
        let equipment = borrow_global_mut<Equipment>(reservation.equipment_id);
        
        assert!(timestamp_now() >= reservation.reserved_until, 2);
        
        equipment.is_available = true;
        move_to(ctx.sender(), reservation);
    }
}
