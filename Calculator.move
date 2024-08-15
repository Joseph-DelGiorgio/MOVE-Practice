module metaschool::calculator {

		// Rsource with key ability
    struct Calculator has key {
        result: u64,
    }

		// Function acquires the Calculator resource
    fun create_calculator(account: &signer) acquires Calculator {
    
			  // We check if the signer address already has a Calculator resource
			  // associated to it
        if (exists<Calculator>(signer::address_of(account))){
        
		        // Here, we are using borrow_global_mut to fetch the Calculator resource
		        // associated with the signer address
            let calculator = borrow_global_mut<Calculator>(signer::address_of(account));
            calculator.result = 0;
        }
        else {
        
	        // If no Calculator resource is present for the input signer address
	        // then we create a new instance of a resource
	        let calculator = Calculator { result: 0 };
	        move_to(account, calculator);
        }
    }
}
