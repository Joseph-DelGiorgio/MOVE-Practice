module 0xcafe::spider_nest {
    struct SpiderDna has key {
        dna_digits: u64,
        // Update this to be u256
        dna_modulus: u256,
    }

    fun init_module(cafe_signer: &signer) {
        let dna_digits = 10;
        // dna_modulus will be a u64 as dna_digits is of type u64.
        let dna_modulus = 10 ^ dna_digits;
        move_to(cafe_signer, SpiderDna {
            dna_digits,
	// Fix this
            dna_modulus: (dna_modulus as u256),
        });
    }
}
