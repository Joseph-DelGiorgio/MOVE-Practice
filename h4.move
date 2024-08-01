module 0xb1f4afa3ba948a570499706b00124653cf54627fcdc421de1517d98f2eeb41f8::h4 {

    struct MyData has key, store {
        value: u64,
        flag: bool,
    }

    fun init_module(sender: &signer) {

        //here
    }
}