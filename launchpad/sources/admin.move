// SPDX-License-Identifier: Apache-2.0
module yousui::admin {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::clock::{Clock};
    use sui::transfer;
    use sui::vec_map;
    // use sui::event;

    use std::string::{Self, String};
    use std::vector;

    use yousui::launchpad_project::{Self, Project, ProjectStorage};
    use yousui::launchpad_presale::{Self, Round as PresaleRound};
    use yousui::launchpad_ido::{Self, Round as IdoRound};
    use yousui::launchpad_vesting::{Self, Vesting};
    use yousui::whitelist;
    use yousui::affiliate;
    use yousui::utils;

    const ESetterIsSetted: u64 = 100+0;
    const ESetterIsNotSetted: u64 = 100+1;
    const ERoundTypeInvalid: u64 = 100+2;
    const E2LengthNotEq: u64 = 100+3;
    const ELengthEqZero: u64 = 100+4;

    struct AdminCap has key, store {
        id: UID,
    }

    struct AdminStorage has key, store {
        id: UID,
        setters: vector<address>,
    }
    
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(
            AdminCap {
                id: object::new(ctx),
            },
            sender
        );

        let setters = vector::empty<address>();
        vector::push_back(&mut setters, sender);
        transfer::share_object(AdminStorage {
           id: object::new(ctx),
           setters,
        });
    }

    public entry fun add_setter(
        _: &mut AdminCap,
        admin_storage: &mut AdminStorage,
        setter_address: address,
        _ctx: &mut TxContext,
    ) {
        assert!(!vector::contains(&admin_storage.setters, &setter_address), ESetterIsSetted);
        vector::push_back(&mut admin_storage.setters, setter_address);
    }

    public entry fun remove_setter(
        _: &mut AdminCap,
        admin_storage: &mut AdminStorage,
        setter_address: address,
        _ctx: &mut TxContext,
    ) {
        let (is_exists, index) = vector::index_of(&admin_storage.setters, &setter_address);
        assert!(is_exists, ESetterIsNotSetted);
        vector::remove(&mut admin_storage.setters, index);
    }

    fun check_is_setter(
        admin_storage: &AdminStorage,
        ctx: &mut TxContext,
    ) {
        assert!(vector::contains(&admin_storage.setters, &tx_context::sender(ctx)), ESetterIsNotSetted);
    }

    public entry fun create_project(
        admin_storage: &AdminStorage,
        project_storage: &mut ProjectStorage,
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
        launchpad_project::create_project(
            project_storage,
            name,
            twitter,
            discord,
            telegram,
            medium,
            website,
            image_url,
            description,
            link_url, ctx
        );
    }
        
    public entry fun create_round_prasale<TOKEN>(
        admin_storage: &AdminStorage,
        clock: &Clock,
        project: &mut Project,
        name: String,
        token_decimal: u8,
        start_at: u64,
        end_at: u64,
        // max_allocation: u64,
        // min_allocation: u64,
        min_purchase: u64,
        max_purchase: u64,
        total_supply: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let round = launchpad_presale::new_round<TOKEN>(
            clock,
            project,
            name,
            token_decimal,
            start_at,
            end_at,
            // max_allocation,
            // min_allocation,
            min_purchase,
            max_purchase,
            total_supply,
            ctx    
        );
        launchpad_project::add_dynamic_object_field<PresaleRound>(project, name, round);
    }

    public entry fun create_round_ido<TOKEN>(
        admin_storage: &AdminStorage,
        clock: &Clock,
        project: &mut Project,
        name: String,
        token_decimal: u8,
        start_at: u64,
        end_at: u64,
        // max_allocation: u64,
        // min_allocation: u64,
        min_purchase: u64,
        total_supply: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        
        let round = launchpad_ido::new_round<TOKEN>(
            clock,
            project,
            name,
            token_decimal,
            start_at,
            end_at,
            // max_allocation,
            // min_allocation,
            min_purchase,
            total_supply,
            ctx    
        );
        launchpad_project::add_dynamic_object_field<IdoRound>(project, name, round);
    }

    public entry fun create_vesting<ROUND>(
        admin_storage: &AdminStorage,
        clock: &Clock,
        project: &mut Project,
        round_name: String,
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let b_round = launchpad_project::borrow_dynamic_object_field(project, round_name);
            let (vesting, name, vesting_id) = launchpad_vesting::new_vesting(
                clock,
                project,
                round_name,
                tge_time,
                tge_unlock_percent,
                number_of_cliff_months,
                number_of_month,
                number_of_linear,
                launchpad_presale::get_token_type(b_round),
                ctx,
            );
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_vesting(bm_round, vesting_id);
            launchpad_project::add_dynamic_object_field<Vesting>(project, name, vesting);
        } else 
        if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let b_round = launchpad_project::borrow_dynamic_object_field(project, round_name);
            let (vesting, name, vesting_id) = launchpad_vesting::new_vesting(
                clock,
                project,
                round_name,
                tge_time,
                tge_unlock_percent,
                number_of_cliff_months,
                number_of_month,
                number_of_linear,
                launchpad_ido::get_token_type(b_round),
                ctx,
            );
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_vesting(bm_round, vesting_id);
            launchpad_project::add_dynamic_object_field<Vesting>(project, name, vesting);
        } else {
            abort(ERoundTypeInvalid)
        };
    } 

    public entry fun add_payment<ROUND, PAYMENT>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        ratio_per_token: u64,
        ratio_decimal: u8, // should 9
        payment_decimal: u8,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::add_payment<PAYMENT>(bm_round, ratio_per_token, ratio_decimal, payment_decimal, ctx);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::add_payment<PAYMENT>(bm_round, ratio_per_token, ratio_decimal, payment_decimal, ctx);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun remove_payment<ROUND, PAYMENT>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::remove_payment<PAYMENT>(bm_round);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::remove_payment<PAYMENT>(bm_round);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_total_supply<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_total_supply: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_total_supply(bm_round, new_total_supply);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_total_supply(bm_round, new_total_supply);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_min_purchase<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_min_purchase: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_min_purchase(bm_round, new_min_purchase);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_min_purchase(bm_round, new_min_purchase);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_max_purchase<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_max_purchase: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_max_purchase(bm_round, new_max_purchase);
        // } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
        //     let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
        //     launchpad_ido::set_end_at(bm_round, new_end_at);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_end_at<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_end_at: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_end_at(bm_round, new_end_at);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_end_at(bm_round, new_end_at);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_start_at<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_start_at: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_start_at(bm_round, new_start_at);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_start_at(bm_round, new_start_at);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_is_pause<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_is_pause: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_is_pause(bm_round, new_is_pause);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_is_pause(bm_round, new_is_pause);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_is_open_claim_commission<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_is_open_claim_commission: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_is_open_claim_commission(bm_round, new_is_open_claim_commission);
        // } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
        //     let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
        //     launchpad_ido::set_is_open_claim_vesting(bm_round, new_is_open_claim_vesting);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_is_open_claim_vesting<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_is_open_claim_vesting: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_is_open_claim_vesting(bm_round, new_is_open_claim_vesting);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_is_open_claim_vesting(bm_round, new_is_open_claim_vesting);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_is_open_claim_refund<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        new_is_open_claim_refund: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::set_is_open_claim_refund(bm_round, new_is_open_claim_refund);
        } else {
            abort(ERoundTypeInvalid)
        };
    }


    public entry fun withdraw_all_balance<ROUND, T>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::withdraw_all_balance<T>(bm_round, ctx);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::withdraw_all_balance<T>(bm_round, ctx);
        } else {
            abort(ERoundTypeInvalid)
        };
    }


    public entry fun withdraw_balance<ROUND, T>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::withdraw_balance<T>(bm_round, amount, ctx);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_ido::withdraw_balance<T>(bm_round, amount, ctx);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_use_nft_purchase<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        is_use_nft_purchase: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_use_nft_purchase(bm_round, is_use_nft_purchase);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_use_once_purchase<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        is_once_purchase: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
            launchpad_presale::set_use_once_purchase(bm_round, is_once_purchase);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun use_affiliate_for_project<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        let name = round_name;
        string::append_utf8(&mut name, affiliate::get_name());

        launchpad_project::add_dynamic_object_field(project, name, affiliate::new_affiliate_system(ctx));

        set_is_use_affiliate<ROUND>(
            admin_storage,
            project,
            round_name,
            true,
            ctx
        );
    }

    public entry fun add_commission_list(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        milestones: vector<u64>,
        percents: vector<u64>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        assert!(vector::length(&milestones) > 0, ELengthEqZero);
        assert!(vector::length(&milestones) == vector::length(&percents), E2LengthNotEq);

        string::append_utf8(&mut round_name, affiliate::get_name());
        let bm_commission_setting = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);

        let profits = vec_map::empty();
        while (!vector::is_empty(&milestones)) {
            vec_map::insert(&mut profits, vector::pop_back(&mut milestones), vector::pop_back(&mut percents))
        };

        affiliate::add_commission_list(bm_commission_setting, &mut profits);
    }

    public entry fun remove_commission_list(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        milestones: vector<u64>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        string::append_utf8(&mut round_name, affiliate::get_name());
        let bm_commission_setting = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
        affiliate::remove_commission_list(bm_commission_setting, milestones);
    }

    public entry fun add_affiliator_list(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        affiliators: vector<address>,
        nations: vector<String>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        assert!(vector::length(&affiliators) > 0, ELengthEqZero);
        assert!(vector::length(&affiliators) == vector::length(&nations), E2LengthNotEq);

        string::append_utf8(&mut round_name, affiliate::get_name());
        let bm_commission_setting = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);

        let affiliator_list = vec_map::empty();
        while (!vector::is_empty(&affiliators)) {
            vec_map::insert(&mut affiliator_list, vector::pop_back(&mut affiliators), vector::pop_back(&mut nations))
        };

        affiliate::add_affiliator_list(bm_commission_setting, &mut affiliator_list, ctx);
    }

    public entry fun remove_affiliator_list(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        affiliators: vector<address>,
        nations: vector<String>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        assert!(vector::length(&affiliators) > 0, ELengthEqZero);
        assert!(vector::length(&affiliators) == vector::length(&nations), E2LengthNotEq);

        string::append_utf8(&mut round_name, affiliate::get_name());
        let bm_commission_setting = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);

        let affiliator_list = vec_map::empty();
        while (!vector::is_empty(&affiliators)) {
            vec_map::insert(&mut affiliator_list, vector::pop_back(&mut affiliators), vector::pop_back(&mut nations))
        };

        affiliate::remove_affiliator_list(bm_commission_setting, &mut affiliator_list);
    }

    public entry fun set_is_use_affiliate<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        is_use_affiliate: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field<PresaleRound>(project, round_name);
            launchpad_presale::set_is_use_affiliate(bm_round, is_use_affiliate);
        // }else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
        //     let bm_round = launchpad_project::borrow_mut_dynamic_object_field<IdoRound>(project, round_name);
        //     launchpad_ido::set_is_use_affiliate(bm_round, is_use_affiliate);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun set_whitelist<ROUND>(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        investors: vector<address>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);
        let name = round_name;
        string::append_utf8(&mut name, whitelist::get_name());
        if (launchpad_project::has_dynamic_object_field_key(project, name)) {
            let bm_whitelist = launchpad_project::borrow_mut_dynamic_object_field(project, name);
            whitelist::set_whitelist(bm_whitelist, investors);
        } else {
            launchpad_project::add_dynamic_object_field(project, name, whitelist::new_whitelist(investors, ctx));
        };

        if (utils::get_full_type<ROUND>() == utils::get_full_type<PresaleRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field<PresaleRound>(project, round_name);
            launchpad_presale::set_is_use_whitelist(bm_round, true);
        } else if (utils::get_full_type<ROUND>() == utils::get_full_type<IdoRound>()) {
            let bm_round = launchpad_project::borrow_mut_dynamic_object_field<IdoRound>(project, round_name);
            launchpad_ido::set_is_use_whitelist(bm_round, true);
        } else {
            abort(ERoundTypeInvalid)
        };
    }

    public entry fun remove_whitelist(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        investors: vector<address>,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        string::append_utf8(&mut round_name, whitelist::get_name());
        let bm_whitelist = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
        whitelist::remove_whitelist(bm_whitelist, investors);
    }

    public entry fun clear_whitelist(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        string::append_utf8(&mut round_name, whitelist::get_name());
        let bm_whitelist = launchpad_project::borrow_mut_dynamic_object_field(project, round_name);
        whitelist::clear_whitelist(bm_whitelist);
    }

    public entry fun add_vesting(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        token_amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        launchpad_vesting::add_vesting(project, round_name, token_amount, ctx);
    }

    public entry fun sub_vesting(
        admin_storage: &AdminStorage,
        project: &mut Project,
        round_name: String,
        token_amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        launchpad_vesting::sub_vesting(project, round_name, token_amount, ctx);
    }
}
