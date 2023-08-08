// SPDX-License-Identifier: Apache-2.0
module yousui::admin {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::coin::{Coin};
    use sui::clock::{Clock};
    use sui::vec_map;
    use sui::vec_set;
    use sui::transfer;

    use std::string::{String};
    use std::vector;

    use yousui::project::{Self, Project};
    use yousui::ido::{Self, Round};
    use yousui::policy;
    use yousui::policy_purchase;
    use yousui::policy_yousui_nft;
    use yousui::policy_whitelist;
    use yousui::policy_staking_tier;
    use yousui::vault;
    use yousui::service_vesting;
    use yousui::service_affiliate;
    use yousui::service_preregister;
    use yousui::service_refund;
    use yousui::utils;
    use yousui::launchpad::{Self, LaunchpadStorage};

    const ESetterIsNotSetted: u64 = 100+0;
    const ELengthEqZero: u64 = 100+1;
    const ETwoLengthNotEq: u64 = 100+2;

    struct AdminCap has key, store {
        id: UID,
    }

    struct AdminStorage has key, store {
        id: UID,
        setters: vector<address>,
    }
    
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Sender Admin cap to sender
        transfer::public_transfer(
            AdminCap {
                id: object::new(ctx),
            },
            sender
        );

        let setters = vector::empty<address>();

        vector::push_back(&mut setters, sender);

        // Share Admin storage
        transfer::share_object(AdminStorage {
           id: object::new(ctx),
           setters,
        });

    }


//------------------------------------------------------------------------ Begin Admin actions ------------------------------------------------------------------------

    public entry fun create_project(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        name: String,
        twitter: String,
        discord: String,
        telegram: String,
        medium: String,
        website: String,
        image_url: String,
        description: String,
        link_url: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        launchpad::add_project<>(
            launchpad,
            name,
            project::create_project(
                name,
                twitter,
                discord,
                telegram,
                medium,
                website,
                image_url,
                description,
                link_url, ctx
            )
        )
    }

    public entry fun new_round<TOKEN>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        name: String,
        token_decimal: u8,
        start_at: u64,
        end_at: u64,
        total_supply: u64,
        purchase_type: vector<u8>,
        ctx: &mut TxContext,
    ) {
        check_is_setter(admin_storage, ctx);
        
        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let project_info = project::get_project_info(project);

        project::add_dynamic_object_field(
            project,
            name,
            ido::new_round<TOKEN>(
                name,
                project_info,
                token_decimal,
                start_at,
                end_at,
                total_supply,
                purchase_type,
                ctx
            )
        );
    }

    public entry fun add_payment<PAYMENT>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ratio_per_token: u64,
        ratio_decimal: u8, // should 9
        payment_decimal: u8,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field<Round>(project, round_name);
        ido::add_payment<PAYMENT>(round, ratio_per_token, ratio_decimal, payment_decimal);
    }

    public entry fun remove_payment<PAYMENT>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field<Round>(project, round_name);
        ido::remove_payment<PAYMENT>(round);
    }

//------------------- RULE ---------------------

    entry public fun add_rule_staking_tier<T>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        min_stake: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);
        let token_type = utils::get_full_type<T>();
        policy_staking_tier::add(policy, min_stake, token_type);
    }

    entry public fun add_rule_yousui_nft(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);
        policy_yousui_nft::add(policy);
    }

    entry public fun add_rule_purchase(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        min_purchase: u64,
        max_purchase: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);
        policy_purchase::add(policy, min_purchase, max_purchase);
    }

    entry public fun add_rule_whitelist(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        investors: vector<address>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);
        policy_whitelist::add(policy, investors);
    }

    entry public fun remove_rule<Rule, Config: store + drop>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);
        policy::remove_rule<Rule, Config>(policy);
    }

    public entry fun set_whitelist<ROUND>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        investors: vector<address>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        
        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);
        
        policy_whitelist::set_whitelist(policy, investors);
    }

    public entry fun set_whitelist_plus(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        investors: vector<address>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        
        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);
        
        policy_whitelist::set_whitelist(policy, investors);
    }

    public entry fun migrate_vesting_schedule(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        
        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::migrate_vesting_schedule(round);
    }

    public entry fun remove_whitelist(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        investors: vector<address>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);

        policy_whitelist::remove_whitelist(policy, investors);
    }

    public entry fun clear_whitelist(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let policy = ido::get_mut_policy(round);

        policy_whitelist::clear_whitelist(policy);
    }

//------------------- RULE ---------------------

    entry public fun add_service_refund(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        start_refund_time: u64,
        refund_range_time: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);
        
        service_refund::add(
            service,
            start_refund_time,
            refund_range_time,
            ctx
        );
    }

    entry public fun remove_service_refund(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);

        service_refund::remove(service);
    }

    entry public fun add_service_vesting(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let project_info = ido::get_project(round);
        let token_type = ido::get_token_type(round);
        let service = ido::get_mut_service(round);
        
        service_vesting::add(
            service,
            project_info,
            tge_time,
            tge_unlock_percent,
            number_of_cliff_months,
            number_of_month,
            number_of_linear,
            token_type,
            ctx
        )
    }

    entry public fun remove_service_vesting(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);

        service_vesting::remove(service);
    }


