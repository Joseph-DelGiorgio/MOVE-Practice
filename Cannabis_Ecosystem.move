module dispensary::cannabis_ecosystem {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use std::string::{Self, String};

    // Structs
    struct CannabisEcosystem has key {
        id: UID,
        owner: address,
        products: Table<ID, Product>,
        strain_registry: Table<String, StrainInfo>,
        compliance_reports: VecMap<u64, ComplianceReport>,
        total_sales: u64,
    }

    struct Product has key, store {
        id: UID,
        name: String,
        strain: String,
        price: u64,
        thc_content: u64,
        cbd_content: u64,
        batch_id: String,
        lab_results: Option<LabResults>,
    }

    struct StrainInfo has store {
        genetic_info: String,
        developer: address,
        patent_number: Option<String>,
    }

    struct LabResults has store {
        test_date: u64,
        thc_verified: u64,
        cbd_verified: u64,
        contaminant_free: bool,
    }

    struct AgeVerification has key {
        id: UID,
        customer: address,
        verified: bool,
        verification_time: u64,
    }

    struct ComplianceReport has store {
        report_date: u64,
        inventory_count: u64,
        sales_volume: u64,
        regulatory_issues: VecMap<String, String>,
    }

    // Events
    struct ProductSold has copy, drop {
        product_id: ID,
        price: u64,
        buyer: address,
        timestamp: u64,
    }

    struct StrainRegistered has copy, drop {
        strain_name: String,
        developer: address,
    }

    // Error codes
    const EInsufficientInventory: u64 = 0;
    const EInvalidAge: u64 = 1;
    const EInsufficientPayment: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EStrainAlreadyRegistered: u64 = 4;

    // Functions
    public fun initialize_ecosystem(ctx: &mut TxContext) {
        let ecosystem = CannabisEcosystem {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            products: table::new(ctx),
            strain_registry: table::new(ctx),
            compliance_reports: vec_map::empty(),
            total_sales: 0,
        };
        transfer::share_object(ecosystem);
    }

    public fun add_product(
        ecosystem: &mut CannabisEcosystem,
        name: String,
        strain: String,
        price: u64,
        thc_content: u64,
        cbd_content: u64,
        batch_id: String,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ecosystem.owner, EUnauthorized);
        let product = Product {
            id: object::new(ctx),
            name,
            strain,
            price,
            thc_content,
            cbd_content,
            batch_id,
            lab_results: option::none(),
        };
        let product_id = object::id(&product);
        table::add(&mut ecosystem.products, product_id, product);
    }

    public fun register_strain(
        ecosystem: &mut CannabisEcosystem,
        strain_name: String,
        genetic_info: String,
        patent_number: Option<String>,
        ctx: &mut TxContext
    ) {
        assert!(!table::contains(&ecosystem.strain_registry, strain_name), EStrainAlreadyRegistered);
        let strain_info = StrainInfo {
            genetic_info,
            developer: tx_context::sender(ctx),
            patent_number,
        };
        table::add(&mut ecosystem.strain_registry, strain_name, strain_info);
        event::emit(StrainRegistered { strain_name, developer: tx_context::sender(ctx) });
    }

    public fun add_lab_results(
        ecosystem: &mut CannabisEcosystem,
        product_id: ID,
        test_date: u64,
        thc_verified: u64,
        cbd_verified: u64,
        contaminant_free: bool,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ecosystem.owner, EUnauthorized);
        let product = table::borrow_mut(&mut ecosystem.products, product_id);
        product.lab_results = option::some(LabResults {
            test_date,
            thc_verified,
            cbd_verified,
            contaminant_free,
        });
    }

    public fun verify_age(customer: address, birth_date: u64, clock: &Clock, ctx: &mut TxContext) {
        let current_time = clock::timestamp_ms(clock);
        let age = (current_time - birth_date) / (1000 * 60 * 60 * 24 * 365);
        let verification = AgeVerification {
            id: object::new(ctx),
            customer,
            verified: age >= 21,
            verification_time: current_time,
        };
        transfer::public_transfer(verification, customer);
    }

    public fun purchase_product(
        ecosystem: &mut CannabisEcosystem,
        product_id: ID,
        payment: &mut Coin<SUI>,
        age_verification: &AgeVerification,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(age_verification.verified, EInvalidAge);
        let product = table::borrow(&ecosystem.products, product_id);
        assert!(coin::value(payment) >= product.price, EInsufficientPayment);

        let price = product.price;
        let paid = coin::split(payment, price, ctx);
        transfer::public_transfer(paid, ecosystem.owner);

        ecosystem.total_sales = ecosystem.total_sales + price;

        event::emit(ProductSold {
            product_id,
            price,
            buyer: tx_context::sender(ctx),
            timestamp: clock::timestamp_ms(clock),
        });
    }

    public fun generate_compliance_report(
        ecosystem: &mut CannabisEcosystem,
        report_date: u64,
        inventory_count: u64,
        sales_volume: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ecosystem.owner, EUnauthorized);
        let report = ComplianceReport {
            report_date,
            inventory_count,
            sales_volume,
            regulatory_issues: vec_map::empty(),
        };
        vec_map::insert(&mut ecosystem.compliance_reports, report_date, report);
    }

    public fun get_product_info(ecosystem: &CannabisEcosystem, product_id: ID): (String, u64, u64, u64, String) {
        let product = table::borrow(&ecosystem.products, product_id);
        (product.name, product.price, product.thc_content, product.cbd_content, product.batch_id)
    }

    public fun get_strain_info(ecosystem: &CannabisEcosystem, strain_name: String): (String, address, Option<String>) {
        let strain_info = table::borrow(&ecosystem.strain_registry, strain_name);
        (strain_info.genetic_info, strain_info.developer, strain_info.patent_number)
    }
}
