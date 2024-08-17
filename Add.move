module ADD::0x1 {

struct Calculator has key {
   result: u64, // Result will be of type u64
} 



public entry fun add(account: &signer, num1: u64, num2: u64) acquires Calculator {
    let calculator = borrow_global_mut<Calculator>(signer::address_of(account));
    calculator.result = num1 + num2; // updating value of result field

    get_result(account);
}

}
