module 0xcafe::spider_nest {
    use std::vector;

    struct SpiderDna has key {
        dna_digits: u64,
        dna_modulus: u64,
    }

    struct Spider has store {
        dna: u64,
    }

    struct SpiderSwarm has key {
        spiders: vector<Spider>,
    }

    fun init_module(cafe_signer: &signer) {
        let dna_digits = 10;
        let dna_modulus = 10 ^ dna_digits;
        move_to(cafe_signer, SpiderDna {
            dna_digits,
            dna_modulus: (dna_modulus as u256),
        });
        move_to(cafe_signer, SpiderSwarm {
            spiders: vector[],
        });
    }

    public fun spawn_spider(dna: u64): Spider {
        Spider {
            dna,
        }
    }

    public fun get_dna_digits(): u64 acquires SpiderDna {
        borrow_global<SpiderDna>(@0xcafe).dna_digits
    }

    public fun set_dna_digits(new_dna_digits: u64) acquires SpiderDna {
        let spider_dna = borrow_global_mut<SpiderDna>(@0xcafe);
        spider_dna.dna_digits = new_dna_digits;
    }
}
