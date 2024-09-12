module collab::music_platform {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::table::{Self, Table};
    use std::vector;
    use std::string::{Self, String};

    // Error codes
    const EINVALID_CONTRIBUTION: u64 = 0;
    const EUNAUTHORIZED: u64 = 1;
    const ESONG_NOT_FINALIZED: u64 = 2;

    struct MusicPlatform has key {
        id: UID,
        songs: Table<ID, Song>,
        royalties: Balance<SUI>,
    }

    struct Song has key, store {
        id: UID,
        title: String,
        creator: address,
        contributors: vector<address>,
        tracks: vector<Track>,
        finalized: bool,
    }

    struct Track has store {
        contributor: address,
        instrument: String,
        ipfs_hash: String,
    }

    struct Collaboration has copy, drop {
        song_id: ID,
        contributor: address,
        instrument: String,
    }

    struct SongFinalized has copy, drop {
        song_id: ID,
        title: String,
        contributors: vector<address>,
    }

    fun init(ctx: &mut TxContext) {
        let platform = MusicPlatform {
            id: object::new(ctx),
            songs: table::new(ctx),
            royalties: balance::zero(),
        };
        transfer::share_object(platform);
    }

    public entry fun create_song(
        platform: &mut MusicPlatform,
        title: vector<u8>,
        ctx: &mut TxContext
    ) {
        let song = Song {
            id: object::new(ctx),
            title: string::utf8(title),
            creator: tx_context::sender(ctx),
            contributors: vector::singleton(tx_context::sender(ctx)),
            tracks: vector::empty(),
            finalized: false,
        };
        let song_id = object::id(&song);
        table::add(&mut platform.songs, song_id, song);
    }

    public entry fun add_track(
        platform: &mut MusicPlatform,
        song_id: ID,
        instrument: vector<u8>,
        ipfs_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let song = table::borrow_mut(&mut platform.songs, song_id);
        assert!(!song.finalized, ESONG_NOT_FINALIZED);

        let track = Track {
            contributor: tx_context::sender(ctx),
            instrument: string::utf8(instrument),
            ipfs_hash: string::utf8(ipfs_hash),
        };
        vector::push_back(&mut song.tracks, track);
        if (!vector::contains(&song.contributors, &tx_context::sender(ctx))) {
            vector::push_back(&mut song.contributors, tx_context::sender(ctx));
        };

        event::emit(Collaboration {
            song_id,
            contributor: tx_context::sender(ctx),
            instrument: string::utf8(instrument),
        });
    }

    public entry fun finalize_song(
        platform: &mut MusicPlatform,
        song_id: ID,
        ctx: &mut TxContext
    ) {
        let song = table::borrow_mut(&mut platform.songs, song_id);
        assert!(song.creator == tx_context::sender(ctx), EUNAUTHORIZED);
        assert!(!song.finalized, ESONG_NOT_FINALIZED);

        song.finalized = true;

        event::emit(SongFinalized {
            song_id,
            title: song.title,
            contributors: song.contributors,
        });
    }

    public entry fun distribute_royalties(
        platform: &mut MusicPlatform,
        song_id: ID,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let song = table::borrow(&platform.songs, song_id);
        assert!(song.finalized, ESONG_NOT_FINALIZED);

        let total_contributors = vector::length(&song.contributors);
        let share = coin::value(&amount) / total_contributors;

        let i = 0;
        while (i < total_contributors) {
            let contributor = *vector::borrow(&song.contributors, i);
            let payment = coin::split(&mut amount, share, ctx);
            transfer::public_transfer(payment, contributor);
            i = i + 1;
        };

        // Any remaining balance (due to rounding) goes to the platform
        if (coin::value(&amount) > 0) {
            balance::join(&mut platform.royalties, coin::into_balance(amount));
        } else {
            coin::destroy_zero(amount);
        };
    }
}
