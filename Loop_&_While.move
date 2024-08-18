//While Loop Demo:
module metaschool::Demo
{
    use std::debug as bug;
    fun sample_function(){
        let n = 5; 
        let sum = 0;
        let i = 1;
        while (i <= n) {
            sum = sum + i;
            i = i + 1
        };
        bug::print(&sum);
    }
}


//Loop Demo
   fun sample_function(){
        let n = 5; 
        let sum = 0;
        let i = 1;
        loop {
            if (i > n) break;
            sum = sum + i;
            i = i + 1;
        };
        bug::print(&sum);
    }



