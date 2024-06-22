module BookLendingLibrary {

    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Vector;
    use 0x1::Errors;
    use 0x1::String;
    use 0x1::Event;

    struct Book {
        id: u64,
        title: String,
        author: String,
        owner: address,
        available: bool,
    }

    struct BookLendingLibrary {
        books: vector<Book>,
        next_book_id: u64,
    }

    event BookAddedEvent {
        book_id: u64,
        title: String,
        author: String,
        owner: address,
    }

    event BookLentEvent {
        book_id: u64,
        borrower: address,
    }

    event BookReturnedEvent {
        book_id: u64,
        borrower: address,
    }

    public fun new_library(admin: &signer): address {
        let library = BookLendingLibrary {
            books: vector::empty(),
            next_book_id: 0,
        };
        let library_address = Account::create_resource_account(admin, vector::empty());
        Account::publish_resource(&admin, library);
        library_address
    }

    public fun add_book(library_address: address, owner: &signer, title: String, author: String) {
        let owner_address = Signer::address_of(owner);
        let library = &mut borrow_global_mut<BookLendingLibrary>(library_address);

        let book = Book {
            id: library.next_book_id,
            title,
            author,
            owner: owner_address,
            available: true,
        };

        library.next_book_id += 1;
        vector::push_back(&mut library.books, book);

        Event::emit<BookAddedEvent>(BookAddedEvent {
            book_id: book.id,
            title: book.title,
            author: book.author,
            owner: owner_address,
        });
    }

    public fun lend_book(library_address: address, borrower: &signer, book_id: u64) {
        let borrower_address = Signer::address_of(borrower);
        let library = &mut borrow_global_mut<BookLendingLibrary>(library_address);
        let book = &mut find_book_mut(&mut library.books, book_id);

        assert!(book.available, Errors::invalid_argument(1));
        book.available = false;

        Event::emit<BookLentEvent>(BookLentEvent {
            book_id: book.id,
            borrower: borrower_address,
        });
    }

    public fun return_book(library_address: address, borrower: &signer, book_id: u64) {
        let borrower_address = Signer::address_of(borrower);
        let library = &mut borrow_global_mut<BookLendingLibrary>(library_address);
        let book = &mut find_book_mut(&mut library.books, book_id);

        assert!(!book.available, Errors::invalid_argument(2));
        book.available = true;

        Event::emit<BookReturnedEvent>(BookReturnedEvent {
            book_id: book.id,
            borrower: borrower_address,
        });
    }

    public fun get_books(library_address: address): vector<(u64, String, String, address, bool)> {
        let library = borrow_global<BookLendingLibrary>(library_address);
        let mut book_list: vector<(u64, String, String, address, bool)> = vector::empty();

        for book in &library.books {
            vector::push_back(
                &mut book_list,
                (book.id, book.title, book.author, book.owner, book.available),
            );
        }

        book_list
    }

    fun find_book(books: &vector<Book>, id: u64): &Book {
        let book_opt = vector::find(books, move |book| book.id == id);
        assert!(book_opt.is_some(), Errors::not_found(0));
        book_opt.borrow().unwrap()
    }

    fun find_book_mut(books: &mut vector<Book>, id: u64): &mut Book {
        let book_opt = vector::find_mut(books, move |book| book.id == id);
        assert!(book_opt.is_some(), Errors::not_found(0));
        book_opt.borrow_mut().unwrap()
    }
}
