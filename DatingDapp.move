/* imports:

Added necessary imports for the Dapp's functionality.
Error Codes:

Defined an additional error code EProfileNotFound.
Struct Definitions:

Profile: Added a liked_profiles field to track profiles liked by the user.
Match: No changes.
DatingDapp: No changes.
Functions:

create_profile: Creates a new profile and initializes the liked_profiles field.
create_dating_dapp: Creates a new DatingDapp instance.
update_profile: Allows updating an existing profile's details.
like_profile: Adds the liked profile's ID to the liked_profiles list of the liker. If the liked profile has already liked the liker, a match is created.
view_matches: Retrieves matches for a given profile.
view_liked_profiles: Retrieves profiles liked by a given profile.
delete_profile: Deletes a profile if the sender is the owner.
view_all_profiles: Retrieves all profiles in the Dapp.
Enhancements
Added functionality for updating profiles.
Enhanced matching logic by storing and checking liked_profiles.
Added functions to view profiles liked by the user and to view all profiles.
Ensured proper error handling and ownership checks.

*/


module dating_dapp::DatingDapp {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::bag::{Bag, Self};
    use sui::table::{Table, Self};
    use sui::transfer;

    /// Error codes
    const ENotOwner: u64 = 1;
    const EProfileNotFound: u64 = 2;

    /// A user profile
    struct Profile has key, store {
        id: UID,
        owner: address,
        name: vector<u8>,
        age: u64,
        gender: vector<u8>,
        preferences: vector<u8>,
        liked_profiles: vector<UID>,
    }

    /// Match details
    struct Match has key, store {
        id: UID,
        profile1: UID,
        profile2: UID,
    }

    /// The main Dating Dapp structure
    struct DatingDapp has key {
        id: UID,
        profiles: Bag<UID, Profile>,
        matches: Bag<UID, Match>,
    }

    /// Create a new profile
    public entry fun create_profile(
        dapp: &mut DatingDapp,
        name: vector<u8>,
        age: u64,
        gender: vector<u8>,
        preferences: vector<u8>,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let profile = Profile {
            id,
            owner: tx_context::sender(ctx),
            name,
            age,
            gender,
            preferences,
            liked_profiles: vector::empty(),
        };
        bag::add(&mut dapp.profiles, id, profile);
    }

    /// Create a new Dating Dapp instance
    public entry fun create_dating_dapp(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let profiles = bag::new(ctx);
        let matches = bag::new(ctx);
        transfer::share_object(DatingDapp {
            id,
            profiles,
            matches,
        })
    }

    /// Update an existing profile
    public entry fun update_profile(
        dapp: &mut DatingDapp,
        profile_id: UID,
        name: vector<u8>,
        age: u64,
        gender: vector<u8>,
        preferences: vector<u8>,
        ctx: &mut TxContext
    ) {
        let profile = bag::borrow_mut(&mut dapp.profiles, profile_id);
        assert!(profile.owner == tx_context::sender(ctx), ENotOwner);
        
        profile.name = name;
        profile.age = age;
        profile.gender = gender;
        profile.preferences = preferences;
    }

    /// Function to like a profile (attempt to match)
    public entry fun like_profile(
        dapp: &mut DatingDapp,
        liker_profile_id: UID,
        liked_profile_id: UID,
        ctx: &mut TxContext
    ) {
        let liker_profile = bag::borrow_mut(&mut dapp.profiles, liker_profile_id);
        let liked_profile = bag::borrow(&dapp.profiles, liked_profile_id);

        // Check if both profiles exist and liker belongs to the sender
        assert!(liker_profile.owner == tx_context::sender(ctx), ENotOwner);

        vector::push_back(&mut liker_profile.liked_profiles, liked_profile_id);

        // Simple match logic: if the liked profile likes the liker back, create a match
        if vector::contains(&liked_profile.liked_profiles, liker_profile_id) {
            let match_id = object::new(ctx);
            let new_match = Match {
                id: match_id,
                profile1: liker_profile_id,
                profile2: liked_profile_id,
            };
            bag::add(&mut dapp.matches, match_id, new_match);
        }
    }

    /// View matches for a profile
    public fun view_matches(
        dapp: &DatingDapp,
        profile_id: UID,
    ): vector<Match> {
        let matches = bag::values(&dapp.matches);
        let mut profile_matches = vector::empty<Match>();

        for match in matches {
            if match.profile1 == profile_id || match.profile2 == profile_id {
                vector::push_back(&mut profile_matches, match);
            }
        }
        profile_matches
    }

    /// View profiles liked by the user
    public fun view_liked_profiles(
        dapp: &DatingDapp,
        profile_id: UID,
    ): vector<Profile> {
        let profile = bag::borrow(&dapp.profiles, profile_id);
        let mut liked_profiles = vector::empty<Profile>();

        for liked_profile_id in &profile.liked_profiles {
            let liked_profile = bag::borrow(&dapp.profiles, liked_profile_id);
            vector::push_back(&mut liked_profiles, liked_profile);
        }
        liked_profiles
    }

    /// Delete a profile
    public entry fun delete_profile(
        dapp: &mut DatingDapp,
        profile_id: UID,
        ctx: &mut TxContext
    ) {
        let profile = bag::borrow_mut(&mut dapp.profiles, profile_id);
        assert!(profile.owner == tx_context::sender(ctx), ENotOwner);
        bag::remove(&mut dapp.profiles, profile_id);
        object::delete(profile_id);
    }

    /// View all profiles
    public fun view_all_profiles(dapp: &DatingDapp): vector<Profile> {
        bag::values(&dapp.profiles)
    }
}
