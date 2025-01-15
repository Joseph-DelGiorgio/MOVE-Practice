module irrigation_system::advanced_irrigation {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};

    // Main structs
    struct IrrigationSystem has key {
        id: UID,
        owner: address,
        water_balance: u64,
        price_per_unit: u64,
        last_watered: u64,
        sensors: Table<vector<u8>, SensorData>,
        crop_profiles: Table<vector<u8>, CropProfile>,
        weather_data: WeatherData,
        maintenance_schedule: Table<u64, MaintenanceTask>,
        authorized_users: VecMap<address, UserRole>,
    }

    struct SensorData has store {
        moisture_level: u64,
        last_updated: u64,
    }

    struct CropProfile has store {
        name: vector<u8>,
        optimal_moisture: u64,
        watering_frequency: u64,
    }

    struct WeatherData has store {
        temperature: u64,
        humidity: u64,
        rainfall_forecast: u64,
        last_updated: u64,
    }

    struct MaintenanceTask has store {
        description: vector<u8>,
        scheduled_time: u64,
        completed: bool,
    }

    struct UserRole has store, drop {
        can_water: bool,
        can_maintain: bool,
        can_manage: bool,
    }

    // Events
    struct WateringEvent has copy, drop {
        system_id: ID,
        amount: u64,
        timestamp: u64,
        initiator: address,
    }

    struct MaintenanceScheduledEvent has copy, drop {
        system_id: ID,
        task_id: u64,
        scheduled_time: u64,
    }

    // Error codes
    const E_INSUFFICIENT_WATER: u64 = 0;
    const E_INSUFFICIENT_PAYMENT: u64 = 1;
    const E_UNAUTHORIZED: u64 = 2;
    const E_INVALID_SENSOR: u64 = 3;
    const E_INVALID_CROP: u64 = 4;

    // Main functions
    public fun create_system(price: u64, ctx: &mut TxContext) {
        let system = IrrigationSystem {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            water_balance: 0,
            price_per_unit: price,
            last_watered: 0,
            sensors: table::new(ctx),
            crop_profiles: table::new(ctx),
            weather_data: WeatherData { temperature: 0, humidity: 0, rainfall_forecast: 0, last_updated: 0 },
            maintenance_schedule: table::new(ctx),
            authorized_users: vec_map::empty(),
        };
        transfer::share_object(system);
    }

    public fun add_water(system: &mut IrrigationSystem, amount: u64, clock: &Clock, ctx: &mut TxContext) {
        assert!(is_authorized(system, tx_context::sender(ctx), true), E_UNAUTHORIZED);
        system.water_balance = system.water_balance + amount;
        system.last_watered = clock::timestamp_ms(clock);
    }

    public fun water_field(
        system: &mut IrrigationSystem,
        amount: u64,
        payment: &mut Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(is_authorized(system, tx_context::sender(ctx), true), E_UNAUTHORIZED);
        assert!(system.water_balance >= amount, E_INSUFFICIENT_WATER);
        let price = calculate_price(system, amount);
        assert!(coin::value(payment) >= price, E_INSUFFICIENT_PAYMENT);

        system.water_balance = system.water_balance - amount;
        let paid = coin::split(payment, price, ctx);
        transfer::public_transfer(paid, system.owner);

        system.last_watered = clock::timestamp_ms(clock);

        event::emit(WateringEvent {
            system_id: object::uid_to_inner(&system.id),
            amount,
            timestamp: system.last_watered,
            initiator: tx_context::sender(ctx),
        });
    }

    public fun update_sensor_data(
        system: &mut IrrigationSystem,
        sensor_id: vector<u8>,
        moisture_level: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(is_authorized(system, tx_context::sender(ctx), true), E_UNAUTHORIZED);
        let sensor_data = SensorData {
            moisture_level,
            last_updated: clock::timestamp_ms(clock),
        };
        if (table::contains(&system.sensors, sensor_id)) {
            table::remove(&mut system.sensors, sensor_id);
        };
        table::add(&mut system.sensors, sensor_id, sensor_data);
    }

    public fun add_crop_profile(
        system: &mut IrrigationSystem,
        name: vector<u8>,
        optimal_moisture: u64,
        watering_frequency: u64,
        ctx: &mut TxContext
    ) {
        assert!(is_authorized(system, tx_context::sender(ctx), false), E_UNAUTHORIZED);
        let profile = CropProfile {
            name: name,
            optimal_moisture,
            watering_frequency,
        };
        table::add(&mut system.crop_profiles, name, profile);
    }

    public fun update_weather_data(
        system: &mut IrrigationSystem,
        temperature: u64,
        humidity: u64,
        rainfall_forecast: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(is_authorized(system, tx_context::sender(ctx), true), E_UNAUTHORIZED);
        system.weather_data = WeatherData {
            temperature,
            humidity,
            rainfall_forecast,
            last_updated: clock::timestamp_ms(clock),
        };
    }

    public fun schedule_maintenance(
        system: &mut IrrigationSystem,
        description: vector<u8>,
        scheduled_time: u64,
        ctx: &mut TxContext
    ) {
        assert!(is_authorized(system, tx_context::sender(ctx), false), E_UNAUTHORIZED);
        let task_id = table::length(&system.maintenance_schedule);
        let task = MaintenanceTask {
            description,
            scheduled_time,
            completed: false,
        };
        table::add(&mut system.maintenance_schedule, task_id, task);

        event::emit(MaintenanceScheduledEvent {
            system_id: object::uid_to_inner(&system.id),
            task_id,
            scheduled_time,
        });
    }

    public fun authorize_user(
        system: &mut IrrigationSystem,
        user: address,
        can_water: bool,
        can_maintain: bool,
        can_manage: bool,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == system.owner, E_UNAUTHORIZED);
        let role = UserRole {
            can_water,
            can_maintain,
            can_manage,
        };
        vec_map::insert(&mut system.authorized_users, user, role);
    }

    // Helper functions
    fun is_authorized(system: &IrrigationSystem, user: address, for_watering: bool): bool {
        if (user == system.owner) {
            true
        } else if (vec_map::contains(&system.authorized_users, &user)) {
            let role = vec_map::get(&system.authorized_users, &user);
            if (for_watering) {
                role.can_water
            } else {
                role.can_manage
            }
        } else {
            false
        }
    }

    fun calculate_price(system: &IrrigationSystem, amount: u64): u64 {
        // Implement tiered pricing or dynamic pricing based on water scarcity
        amount * system.price_per_unit
    }

    // Getter functions
    public fun get_system_info(system: &IrrigationSystem): (u64, u64, u64) {
        (system.water_balance, system.price_per_unit, system.last_watered)
    }

    public fun get_sensor_data(system: &IrrigationSystem, sensor_id: vector<u8>): (u64, u64) {
        let sensor = table::borrow(&system.sensors, sensor_id);
        (sensor.moisture_level, sensor.last_updated)
    }

    public fun get_weather_data(system: &IrrigationSystem): (u64, u64, u64, u64) {
        (system.weather_data.temperature, system.weather_data.humidity, 
         system.weather_data.rainfall_forecast, system.weather_data.last_updated)
    }
}
