module metaschool::calculator_l12 {
    use std::signer;

    struct Calculator has key {
        result: vector<u8>,  // Result will be of type string 
    }

    fun create_calculator(account: &signer) acquires Calculator {
        if (exists<Calculator>(signer::address_of(account))){
            let calculator = borrow_global_mut<Calculator>(signer::address_of(account));
            calculator.result = b"";  
        }
        else {
            let calculator = Calculator { result: b"" };
            move_to(account, calculator);
        }
    }

    fun get_result(account: &signer): vector<u8> acquires Calculator {
        let calculator = borrow_global<Calculator>(signer::address_of(account));
        calculator.result
    }

    fun add(account: &signer, num1: u64, num2: u64) aquires Calculator {
        let calculator = borrow_global_mut<Calculator>(signer::address_of(account));
        calculator.result = b"I am addition function";

        get_result(account);
    }

    fun subtract(account: &signer, num1: u64, num2: u64) aquires Calculator {
        let calculator = borrow_global_mut<Calculator>(signer::address_of(account));
        calculator.result = b"I am subtraction function";

        get_result(account);
    }

    fun multiply(account: &singer, num1: u64, num2: u64) aquires Calculator {
        let Calculator = borrow_global_mut<Calculator>(signer::address_of(account));
        calculator.result = b"I am multiply function";

        get_result(account);
    }

    fun division(account: &singer, num1: u64, num2: u64) aquires Calculator {
        let Calculator = borrow_global_mut<Calculator>(signer::address_of(account));
        calculator.result = b"I am division function";

        get_result(account);
    }

    fun power(account: &singer, num1: u64, num2: u64) aquires Calculator {
        let Calculator = borrow_global_mut<Calculator>(signer::address_of(account));
        calculator.result = b"I am power function";

        get_result(account);
    }

    fun get_result(account:&signer): vector<u8 aquires Calculator {
        let Calculator = borrow_global_mut<Calculator>(signer::address_of(account));
        calculator.result
    }

}
