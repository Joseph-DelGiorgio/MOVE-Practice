module example::if_statement
{
    use std::debug as bug;		
    fun sample_function(){
        let a : u8 = 15;
        if(a == 5) // false condition
        {
            a = a + 5;
        }
        else
        {
            a = 0;
        };
        bug::print(&a);
    }
}
