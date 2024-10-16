module DeepBookExample {
    use std::vector;
    use std::string;
    use sui::move_to_sender;
    use sui::move_to;

    // Define a structure to hold order details
    struct Order has copy, drop {
        id: u64,
        user: address,
        amount: u64,
        price: u64,
    }

    // Define a storage for orders
    struct OrderBook has key {
        orders: vector<Order>,
    }

    public fun initialize_order_book() {
        let order_book = OrderBook {
            orders: vector::empty<Order>(),
        };
        move_to_sender<OrderBook>(order_book);
    }

    // Function to place an order
    public fun place_order(order_id: u64, user: address, amount: u64, price: u64) {
        let order = Order {
            id: order_id,
            user,
            amount,
            price,
        };

        // Retrieve the order book
        let mut order_book = borrow_global_mut<OrderBook>(user);
        
        // Add the order to the order book
        vector::push_back(&mut order_book.orders, order);
    }

    // Function to get orders for a user
    public fun get_orders(user: address): vector<Order> {
        let order_book = borrow_global<OrderBook>(user);
        return order_book.orders;
    }
}
