module decentralized_music::collab_studio {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::dynamic_object_field as dof;
    use std::string::{Self, String};
    use std::vector;

    // Errors
    const EInsufficientFunds: u64 = 0;
    const ETrackNotFound: u64 = 1;
    const EUnauthorized: u64 = 2;
    const EInvalidRoyaltyShare: u64 = 3;
    const ECollaborationClosed: u64 = 4;

    // Structs
    struct MusicPlatform has key {
        id: UID,
        tracks: Table<ID, Track>,
        platform_fee: u64, // in basis points (e.g., 250 = 2.5%)
    }

    struct Track has key, store {
        id: UID,
        title: String,
        primary_artist: address,
        collaborators: vector<address>,
        royalty_shares: Table<address, u64>, // in basis points
        genre: String,
        total_streams: u64,
        revenue: Coin<SUI>,
        open_for_collab: bool,
        stem_count: u64,
    }

    struct Stem has key, store {
        id: UID,
        track_id: ID,
        creator: address,
        stem_type: String, // e.g., "vocals", "guitar", "drums"
        ipfs_hash: String, // IPFS hash of the audio file
    }

    struct StreamToken has key, store {
        id: UID,
        track_id: ID,
    }

    // Events
    struct TrackCreated has copy, drop {
        track_id: ID,
        title: String,
        primary_artist: address,
    }

    struct CollaborationAdded has copy, drop {
        track_id: ID,
        collaborator: address,
        royalty_share: u64,
    }

    struct StemAdded has copy, drop {
        track_id: ID,
        stem_id: ID,
        creator: address,
        stem_type: String,
    }

    struct StreamRegistered has copy, drop {
        track_id: ID,
        listener: address,
    }

    // Initialize the music platform
    fun init(ctx: &mut TxContext) {
        let platform = MusicPlatform {
            id: object::new(ctx),
            tracks: table::new(ctx),
            platform_fee: 250, // 2.5%
        };
        transfer::share_object(platform);
    }

    // Create a new track
    public entry fun create_track(
        platform: &mut MusicPlatform,
        title: vector<u8>,
        genre: vector<u8>,
        ctx: &mut TxContext
    ) {
        let track = Track {
            id: object::new(ctx),
            title: string::utf8(title),
            primary_artist: tx_context::sender(ctx),
            collaborators: vector::empty(),
            royalty_shares: table::new(ctx),
            genre: string::utf8(genre),
            total_streams: 0,
            revenue: coin::zero(ctx),
            open_for_collab: true,
            stem_count: 0,
        };

        let track_id = object::id(&track);
        table::add(&mut platform.tracks, track_id, track);

        // Set initial royalty share for primary artist
        table::add(&mut table::borrow_mut(&mut platform.tracks, track_id).royalty_shares, tx_context::sender(ctx), 10000); // 100%

        event::emit(TrackCreated {
            track_id,
            title: string::utf8(title),
            primary_artist: tx_context::sender(ctx),
        });
    }

    // Add a collaborator to a track
    public entry fun add_collaborator(
        platform: &mut MusicPlatform,
        track_id: ID,
        collaborator: address,
        royalty_share: u64,
        ctx: &mut TxContext
    ) {
        let track = table::borrow_mut(&mut platform.tracks, track_id);
        assert!(tx_context::sender(ctx) == track.primary_artist, EUnauthorized);
        assert!(track.open_for_collab, ECollaborationClosed);
        assert!(royalty_share > 0 && royalty_share < 10000, EInvalidRoyaltyShare);

        vector::push_back(&mut track.collaborators, collaborator);
        table::add(&mut track.royalty_shares, collaborator, royalty_share);

        // Adjust primary artist's share
        let primary_share = table::borrow_mut(&mut track.royalty_shares, track.primary_artist);
        *primary_share = *primary_share - royalty_share;

        event::emit(CollaborationAdded {
            track_id,
            collaborator,
            royalty_share,
        });
    }

    // Add a stem to a track
    public entry fun add_stem(
        platform: &mut MusicPlatform,
        track_id: ID,
        stem_type: vector<u8>,
        ipfs_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let track = table::borrow_mut(&mut platform.tracks, track_id);
        assert!(track.open_for_collab, ECollaborationClosed);
        assert!(tx_context::sender(ctx) == track.primary_artist || vector::contains(&track.collaborators, &tx_context::sender(ctx)), EUnauthorized);

        let stem = Stem {
            id: object::new(ctx),
            track_id,
            creator: tx_context::sender(ctx),
            stem_type: string::utf8(stem_type),
            ipfs_hash: string::utf8(ipfs_hash),
        };

        let stem_id = object::id(&stem);
        dof::add(&mut track.id, stem_id, stem);
        track.stem_count = track.stem_count + 1;

        event::emit(StemAdded {
            track_id,
            stem_id,
            creator: tx_context::sender(ctx),
            stem_type: string::utf8(stem_type),
        });
    }

    // Register a stream (simplified)
    public entry fun register_stream(
        platform: &mut MusicPlatform,
        track_id: ID,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let stream_cost = 1_000_000; // 0.001 SUI per stream
        assert!(coin::value(payment) >= stream_cost, EInsufficientFunds);

        let track = table::borrow_mut(&mut platform.tracks, track_id);
        track.total_streams = track.total_streams + 1;

        let stream_payment = coin::split(payment, stream_cost, ctx);
        coin::join(&mut track.revenue, stream_payment);

        // Create and transfer stream token (could be used for listener rewards)
        let stream_token = StreamToken {
            id: object::new(ctx),
            track_id,
        };
        transfer::transfer(stream_token, tx_context::sender(ctx));

        event::emit(StreamRegistered {
            track_id,
            listener: tx_context::sender(ctx),
        });
    }

    // Distribute royalties
    public entry fun distribute_royalties(
        platform: &mut MusicPlatform,
        track_id: ID,
        ctx: &mut TxContext
    ) {
        let track = table::borrow_mut(&mut platform.tracks, track_id);
        let total_revenue = coin::value(&track.revenue);
        let platform_fee_amount = (total_revenue * platform.platform_fee) / 10000;

        let distribution_amount = total_revenue - platform_fee_amount;
        let platform_fee_coin = coin::split(&mut track.revenue, platform_fee_amount, ctx);
        transfer::public_transfer(platform_fee_coin, tx_context::sender(ctx)); // Transfer to platform owner

        let i = 0;
        let collaborators = *&track.collaborators; // Create a copy to avoid borrow checker issues
        vector::push_back(&mut collaborators, track.primary_artist);

        while (i < vector::length(&collaborators)) {
            let collaborator = *vector::borrow(&collaborators, i);
            let share = *table::borrow(&track.royalty_shares, collaborator);
            let royalty_amount = (distribution_amount * share) / 10000;

            if (royalty_amount > 0) {
                let royalty_payment = coin::split(&mut track.revenue, royalty_amount, ctx);
                transfer::public_transfer(royalty_payment, collaborator);
            };

            i = i + 1;
        };
    }

    // View functions
    public fun get_track_info(platform: &MusicPlatform, track_id: ID): (String, address, u64, u64, bool, u64) {
        let track = table::borrow(&platform.tracks, track_id);
        (track.title, track.primary_artist, track.total_streams, coin::value(&track.revenue), track.open_for_collab, track.stem_count)
    }

    public fun get_collaborator_share(platform: &MusicPlatform, track_id: ID, collaborator: address): u64 {
        let track = table::borrow(&platform.tracks, track_id);
        *table::borrow(&track.royalty_shares, collaborator)
    }
}
