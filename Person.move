module 0x1::PersonModule {
    //use std::signer;
    use std::string::String;

    // Define the Person struct with the `key` and `store` abilities
    struct Person has key, store {
        id: u64,
        name: String,
        city: String,
        age: u8,
        date_of_birth: String,
    }

    // Constructor function to create a new Person object
    public fun create_person(
        id: u64,
        name: String,
        city: String,
        age: u8,
        date_of_birth: String
    ): Person {
        Person {
            id,
            name,
            city,
            age,
            date_of_birth,
        }
    }
}
