module 0x1::weighted_voting {

    use sui::event;
    use sui::coin::{Coin, TreasuryCap, transfer};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::vector;

    struct Proposal has key {
        id: u64,
        description: String,
        votes_for: u64,
        votes_against: u64,
    }

    struct VotingSystem has key {
        id: UID,
        proposals: vector::Vector<Proposal>,
        total_supply: u64,
    }

    public entry fun init_voting_system(ctx: &mut TxContext): VotingSystem {
        let proposals = vector::empty<Proposal>();
        VotingSystem {
            id: object::new<UID>(ctx),
            proposals,
            total_supply: 0,
        }
    }

    public entry fun create_proposal(voting_system: &mut VotingSystem, description: String, ctx: &mut TxContext) {
        let proposal = Proposal {
            id: ctx.next_id(),
            description,
            votes_for: 0,
            votes_against: 0,
        };
        vector::push_back(&mut voting_system.proposals, proposal);
    }

    public entry fun vote(
        voting_system: &mut VotingSystem,
        proposal_id: u64,
        vote_for: bool,
        amount: u64,
        coin: Coin,
        ctx: &mut TxContext
    ) {
        let index = find_proposal(&voting_system.proposals, proposal_id);
        let proposal = &mut vector::borrow_mut(&mut voting_system.proposals, index);
        if (vote_for) {
            proposal.votes_for += amount;
        } else {
            proposal.votes_against += amount;
        }
        voting_system.total_supply += amount;

        // Transfer coins to a burn address or hold them in the system
        transfer(coin, @0x0, ctx);
    }

    fun find_proposal(proposals: &vector::Vector<Proposal>, proposal_id: u64): u64 {
        let len = vector::length(proposals);
        let mut i = 0;
        while (i < len) {
            let proposal = &vector::borrow(proposals, i);
            if (proposal.id == proposal_id) {
                return i;
            }
            i = i + 1;
        }
        assert!(false, 0); // Proposal not found
        0 // Default return to satisfy the function signature, will never reach here due to assert
    }

    public fun get_proposal(voting_system: &VotingSystem, proposal_id: u64): &Proposal {
        let index = find_proposal(&voting_system.proposals, proposal_id);
        &vector::borrow(&voting_system.proposals, index)
    }

    public fun total_votes(voting_system: &VotingSystem, proposal_id: u64): u64 {
        let proposal = get_proposal(voting_system, proposal_id);
        proposal.votes_for + proposal.votes_against
    }

    public fun winning_option(voting_system: &VotingSystem, proposal_id: u64): bool {
        let proposal = get_proposal(voting_system, proposal_id);
        proposal.votes_for > proposal.votes_against
    }
}
