module book::drop_ability{

    public struct IgnoreMe has drop{
        a: u8,
        b: u8,
    }

    public struct NoDrop {}

     #[test]
    // Create an instance of the `IgnoreMe` struct and ignore it.
    // Even though we constructed the instance, we don't need to unpack it.

    fun test_ignore(){
        let no_drop = NoDrop();
        let _ = IgnoreMe {a: 1, b: 2};

        let NoDrop{} = no_drop;
    }
}
