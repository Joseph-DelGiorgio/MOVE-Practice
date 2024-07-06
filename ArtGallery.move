module artwork_gallery::gallery {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // Struct to represent an artwork
    struct Artwork has key, store {
        id: UID,
        creator: address,
        owner: address,
        metadata: vector<u8>,
        price: u64
    }

    // Event to signal the creation of a new artwork
    struct ArtworkCreated has copy, drop {
        id: UID,
        creator: address,
        metadata: vector<u8>
    }

    // Event to signal the purchase of an artwork
    struct ArtworkPurchased has copy, drop {
        id: UID,
        buyer: address,
        price: u64
    }

    // Gallery state to store all artworks
    struct Gallery has key {
        id: UID,
        artworks: Table<u64, Artwork>,
        next_artwork_id: u64
    }

    // Initialize the gallery
    fun init(ctx: &mut TxContext) {
        let gallery = Gallery {
            id: object::new(ctx),
            artworks: table::new(ctx),
            next_artwork_id: 1
        };
        transfer::share_object(gallery);
    }

    // Create a new artwork
    public fun create_artwork(
        gallery: &mut Gallery,
        metadata: vector<u8>,
        price: u64,
        ctx: &mut TxContext
    ) {
        let artwork = Artwork {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            owner: tx_context::sender(ctx),
            metadata,
            price
        };
        let artwork_id = gallery.next_artwork_id;
        table::add(&mut gallery.artworks, artwork_id, artwork);
        gallery.next_artwork_id = gallery.next_artwork_id + 1;
        
        event::emit(ArtworkCreated {
            id: object::uid_to_inner(&artwork.id),
            creator: artwork.creator,
            metadata: artwork.metadata
        });
    }

    // Purchase an artwork
    public fun purchase_artwork(
        gallery: &mut Gallery,
        artwork_id: u64,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let artwork = table::borrow_mut(&mut gallery.artworks, artwork_id);
        assert!(artwork.owner != tx_context::sender(ctx), 0);
        assert!(artwork.price > 0, 0);

        let price = artwork.price;
        let paid = coin::split(payment, price, ctx);
        transfer::public_transfer(paid, artwork.owner);

        artwork.owner = tx_context::sender(ctx);
        artwork.price = 0; // Artwork is no longer for sale

        event::emit(ArtworkPurchased {
            id: object::uid_to_inner(&artwork.id),
            buyer: artwork.owner,
            price: price
        });
    }

    // Set artwork price for sale
    public fun set_artwork_price(
        gallery: &mut Gallery,
        artwork_id: u64,
        price: u64,
        ctx: &mut TxContext
    ) {
        let artwork = table::borrow_mut(&mut gallery.artworks, artwork_id);
        assert!(artwork.owner == tx_context::sender(ctx), 0);
        artwork.price = price;
    }

    // Get artwork details
    public fun get_artwork(gallery: &Gallery, artwork_id: u64): &Artwork {
        table::borrow(&gallery.artworks, artwork_id)
    }
}
