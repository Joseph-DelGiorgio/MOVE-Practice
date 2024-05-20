module EncodeEX {

struct ThisIsAnObject has key {
    id: UID,
}

}

module car::car {

    use sui::object::{Self, UID};

    struct Car has key {
        id: UID,
        speed: u8,
        acceleration: u8,
        handling: u8,
    }

    use sui::tx_context::{Self, TxContext};

    fun new(speed: u8, acceleration: u8, handling: u8, ctx: &mut TxContext): Car {
        Car {
            id: object::new(ctx),
            speed,
            handling,
        }
    }

    use sui::transfer;

    public entry fun create(speed: u8, acceleration: u8, handling: u8, ctx: &mut TxContext) {
        let car = new(speed, acceleration, handling, ctx);
        transfer::transfer(car, tx_context::sender(ctx));
    }

    public entry fun transfer(car: Car, recipient: address) {
        transfer::transfer(car, recipient);
    }

    public fun get_stats(self: &Car): (u8, u8, u8) {
        (self.speed, self.handling, self.acceleration)
    }

    public entry fun upgrade_speed(self: &mut Car, amount: u8) {
        self.speed = self.speed + amount;
    }

    public entry fun upgrade_acceleration(self: &mut Car, amount: u8) {
        self.acceleration = self.acceleration + amount;
    }

    public entry fun upgrade_handling(self: &mut Car, amount: u8) {
        self.handling = self.handling + amount;
    }


}

module car::car_admin {

    use sui::object{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    struct AdminCapability has key {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCapability {
            id: object::new(ctx),
        }, tx_context::sender(ctx))
    }

    public entry fun create(_: &AdminCapability, speed: u8, acceleration: u8, handling: u8, ctx: &mut TxContext) {
        let car = new(speed, acceleration, handling, ctx);
        transfer::transfer(car, tx_context::sender(ctx));
    }
}

module car::car_shop {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    const EInsufficientBalance: u64 = 0;

    struct Car has key {
        id: UID,
        speed: u8,
        acceleration: u8,
        handling: u8,
    }

    struct CarShop has key {
        id: UID,
        price: u64,
        balance: Balance<SUI>
    }

    struct ShopOwnerCar has key {id: UID}

    fun init(ctx: &mut TxContext) {
        transfer::transfer(ShopOwnerCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        transfer::share_object(CarShop {
            id: object::new(ctx),
            price: 100,
            balance: balance::zero()
        })
    }

    public entry fun buy_car(shop: &mut CarShop, payment: &mut Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(payment) >= shop.price, EInsufficientBalance);

        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, shop.price);

        balance::join(&mut shop.balance, paid);

        transfer::transfer(Car {
            id: object::new(ctx),
            speed: 50,
            acceleration: 50,
            handling: 50
        }, tx_context::sender(ctx))
    }

    public entry fun collect_profits(_: &ShopOwnerCap, shop: &mut CarShop, ctx: &mut TxContext) {
        let amount = balance::value(&shop.balance);
        let profits = coin::take(&mut shop.balance, amount, ctx);

        transfer::transfer(profits, tx_context::sender(ctx))
    }



}
