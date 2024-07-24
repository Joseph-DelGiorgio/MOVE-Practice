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
    const EInsufficientStreamTokens: u64 = 5;
    const EInvalidTier: u64 = 6;

    // Structs
    struct MusicPlatform has key {
        id: UID,
        tracks: Table<ID, Track>,
        platform_fee: u64,
        listener_profiles: Table<address, ListenerProfile>,
        rewards_pool: Coin<SUI>,
        rewards_rate: u64,
        genre_discovery_bonus: u64,
    }

    struct Track has key, store {
        id: UID,
        title: String,
        primary_artist: address,
        collaborators: vector<address>,
        royalty_shares: Table<address, u64>,
        genre: String,
        total_streams: u64,
        revenue: Coin<SUI>,
        open_for_collab: bool,
        stem_count: u64,
        feedback_count: u64,
        creation_time: u64,
    }

    struct Stem has key, store {
        id: UID,
        track_id: ID,
        creator: address,
        stem_type: String,
        ipfs_hash: String,
    }

    struct StreamToken has key, store {
        id: UID,
        track_id: ID,
        timestamp: u64,
    }

    struct ListenerProfile has key, store {
        id: UID,
        address: address,
        total_streams: u64,
        rewards_balance: Coin<SUI>,
        streamed_genres: Table<String, bool>,
        tier: u8,
        last_stream: u64,
        streak_days: u64,
    }

    struct Feedback has key, store {
        id: UID,
        track_id: ID,
        author: address,
        content: String,
        timestamp: u64,
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

    struct RewardsClaimed has copy, drop {
        listener: address,
        amount: u64,
    }

    struct FeedbackAdded has copy, drop {
        track_id: ID,
        author: address,
    }

    struct ListenerTierUpgraded has copy, drop {
        listener: address,
        new_tier: u8,
    }

    // Initialize the music platform
    fun init(ctx: &mut TxContext) {
        let platform = MusicPlatform {
            id: object::new(ctx),
            tracks: table::new(ctx),
            platform_fee: 250, // 2.5%
            listener_profiles: table::new(ctx),
            rewards_pool: coin::zero(ctx),
            rewards_rate: 1_000_000, // 0.001 SUI per 1000 streams
            genre_discovery_bonus: 500_000, // 0.0005 SUI bonus for new genre
        };
        transfer::share_object(platform);
    }

    // Create a new track
    public entry fun create_track(
        platform: &mut MusicPlatform,
        title: vector<u8>,
        genre: vector<u8>,
        clock: &Clock,
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
            feedback_count: 0,
            creation_time: clock::timestamp_ms(clock),
        };

        let track_id = object::id(&track);
        table::add(&mut platform.tracks, track_id, track);
        table::add(&mut table::borrow_mut(&mut platform.tracks, track_id).royalty_shares, tx_context::sender(ctx), 10000);

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

    // Register a stream
    public entry fun register_stream(
        platform: &mut MusicPlatform,
        track_id: ID,
        payment: &mut Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let stream_cost = 1_000_000; // 0.001 SUI per stream
        assert!(coin::value(payment) >= stream_cost, EInsufficientFunds);

        let track = table::borrow_mut(&mut platform.tracks, track_id);
        track.total_streams = track.total_streams + 1;

        let stream_payment = coin::split(payment, stream_cost, ctx);
        coin::join(&mut track.revenue, stream_payment);

        let stream_token = StreamToken {
            id: object::new(ctx),
            track_id,
            timestamp: clock::timestamp_ms(clock),
        };
        transfer::transfer(stream_token, tx_context::sender(ctx));

        let listener = tx_context::sender(ctx);
        if (!table::contains(&platform.listener_profiles, listener)) {
            table::add(&mut platform.listener_profiles, listener, ListenerProfile {
                id: object::new(ctx),
                address: listener,
                total_streams: 0,
                rewards_balance: coin::zero(ctx),
                streamed_genres: table::new(ctx),
                tier: 1,
                last_stream: 0,
                streak_days: 0,
            });
        };
        
        let profile = table::borrow_mut(&mut platform.listener_profiles, listener);
        profile.total_streams = profile.total_streams + 1;
        
        // Update streak and check for tier upgrade
        let current_time = clock::timestamp_ms(clock);
        if (current_time - profile.last_stream >= 86400000) { // 24 hours in milliseconds
            profile.streak_days = profile.streak_days + 1;
            if (profile.streak_days % 7 == 0 && profile.tier < 5) {
                profile.tier = profile.tier + 1;
                event::emit(ListenerTierUpgraded {
                    listener,
                    new_tier: profile.tier,
                });
            }
        } else if (current_time - profile.last_stream >= 172800000) { // 48 hours in milliseconds
            profile.streak_days = 1;
        };
        profile.last_stream = current_time;

        // Check for genre discovery bonus
        if (!table::contains(&profile.streamed_genres, track.genre)) {
            table::add(&mut profile.streamed_genres, track.genre, true);
            let bonus = coin::split(&mut platform.rewards_pool, platform.genre_discovery_bonus, ctx);
            coin::join(&mut profile.rewards_balance, bonus);
        };

        event::emit(StreamRegistered {
            track_id,
            listener,
        });
    }

    // Claim listener rewards
    public entry fun claim_listener_rewards(
        platform: &mut MusicPlatform,
        ctx: &mut TxContext
    ) {
        let listener = tx_context::sender(ctx);
        assert!(table::contains(&platform.listener_profiles, listener), EUnauthorized);

        let profile = table::borrow_mut(&mut platform.listener_profiles, listener);
        let streams_to_reward = profile.total_streams;
        let tier_multiplier = (profile.tier as u64) * 2;
        let reward_amount = (streams_to_reward * platform.rewards_rate * tier_multiplier) / 1000;

        assert!(coin::value(&platform.rewards_pool) >= reward_amount, EInsufficientFunds);

        let reward = coin::split(&mut platform.rewards_pool, reward_amount, ctx);
        coin::join(&mut profile.rewards_balance, reward);

        profile.total_streams = 0; // Reset stream count after claiming rewards

        event::emit(RewardsClaimed {
            listener,
            amount: reward_amount,
        });
    }

    // Withdraw listener rewards
    public entry fun withdraw_listener_rewards(
        platform: &mut MusicPlatform,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let listener = tx_context::sender(ctx);
        assert!(table::contains(&platform.listener_profiles, listener), EUnauthorized);

        let profile = table::borrow_mut(&mut platform.listener_profiles, listener);
        assert!(coin::value(&profile.rewards_balance) >= amount, EInsufficientFunds);

        let withdrawal = coin::split(&mut profile.rewards_balance, amount, ctx);
        transfer::public_transfer(withdrawal, listener);
    }

    // Add funds to the rewards pool
    public entry fun add_to_rewards_pool(
        platform: &mut MusicPlatform,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= amount, EInsufficientFunds);
        let rewards_payment = coin::split(payment, amount, ctx);
        coin::join(&mut platform.rewards_pool, rewards_payment);
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
        transfer::public_transfer(platform_fee_coin, tx_context::sender(ctx));

        let i = 0;
        let collaborators = *&track.collaborators;
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

    // Add feedback to a track
    public entry fun add_feedback(
        platform: &mut MusicPlatform,
        track_id: ID,
        content: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&platform.tracks, track_id), ETrackNotFound);
        
        let feedback = Feedback {
            id: object::new(ctx),
            track_id,
            author: tx_context::sender(ctx),
            content: string::utf8(content),
            timestamp: clock::timestamp_ms(clock),
        };

        let track = table::borrow_mut(&mut platform.tracks, track_id);
        dof::add(&mut track.id, object::id(&feedback), feedback);
        track.feedback_count = track.feedback_count + 1;

        event::emit(FeedbackAdded {
            track_id,
            author: tx_context::sender(ctx),
        });
    }

    // View functions
    public fun get_track_info(platform: &MusicPlatform, track_id: ID): (String, address, u64, u64, bool, u64, u64, u64) {
        let track = table::borrow(&platform.tracks, track_id);
        (track.title, track.primary_artist, track.total_streams, coin::value(&track.revenue), track.open_for_collab, track.stem_count, track.feedback_count, track.creation_time)
    }

    public fun get_collaborator_share(platform: &MusicPlatform, track_id: ID, collaborator: address): u64 {
        let track = table::borrow(&platform.tracks, track_id);
        *table::borrow(&track.royalty_shares, collaborator)
    }

    public fun get_listener_profile(platform: &MusicPlatform, listener: address): (u64, u64, u8, u64, u64) {
        let profile = table::borrow(&platform.listener_profiles, listener);
        (profile.total_streams, coin::value(&profile.rewards_balance), profile.tier, profile.last_stream, profile.streak_days)
    }

    public fun get_rewards_pool_balance(platform: &MusicPlatform): u64 {
        coin::value(&platform.rewards_pool)
    }

    public fun get_platform_stats(platform: &MusicPlatform): (u64, u64, u64) {
        (platform.platform_fee, platform.rewards_rate, platform.genre_discovery_bonus)
    }

    public fun get_stem_info(platform: &MusicPlatform, track_id: ID, stem_id: ID): (address, String, String) {
        let track = table::borrow(&platform.tracks, track_id);
        let stem = dof::borrow<ID, Stem>(&track.id, stem_id);
        (stem.creator, stem.stem_type, stem.ipfs_hash)
    }

    public fun get_feedback(platform: &MusicPlatform, track_id: ID, feedback_id: ID): (address, String, u64) {
        let track = table::borrow(&platform.tracks, track_id);
        let feedback = dof::borrow<ID, Feedback>(&track.id, feedback_id);
        (feedback.author, feedback.content, feedback.timestamp)
    }
}


