module music_royalties::distribution {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    use std::vector;

    // Structs
    struct Song has key, store {
        id: UID,
        title: vector<u8>,
        artist: address,
        collaborators: vector<address>,
        royalty_splits: vector<u64>, // Percentages, should sum to 100
        price: u64,
        streams: u64
    }

    struct MusicPlatform has key {
        id: UID,
        songs: Table<UID, Song>,
        royalties: Table<address, Balance<SUI>>,
        stream_price: u64
    }

    struct SongToken has key, store {
        id: UID,
        song_id: UID,
        owner: address
    }

    // Events
    struct SongUploaded has copy, drop {
        song_id: UID,
        title: vector<u8>,
        artist: address
    }

    struct SongPurchased has copy, drop {
        song_id: UID,
        buyer: address
    }

    struct SongStreamed has copy, drop {
        song_id: UID,
        listener: address
    }

    // Error codes
    const ERR_INVALID_ROYALTY_SPLIT: u64 = 1;
    const ERR_INSUFFICIENT_PAYMENT: u64 = 2;

    // Initialize the music platform
    fun init(ctx: &mut TxContext) {
        let platform = MusicPlatform {
            id: object::new(ctx),
            songs: table::new(ctx),
            royalties: table::new(ctx),
            stream_price: 1 // 1 SUI per stream, adjust as needed
        };
        transfer::share_object(platform);
    }

    // Upload a new song
    public fun upload_song(
        platform: &mut MusicPlatform,
        title: vector<u8>,
        collaborators: vector<address>,
        royalty_splits: vector<u64>,
        price: u64,
        ctx: &mut TxContext
    ) {
        // Ensure royalty splits sum to 100
        let total_split = 0;
        let i = 0;
        while (i < vector::length(&royalty_splits)) {
            total_split = total_split + *vector::borrow(&royalty_splits, i);
            i = i + 1;
        };
        assert!(total_split == 100, ERR_INVALID_ROYALTY_SPLIT);

        let song_id = object::new(ctx);
        let song = Song {
            id: object::new(ctx),
            title,
            artist: tx_context::sender(ctx),
            collaborators,
            royalty_splits,
            price,
            streams: 0
        };

        table::add(&mut platform.songs, object::uid_to_inner(&song.id), song);

        event::emit(SongUploaded {
            song_id: object::uid_to_inner(&song.id),
            title,
            artist: tx_context::sender(ctx)
        });
    }

    // Purchase a song
    public fun purchase_song(
        platform: &mut MusicPlatform,
        song_id: UID,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let song = table::borrow(&platform.songs, object::uid_to_inner(&song_id));
        assert!(coin::value(payment) >= song.price, ERR_INSUFFICIENT_PAYMENT);

        // Transfer payment and create SongToken
        let paid = coin::split(payment, song.price, ctx);
        distribute_royalties(platform, &song, coin::into_balance(paid));

        let song_token = SongToken {
            id: object::new(ctx),
            song_id: object::uid_to_inner(&song_id),
            owner: tx_context::sender(ctx)
        };
        transfer::transfer(song_token, tx_context::sender(ctx));

        event::emit(SongPurchased {
            song_id: object::uid_to_inner(&song_id),
            buyer: tx_context::sender(ctx)
        });
    }

    // Stream a song
    public fun stream_song(
        platform: &mut MusicPlatform,
        song_id: UID,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= platform.stream_price, ERR_INSUFFICIENT_PAYMENT);

        let song = table::borrow_mut(&mut platform.songs, object::uid_to_inner(&song_id));
        song.streams = song.streams + 1;

        let paid = coin::split(payment, platform.stream_price, ctx);
        distribute_royalties(platform, song, coin::into_balance(paid));

        event::emit(SongStreamed {
            song_id: object::uid_to_inner(&song_id),
            listener: tx_context::sender(ctx)
        });
    }

    // Distribute royalties to collaborators
    fun distribute_royalties(platform: &mut MusicPlatform, song: &Song, payment: Balance<SUI>) {
        let total_amount = balance::value(&payment);
        let i = 0;
        while (i < vector::length(&song.collaborators)) {
            let collaborator = *vector::borrow(&song.collaborators, i);
            let split = *vector::borrow(&song.royalty_splits, i);
            let amount = (total_amount * split) / 100;

            if (!table::contains(&platform.royalties, collaborator)) {
                table::add(&mut platform.royalties, collaborator, balance::zero<SUI>());
            };
            let collab_balance = table::borrow_mut(&mut platform.royalties, collaborator);
            balance::join(collab_balance, balance::split(&mut payment, amount));

            i = i + 1;
        };
        // Any remaining dust goes to the main artist
        if (balance::value(&payment) > 0) {
            let artist_balance = table::borrow_mut(&mut platform.royalties, song.artist);
            balance::join(artist_balance, payment);
        };
    }

    // Withdraw accumulated royalties
    public fun withdraw_royalties(
        platform: &mut MusicPlatform,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&platform.royalties, sender), 0);

        let royalties = table::borrow_mut(&mut platform.royalties, sender);
        let amount = balance::value(royalties);
        coin::from_balance(balance::split(royalties, amount), ctx)
    }

    // Getters
    public fun get_song_info(platform: &MusicPlatform, song_id: UID): &Song {
        table::borrow(&platform.songs, object::uid_to_inner(&song_id))
    }

    public fun get_royalty_balance(platform: &MusicPlatform, address: address): u64 {
        if (table::contains(&platform.royalties, address)) {
            balance::value(table::borrow(&platform.royalties, address))
        } else {
            0
        }
    }
}
