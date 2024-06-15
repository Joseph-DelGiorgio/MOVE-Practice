module library::LibrarySystem {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::bag::{Bag, Self};
    use sui::transfer;
    use sui::vector;

    /// Error codes
    const E_NOT_OWNER: u64 = 1;
    const E_BOOK_NOT_AVAILABLE: u64 = 2;
    const E_BOOK_ALREADY_BORROWED: u64 = 3;

    /// A book structure
    struct Book has key, store {
        id: UID,
        title: vector<u8>,
        author: vector<u8>,
        is_borrowed: bool,
        borrower: address,
    }

    /// The main Library System structure
    struct LibrarySystem has key {
        id: UID,
        books: Bag<UID, Book>,
    }

    /// Create a new LibrarySystem instance
    public entry fun create_library_system(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let books = bag::new(ctx);
        transfer::share_object(LibrarySystem {
            id,
            books,
        })
    }

    /// Add a new book to the library
    public entry fun add_book(
        system: &mut LibrarySystem,
        title: vector<u8>,
        author: vector<u8>,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let book = Book {
            id,
            title,
            author,
            is_borrowed: false,
            borrower: tx_context::sender(ctx),
        };
        bag::add(&mut system.books, id, book);
    }

    /// Borrow a book from the library
    public entry fun borrow_book(
        system: &mut LibrarySystem,
        book_id: UID,
        ctx: &mut TxContext
    ) {
        let borrower = tx_context::sender(ctx);
        let book = bag::borrow_mut(&mut system.books, book_id);

        // Check if the book is already borrowed
        assert!(!book.is_borrowed, E_BOOK_ALREADY_BORROWED);

        // Mark the book as borrowed
        book.is_borrowed = true;
        book.borrower = borrower;
    }

    /// Return a borrowed book to the library
    public entry fun return_book(
        system: &mut LibrarySystem,
        book_id: UID,
        ctx: &mut TxContext
    ) {
        let borrower = tx_context::sender(ctx);
        let book = bag::borrow_mut(&mut system.books, book_id);

        // Check if the book is borrowed by the sender
        assert!(book.is_borrowed, E_BOOK_NOT_AVAILABLE);
        assert!(book.borrower == borrower, E_NOT_OWNER);

        // Mark the book as available
        book.is_borrowed = false;
        book.borrower = 0x0;
    }

    /// View the details of a book
    public fun view_book(
        system: &LibrarySystem,
        book_id: UID
    ): Book {
        bag::borrow(&system.books, book_id)
    }

    /// View all books in the library
    public fun view_all_books(system: &LibrarySystem): vector<Book> {
        bag::values(&system.books)
    }
}