/*

This final version of the decentralized music collaboration and royalty distribution platform includes all the improvements and features we've discussed. Here's a summary of the key features:

Collaborative Track Creation: Artists can create tracks, add collaborators, and set custom royalty shares.
Stem-based Collaboration: Collaborators can add individual stems to a track, stored with IPFS hashes.
Dynamic Royalty Distribution: Royalties are automatically distributed based on pre-set shares.
Listener Rewards System: Listeners earn rewards for streaming, with bonuses for discovering new genres.
Tiered Listener System: Listeners can upgrade their tier by maintaining a streak, earning higher rewards.
Feedback Mechanism: Listeners can provide feedback on tracks, potentially influencing the creative process.
Platform Fee and Rewards Pool: A small platform fee is collected, and a rewards pool is maintained for listener incentives.
Stream Tokens: Listeners receive tokens for each stream, which could be used for future features.
Advanced View Functions: Comprehensive functions to view track info, listener profiles, platform stats, stem info, and feedback.

This implementation creates a rich ecosystem for music creation, collaboration, and consumption. It incentivizes both artists and listeners, promotes discovery of new music, and ensures fair compensation for all parties involved.
Some potential future enhancements could include:

Governance system for adjusting platform parameters
NFT creation for special releases or limited edition tracks
Integration with decentralized streaming platforms
Collaboration challenges or themed events
Cross-platform loyalty program integration

This smart contract provides a solid foundation for a decentralized music platform that could revolutionize how music is created, shared, and monetized in the web3 era.

*/

