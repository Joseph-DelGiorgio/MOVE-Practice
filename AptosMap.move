//simple map:
use aptos_std::simple_map;
let my_map = simple_map::new<u64>();

//vector of keys and values map:
let my_map = simple_map::new_from(vector[1, 2, 3], vector[4, 5, 6]);



let my_map = simple_map::new();

simple_map::add(&mut my_map, 1, 4);
simple_map::add(&mut my_map, 2, 5);
simple_map::add(&mut my_map, 3, 6);



//Elements inside a simple map can be borrowed with a reference to the key:
let value = simple_map::borrow(&my_map, &1);

//Elements can be modified in place by borrowing mutable references:
let my_map = simple_map::borrow_mut(&mut my_map, &1);
*my_map = 7;


//Elements can be removed from the map:
simple_map::remove(&mut my_map, &1);


//To check if a key is present in the map:
let is_present = simple_map::contains(&my_map, &1);
