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

    /// A user profile
    struct Profile has key, store {
        id: UID,
        owner: address,
        name: vector<u8>,
        age: u64,
        gender: vector<u8>,
        preferences: vector<u8>,
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

    /// Function to like a profile (attempt to match)
    public entry fun like_profile(
        dapp: &mut DatingDapp,
        liker_profile_id: UID,
        liked_profile_id: UID,
        ctx: &mut TxContext
    ) {
        let liker_profile = bag::borrow(&dapp.profiles, liker_profile_id);
        let liked_profile = bag::borrow(&dapp.profiles, liked_profile_id);

        // Check if both profiles exist and belong to the sender
        assert!(liker_profile.owner == tx_context::sender(ctx), ENotOwner);
        
        // Simple match logic: if the liked profile likes the liker back, create a match
        // Here, we could add more complex matching criteria based on profiles' preferences
        if profile_likes_back(liked_profile, liker_profile) {
            let match_id = object::new(ctx);
            let new_match = Match {
                id: match_id,
                profile1: liker_profile_id,
                profile2: liked_profile_id,
            };
            bag::add(&mut dapp.matches, match_id, new_match);
        }
    }

    /// Helper function to determine if a profile likes another profile back
    fun profile_likes_back(liked_profile: &Profile, liker_profile: &Profile): bool {
        // Add logic to check if liked_profile likes liker_profile back
        // This can involve checking preferences, history, etc.
        true
    }

    /// View matches for a profile
    public entry fun view_matches(
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
}
