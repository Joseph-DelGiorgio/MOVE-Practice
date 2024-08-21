module 0xcafe::spider_nest {
     use aptos_framework::account;
     use aptos_framework::event;
     use std::vector;

    struct SpiderDna has key {
        dna_digits: u64,
        dna_modulus: u64,
    }

    struct Spider has store {
        dna: u64,
    }

    #[event]
    struct SpawnSpiderEvent has drop, store {
        dna: u64,
    }
    struct SpiderSwarm has key {
        spiders: vector<Spider>,
    }

    fun init_module(cafe_signer: &signer) {
        let dna_modulus = 10 ^ 10;
        move_to(cafe_signer, SpiderDna {
            dna_digits: 10,
            dna_modulus,
        });
        move_to(cafe_signer, SpiderSwarm {
            spiders: vector[],
        });
    }

    fun spawn_spider(dna: u64) acquires SpiderSwarm {
        let spider = Spider {
            dna,
        };
        let spider_swarm = borrow_global_mut<SpiderSwarm>(@0xcafe);
        vector::push_back(&mut spider_swarm.spiders, spider);

        event::emit(SpawnSpiderEvent {
            dna,
        });
    }

    public fun get_dna_digits(): u64 acquires SpiderDna {
        borrow_global<SpiderDna>(@0xcafe).dna_digits
    }

    public fun set_dna_digits(new_dna_digits: u64) acquires SpiderDna {
        let spider_dna = borrow_global_mut<SpiderDna>(@0xcafe);
        spider_dna.dna_digits = new_dna_digits;
    }

    public fun get_first_spider_dna(): u64 acquires SpiderSwarm {
        let spider_swarm = borrow_global<SpiderSwarm>(@0xcafe);
        let first_spider = vector::borrow(&spider_swarm.spiders, 0);
        first_spider.dna
    }
}


