module cart_barn::electricity_manager {

    struct ChargingSlot has key {
        id: u64,
        is_occupied: bool,
    }

    public fun initialize_slots(num_slots: u64): vector<ChargingSlot> {
        let mut slots = vector::empty<ChargingSlot>();
        let mut i = 0;
        while (i < num_slots) {
            let slot = ChargingSlot { id: i, is_occupied: false };
            vector::push_back(&mut slots, slot);
            i = i + 1;
        };
        slots
    }

    public fun occupy_slot(slots: &mut vector<ChargingSlot>, slot_id: u64): bool {
        let slot = &mut vector::borrow_mut(slots, slot_id);
        if (!slot.is_occupied) {
            slot.is_occupied = true;
            true
        } else {
            false
        }
    }

    public fun release_slot(slots: &mut vector<ChargingSlot>, slot_id: u64): bool {
        let slot = &mut vector::borrow_mut(slots, slot_id);
        if (slot.is_occupied) {
            slot.is_occupied = false;
            true
        } else {
            false
        }
    }
}
