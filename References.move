 /* MOVE SYNTAX */

// visibility =  
// public - can be called by any function in any module or script. 

// public(friend) - A public(friend) function can be called by any function in the same module
// and by the function of the module which are explicitly defined in the friend list. 

// private - By default the functions in move are private(that means they can only be called 
// within the same module) and cannot be access outside the module by other modules and scripts. 

// fun = function


/* visibility fun Function_Name(arg1: data_type, arg2:data_type, ...) : (u8,bool){

    //your code
}
*/

//MOVE provides 2 types of references
// immutable & - cannot modify underlying values (or any of its feilds)
// mutable &mut - allow for modifications via a write through that reference

module my_addrx::References 
{
    use std::debug::print;

    fun practice()
    {
        //immutable references
        
        let a = 10;
        let ima = &a;
        //modify the value
        *ima = 11;
        print(&a);
        print(ima);


        //Mutable references
        let a = 10;
        let ma - &mut a;
        //modify the value
        print(ma);
        *ma = 11;
        print(ma);
        *ma = 11;
        let c - a;
        print(&c);
        print(&a);
        print(ma);
    }

    #[test]
    fun testing()
    {
        practice();
    }
}