// ----- Affiliate -----
    entry public fun add_service_affiliate(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);
        
        service_affiliate::add(
            service,
            ctx
        )
    }

    entry public fun remove_service_affiliate(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);

        service_affiliate::remove(service);
    }

    entry public fun add_affiliator_list(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        affiliators: vector<address>,
        nations: vector<String>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        assert!(vector::length(&affiliators) > 0, ELengthEqZero);
        assert!(vector::length(&affiliators) == vector::length(&nations), ETwoLengthNotEq);

        let affiliator_list = vec_map::empty();
        while (!vector::is_empty(&affiliators)) {
            vec_map::insert(&mut affiliator_list, vector::pop_back(&mut affiliators), vector::pop_back(&mut nations))
        };

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);

        service_affiliate::add_affiliator_list(service, affiliator_list);
    }

    entry public fun remove_affiliator_list(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        affiliators: vector<address>,
        nations: vector<String>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        assert!(vector::length(&affiliators) > 0, ELengthEqZero);
        assert!(vector::length(&affiliators) == vector::length(&nations), ETwoLengthNotEq);

        let affiliator_list = vec_map::empty();
        while (!vector::is_empty(&affiliators)) {
            vec_map::insert(&mut affiliator_list, vector::pop_back(&mut affiliators), vector::pop_back(&mut nations))
        };

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);

        service_affiliate::remove_affiliator_list(service, affiliator_list);
    }


// ----- Affiliate -----


// ----- SERVICE PREREGISTER BEGIN -----

    entry public fun add_service_preregister(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);
        
        service_preregister::add(
            service,
            ctx
        )
    }

    entry public fun set_is_open_claim_refund(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        is_open_claim_refund: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);
        
        service_preregister::set_is_open_claim_refund(
            service,
            is_open_claim_refund
        )
    }

    entry public fun remove_service_preregister(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);

        service_preregister::remove(service);
    }

// ----- SERVICE PREREGISTER END -----


    public entry fun set_end_at(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        new_end_at: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_end_at(bm_round, new_end_at);
    }

    public entry fun set_start_at(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        new_start_at: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_start_at(bm_round, new_start_at);
    }

    public entry fun set_payment_rate<PAYMENT>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        new_ratio_per_token: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_payment_rate<PAYMENT>(bm_round, new_ratio_per_token);
    }

    public entry fun set_pause(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        is_pause: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_pause(bm_round, is_pause);
    }

    public entry fun set_total_supply(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        total_supply: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_total_supply(bm_round, total_supply);
    }

    public entry fun set_total_sold(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        total_sold: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_total_sold(bm_round, total_sold);
    }

    public entry fun set_push_total_sold(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_push_total_sold(bm_round, amount);
    }

    public entry fun set_arr_purchase_type(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        purchase_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);

        let arr_purchase_type = vec_set::empty<u8>();
        while (!vector::is_empty(&purchase_type)) {
            vec_set::insert(&mut arr_purchase_type, vector::pop_back(&mut purchase_type));
        };

        ido::set_arr_purchase_type(bm_round, arr_purchase_type);
    }

    public entry fun fix(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let bm_round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::set_push_total_sold(bm_round, amount);
    }

    public entry fun set_is_open_claim_vesting(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        is_open_claim_vesting: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let service = ido::get_mut_service(round);
        service_vesting::set_is_open_claim_vesting(service, is_open_claim_vesting);
    }

    entry public fun set_is_vesting_info(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let token_type = ido::get_token_type(round);
        let service = ido::get_mut_service(round);
        
        service_vesting::set_is_vesting_info(
            service,
            tge_time,
            tge_unlock_percent,
            number_of_cliff_months,
            number_of_month,
            number_of_linear,
            token_type
        )
    }

    public entry fun deposit_round<T>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        coin: Coin<T>,
        ctx: &mut TxContext
    ) {

        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let vaults = ido::get_mut_vault(round);

        vault::deposit<T>(vaults, coin, ctx)
    }

    public entry fun withdraw_round<T>(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        let vaults = ido::get_mut_vault(round);

        vault::withdraw<T>(vaults, amount, tx_context::sender(ctx), ctx)
    }

    public entry fun airdrop_vesting(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        clock: &Clock,
        arr_user_address: vector<address>,
        arr_token_amount: vector<u64>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        ido::airdrop_vesting(clock, round, arr_user_address, arr_token_amount, ctx)
    }

// --- launchpad ---

    public entry fun set_launchpad_image(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        new_image: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        launchpad::set_image(launchpad, new_image)
    }

// --- refund ---

    public entry fun set_start_refund_time(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        start_refund_time: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);

        let service = ido::get_mut_service(round);
        service_refund::set_start_refund_time(service, start_refund_time);
    }

    public entry fun set_refund_range_time(
        admin_storage: &AdminStorage,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        range_time: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let project = launchpad::borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field(project, round_name);
        
        let service = ido::get_mut_service(round);
        service_refund::set_refund_range_time(service, range_time);
    }

//------------------------------------------------------------------------ End Admin actions ------------------------------------------------------------------------

    fun check_is_setter(
        admin_storage: &AdminStorage,
        ctx: &mut TxContext,
    ) {
        assert!(vector::contains(&admin_storage.setters, &tx_context::sender(ctx)), ESetterIsNotSetted);
    }
}
