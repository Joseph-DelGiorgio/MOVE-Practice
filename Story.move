module collaborative_story::narrative {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::random;
    use std::string::{Self, String};
    use std::vector;

    // Errors
    const EInsufficientTokens: u64 = 0;
    const EStoryLocked: u64 = 1;
    const EInvalidContribution: u64 = 2;

    // Story state
    const OPEN: u8 = 0;
    const LOCKED: u8 = 1;

    // Structs
    struct StoryBook has key {
        id: UID,
        title: String,
        current_chapter: u64,
        state: u8,
        last_update: u64,
        token_requirement: u64,
    }

    struct Chapter has key, store {
        id: UID,
        number: u64,
        content: String,
        author: address,
        timestamp: u64,
    }

    struct AuthorBadge has key, store {
        id: UID,
        author: address,
        contributions: u64,
    }

    // Events
    struct ChapterAdded has copy, drop {
        book_id: UID,
        chapter_number: u64,
        author: address,
    }

    struct StoryLocked has copy, drop {
        book_id: UID,
        final_chapter: u64,
    }

    // Initialize a new StoryBook
    public entry fun create_story_book(
        title: vector<u8>,
        token_requirement: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let story_book = StoryBook {
            id: object::new(ctx),
            title: string::utf8(title),
            current_chapter: 0,
            state: OPEN,
            last_update: clock::timestamp_ms(clock),
            token_requirement,
        };
        transfer::share_object(story_book);
    }

    // Add a new chapter to the story
    public entry fun add_chapter(
        story_book: &mut StoryBook,
        content: vector<u8>,
        payment: &mut Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(story_book.state == OPEN, EStoryLocked);
        assert!(coin::value(payment) >= story_book.token_requirement, EInsufficientTokens);
        
        // Consume the required tokens
        let burn_amount = coin::split(payment, story_book.token_requirement, ctx);
        transfer::public_transfer(burn_amount, @0x0);

        let author = tx_context::sender(ctx);
        let chapter_number = story_book.current_chapter + 1;
        
        let chapter = Chapter {
            id: object::new(ctx),
            number: chapter_number,
            content: string::utf8(content),
            author,
            timestamp: clock::timestamp_ms(clock),
        };

        dof::add(&mut story_book.id, chapter_number, chapter);
        story_book.current_chapter = chapter_number;
        story_book.last_update = clock::timestamp_ms(clock);

        // Update or create AuthorBadge
        if (dof::exists_(&story_book.id, author)) {
            let badge: &mut AuthorBadge = dof::borrow_mut(&mut story_book.id, author);
            badge.contributions = badge.contributions + 1;
        } else {
            let new_badge = AuthorBadge {
                id: object::new(ctx),
                author,
                contributions: 1,
            };
            dof::add(&mut story_book.id, author, new_badge);
        }

        // Emit event
        sui::event::emit(ChapterAdded {
            book_id: object::uid_to_inner(&story_book.id),
            chapter_number,
            author,
        });

        // Randomly lock the story
        if (should_lock_story(clock, ctx)) {
            story_book.state = LOCKED;
            sui::event::emit(StoryLocked {
                book_id: object::uid_to_inner(&story_book.id),
                final_chapter: chapter_number,
            });
        }
    }

    // Helper function to determine if the story should be locked
    fun should_lock_story(clock: &Clock, ctx: &mut TxContext): bool {
        let random_value = random::ctx(ctx) % 100;
        random_value < 10 // 10% chance to lock the story
    }

    // View functions
    public fun get_story_info(story_book: &StoryBook): (String, u64, u8, u64, u64) {
        (
            story_book.title,
            story_book.current_chapter,
            story_book.state,
            story_book.last_update,
            story_book.token_requirement
        )
    }

    public fun get_chapter_content(story_book: &StoryBook, chapter_number: u64): String {
        let chapter: &Chapter = dof::borrow(&story_book.id, chapter_number);
        chapter.content
    }

    public fun get_author_contributions(story_book: &StoryBook, author: address): u64 {
        if (dof::exists_(&story_book.id, author)) {
            let badge: &AuthorBadge = dof::borrow(&story_book.id, author);
            badge.contributions
        } else {
            0
        }
    }
}
