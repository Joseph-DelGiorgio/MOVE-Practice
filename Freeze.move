module my_module::config_manager {

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    /// Capability granting the admin the right to manage the config.
    public struct AdminCap has key {
        id: UID,
    }

    /// The Config object that will be made immutable.
    public struct Config has key {
        id: UID,
        message: String,
    }

    /// Creates a new `Config` object and freezes it.
    public fun create_and_freeze(
        _: &AdminCap,
        message: String,
        ctx: &mut TxContext
    ) {
        let config = Config {
            id: object::new(ctx),
            message,
        };

        // Freeze the object so it becomes immutable.
        transfer::freeze_object(config);
    }

    /// Returns the message from the `Config` object.
    /// Can access the object by immutable reference!
    public fun message(c: &Config): String { c.message }

    /// Module initializer is called only once on module publish.
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx))
    }
}
