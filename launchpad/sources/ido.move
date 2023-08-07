// SPDX-License-Identifier: Apache-2.0
module yousui::ido {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::coin::{Coin};
    use sui::object_bag::{Self, ObjectBag};
    use sui::package::{Self, Publisher};
    use sui::vec_set::{Self, VecSet};
    use sui::vec_map::{Self, VecMap};
    use sui::clock::{Self, Clock};
    use std::option::{Self, Option};
    use sui::transfer;
    use sui::display;
    use sui::math;
    use sui::dynamic_field as df;
    use sui::event::emit;

    use std::string::{String, utf8};
    use std::vector;

    use yousui::project::{Self, ProjectInfo};
    use yousui::service::{Self, Service};
    use yousui::vault::{Self, Vaults};
    use yousui::policy::{Self, Policy};
    use yousui::policy_purchase;
    use yousui::policy_yousui_nft;
    use yousui::policy_whitelist;
    use yousui::policy_staking_tier;
    use yousui::service_vesting;
    use yousui::service_affiliate;
    use yousui::service_preregister;
    use yousui::service_refund;
    use yousui::certificate;
    use yousui::utils;

    use yousuinfts::nft::{YOUSUINFT};
    use yousui_staking::staking::{StakingStorage};

    friend yousui::admin;
    
    const EVestingClaimNothing: u64 = 300+0;
    const EClaimVestingNotOpen: u64 = 300+1;
    const EEndTimeInvalid: u64 = 300+2;
    const EStartTimeInvalid: u64 = 300+3;
    const ETokenDecimalInvalid: u64 = 300+4;
    const EPurchaseTimeInvalid: u64 = 300+5;
    const ECurrentPause: u64 = 300+6;
    const ETotalSupplyInvalid: u64 = 300+7;
    const ESoldExceedSupply: u64 = 300+8;
    const ECurrentTimeInvalid: u64 = 300+9;
    const EPaymentMethodInvalid: u64 = 300+10;
    const ESenderNotParticipant: u64 = 300+11;
    const ENotEndRoundYet: u64 = 300+12;
    const EShouldClaimRefundBefore: u64 = 300+13;
    const EPurchaseFunctionInvalid: u64 = 300+14;
    const ERefundClaimed: u64 = 300+15;
    // UPDATE
    const ELengthMismatch: u64 = 300+16;
    // UPDATE

    const POLICY: vector<u8> = b"POLICY";
    const SERVICE: vector<u8> = b"SERVICE";
    const VAULT: vector<u8> = b"VAULT";

    // UPDATE
    const ADMIN_VESTING_TYPE: u8 = 0;
    // UPDATE
    const PURCHASE_NOR_TYPE: u8 = 1;
    const PURCHASE_REF_TYPE: u8 = 2;
    const PURCHASE_HOLD_TYPE: u8 = 3;
    const PURCHASE_HOLD_TIER_TYPE: u8 = 4;
    const PURCHASE_STAKING_TYPE: u8 = 5;


    struct Round has key, store {
        id: UID,
        name: String,
        project: ProjectInfo,

        token_type: String,
        token_decimal: u8,

        start_at: u64,
        end_at: u64,

        total_sold: u64,
        total_supply: u64,

        payments: VecMap<String, Payment>,

        participants: VecSet<address>,

        is_pause: bool,

        purchase_type: VecSet<u8>,

        core: VecMap<String, ID>,

        other: ObjectBag,
    }

    struct Payment has copy, drop, store {
        ratio_per_token: u64,
        ratio_decimal: u8, // should be 9
        method_type: String,
        payment_decimal: u8,
    }

    struct Invest has store {
        investments: vector<Receipt>,
        total_accumulate_token: u64,
        final_accumulate_token: Option<u64>
    }

    struct Receipt has store {
        payment: Payment,
        payment_amount: u64,
        token_amount: u64,
    }

    struct IDO has drop {}

    // ======== Events =========

    struct NewRound has copy, drop {
        round_id: ID,
        round_name: String,
        project_name: String,
        token_type: String,
        token_decimal: u8,
        total_supply: u64,
        sender: address
    }

    struct Purchase has copy, drop {
        round_id: ID,
        token_amount: u64,
        payment_amount: u64,
        payment_method_type: String,
        sender: address
    }

    struct PurchaseEvent has copy, drop {
        project_name: String,
        round_name: String,
        token_amount: u64,
        payment_amount: u64,
        payment_method_type: String,
        sender: address
    }


    // UPDATE
    struct AdminVesting has copy, drop {
        round_id: ID,
        arr_user_address: vector<address>,
        arr_token_amount: vector<u64>,
        sender: address
    }
    // UPDATE

    struct ClaimVesting has copy, drop {
        round_id: ID,
        period_id_list: vector<u64>,
        total_claim: u64,
        sender: address
    }

    struct ClaimVestingEvent has copy, drop {
        project_name: String,
        round_name: String,
        period_id_list: vector<u64>,
        total_claim: u64,
        sender: address
    }

    struct ClaimRefundEvent has copy, drop {
        project_name: String,
        round_name: String,
        total_refund: u64,
        refund_token_type: String,
        sender: address
    }


    fun init(witness: IDO, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<Round>(&publisher, utf8(b"YouSUI x {project.name} <> {name}"), utf8(b"{project.description}") , ctx);
        transfer::public_transfer(publisher, tx_context::sender(ctx));
    }

    fun display<T: key>(publisher: &Publisher, name: String, description: String, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];
        let values = vector[
            name,
            utf8(b"{project.link_url}"),
            utf8(b"{project.image_url}"),
            description,
            utf8(b"{project.website}"),
            utf8(b"YouSUI Creator")
        ];
        let display = display::new_with_fields<T>(
            publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    public(friend) fun new_round<TOKEN>(name: String, project: ProjectInfo, token_decimal: u8, start_at: u64, end_at: u64, total_supply: u64, purchase_type: vector<u8>, ctx: &mut TxContext): Round {

        let id = object::new(ctx);
        let token_type = utils::get_full_type<TOKEN>();

        let core = vec_map::empty<String, ID>();
        let other = object_bag::new(ctx);

        new_policy(&mut core, &mut other, ctx);
        new_service(&mut core, &mut other, ctx);
        new_vault(&mut core, &mut other, ctx);

        emit(NewRound {
            round_id: object::uid_to_inner(&id),
            round_name: name,
            project_name: project::get_project_name(&project),
            token_type,
            token_decimal,
            total_supply,
            sender: tx_context::sender(ctx)
        });

        let arr_purchase_type = vec_set::empty<u8>();
        while (!vector::is_empty(&purchase_type)) {
            vec_set::insert(&mut arr_purchase_type, vector::pop_back(&mut purchase_type));
        };

        Round {
            id,
            name,
            project,
            token_type,
            token_decimal,
            start_at,
            end_at,
            total_sold: 0,
            total_supply,
            payments: vec_map::empty(),
            participants: vec_set::empty(),
            is_pause: false,
            purchase_type: arr_purchase_type,
            core,
            other,
        }
    }

    public fun purchase_nor<TOKEN, PAYMENT>(
        clock: &Clock,
        round: &mut Round,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        ctx: &mut TxContext
    ) {

        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let payment_method_type = utils::get_full_type<PAYMENT>();
        let payment_amount = cal_payment_amount(&round.payments, payment_method_type, token_amount, round.token_decimal);

        buy_validate(round, timestamp);

        assert!(vec_set::contains(&round.purchase_type, &PURCHASE_NOR_TYPE), EPurchaseFunctionInvalid);

        // handle receipt
        let receipt =  Receipt {
                payment: *vec_map::get(&round.payments, &payment_method_type),
                payment_amount,
                token_amount,
            };
        if (!df::exists_<address>(&round.id, sender)) {
            let receipt_instance = vector::empty<Receipt>();
            vector::push_back(&mut receipt_instance, receipt);
            df::add<address, Invest>(&mut round.id, sender, Invest {
                investments: receipt_instance,
                total_accumulate_token: token_amount,
                final_accumulate_token: option::none(),
            });
        } else {
            let bm_invest_by_user = df::borrow_mut<address, Invest>(&mut round.id, sender);
            bm_invest_by_user.total_accumulate_token = bm_invest_by_user.total_accumulate_token + token_amount;
            vector::push_back(&mut bm_invest_by_user.investments, receipt);
        };

        // check policy
        let policy = object_bag::borrow_mut(&mut round.other, utf8(POLICY));
        let request = policy::new_request(object::uid_to_inner(&round.id));
        policy_purchase::check(policy, &mut request, token_amount);
        policy_whitelist::check(policy, &mut request, ctx);
        policy_yousui_nft::pass(policy, &mut request);
        policy_staking_tier::pass(policy, &mut request);
        policy::confirm_request(policy, request);

        // update state
        update_state_purchase<PAYMENT>(round, token_amount, payment_amount, paid, ctx);

        // check service
        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));
        let vesting_id = service_vesting::get_id(service);


        service_preregister::validate_purchase(service, round.total_sold, round.total_supply);
        service_vesting::execute_add_vesting(service, token_amount, sender);

        emit(PurchaseEvent {
            project_name: project::get_project_name(&round.project),
            round_name: round.name,
            token_amount,
            payment_amount,
            payment_method_type,
            sender: tx_context::sender(ctx)
        });

        handle_cert(round, timestamp, vesting_id, ctx);
    }

    public fun purchase_ref<TOKEN, PAYMENT>(
        clock: &Clock,
        round: &mut Round,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        affiliate_code: String,
        ctx: &mut TxContext
    ) {

        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let payment_method_type = utils::get_full_type<PAYMENT>();
        let payment_amount = cal_payment_amount(&round.payments, payment_method_type, token_amount, round.token_decimal);

        buy_validate(round, timestamp);
        assert!(vec_set::contains(&round.purchase_type, &PURCHASE_REF_TYPE), EPurchaseFunctionInvalid);

        // handle receipt
        let receipt =  Receipt {
                payment: *vec_map::get(&round.payments, &payment_method_type),
                payment_amount,
                token_amount,
            };
        if (!df::exists_<address>(&round.id, sender)) {
            let receipt_instance = vector::empty<Receipt>();
            vector::push_back(&mut receipt_instance, receipt);
            df::add<address, Invest>(&mut round.id, sender, Invest {
                investments: receipt_instance,
                total_accumulate_token: token_amount,
                final_accumulate_token: option::none(),
            });
        } else {
            let bm_invest_by_user = df::borrow_mut<address, Invest>(&mut round.id, sender);
            bm_invest_by_user.total_accumulate_token = bm_invest_by_user.total_accumulate_token + token_amount;
            vector::push_back(&mut bm_invest_by_user.investments, receipt);
        };

        // check policy
        let policy = object_bag::borrow_mut(&mut round.other, utf8(POLICY));
        let request = policy::new_request(object::uid_to_inner(&round.id));
        policy_purchase::check(policy, &mut request, token_amount);
        policy::confirm_request(policy, request);

        // update state
        update_state_purchase<PAYMENT>(round, token_amount, payment_amount, paid, ctx);

        // check service
        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));
        let vesting_id = service_vesting::get_id(service);


        service_affiliate::add_profit_by_affiliate<PAYMENT>(service, affiliate_code, payment_amount);
        service_preregister::validate_purchase(service, round.total_sold, round.total_supply);
        service_vesting::execute_add_vesting(service, token_amount, sender);

        emit(PurchaseEvent {
            project_name: project::get_project_name(&round.project),
            round_name: round.name,
            token_amount,
            payment_amount,
            payment_method_type,
            sender: tx_context::sender(ctx)
        });

        handle_cert(round, timestamp, vesting_id, ctx);
    }

    public fun purchase_yousui_og_holder<TOKEN, PAYMENT>(
        clock: &Clock,
        round: &mut Round,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        hold_nft: &YOUSUINFT,
        ctx: &mut TxContext
    ) {

        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let payment_method_type = utils::get_full_type<PAYMENT>();
        let payment_amount = cal_payment_amount(&round.payments, payment_method_type, token_amount, round.token_decimal);

        buy_validate(round, timestamp);
        assert!(vec_set::contains(&round.purchase_type, &PURCHASE_HOLD_TYPE), EPurchaseFunctionInvalid);

        // handle receipt
        let receipt =  Receipt {
                payment: *vec_map::get(&round.payments, &payment_method_type),
                payment_amount,
                token_amount,
            };
        if (!df::exists_<address>(&round.id, sender)) {
            let receipt_instance = vector::empty<Receipt>();
            vector::push_back(&mut receipt_instance, receipt);
            df::add<address, Invest>(&mut round.id, sender, Invest {
                investments: receipt_instance,
                total_accumulate_token: token_amount,
                final_accumulate_token: option::none(),
            });
        } else {
            let bm_invest_by_user = df::borrow_mut<address, Invest>(&mut round.id, sender);
            bm_invest_by_user.total_accumulate_token = bm_invest_by_user.total_accumulate_token + token_amount;
            vector::push_back(&mut bm_invest_by_user.investments, receipt);
        };

        // check policy
        let policy = object_bag::borrow_mut(&mut round.other, utf8(POLICY));
        let request = policy::new_request(object::uid_to_inner(&round.id));
        policy_purchase::check(policy, &mut request, token_amount);
        policy_whitelist::check(policy, &mut request, ctx);
        policy_yousui_nft::check(policy, &mut request, hold_nft);
        policy_staking_tier::pass(policy, &mut request);
        policy::confirm_request(policy, request);

        // update state
        update_state_purchase<PAYMENT>(round, token_amount, payment_amount, paid, ctx);

        // check service
        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));
        let vesting_id = service_vesting::get_id(service);

        service_preregister::validate_purchase(service, round.total_sold, round.total_supply);
        service_vesting::execute_add_vesting(service, token_amount, sender);

        emit(PurchaseEvent {
            project_name: project::get_project_name(&round.project),
            round_name: round.name,
            token_amount,
            payment_amount,
            payment_method_type,
            sender: tx_context::sender(ctx)
        });

        handle_cert(round, timestamp, vesting_id, ctx);
    }

    public fun purchase_yousui_tier45_holder<TOKEN, PAYMENT>(
        clock: &Clock,
        round: &mut Round,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        hold_nft: &YOUSUINFT,
        ctx: &mut TxContext
    ) {

        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let payment_method_type = utils::get_full_type<PAYMENT>();
        let payment_amount = cal_payment_amount(&round.payments, payment_method_type, token_amount, round.token_decimal);

        buy_validate(round, timestamp);
        assert!(vec_set::contains(&round.purchase_type, &PURCHASE_HOLD_TIER_TYPE), EPurchaseFunctionInvalid);

        // handle receipt
        let receipt =  Receipt {
                payment: *vec_map::get(&round.payments, &payment_method_type),
                payment_amount,
                token_amount,
            };
        if (!df::exists_<address>(&round.id, sender)) {
            let receipt_instance = vector::empty<Receipt>();
            vector::push_back(&mut receipt_instance, receipt);
            df::add<address, Invest>(&mut round.id, sender, Invest {
                investments: receipt_instance,
                total_accumulate_token: token_amount,
                final_accumulate_token: option::none(),
            });
        } else {
            let bm_invest_by_user = df::borrow_mut<address, Invest>(&mut round.id, sender);
            bm_invest_by_user.total_accumulate_token = bm_invest_by_user.total_accumulate_token + token_amount;
            vector::push_back(&mut bm_invest_by_user.investments, receipt);
        };

        // check policy
        let policy = object_bag::borrow_mut(&mut round.other, utf8(POLICY));
        let request = policy::new_request(object::uid_to_inner(&round.id));
        policy_purchase::check(policy, &mut request, token_amount);
        policy_whitelist::pass(policy, &mut request);
        policy_yousui_nft::check_tier(policy, &mut request, hold_nft);
        policy_staking_tier::pass(policy, &mut request);
        policy::confirm_request(policy, request);

        // update state
        update_state_purchase<PAYMENT>(round, token_amount, payment_amount, paid, ctx);

        // check service
        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));
        let vesting_id = service_vesting::get_id(service);

        service_preregister::validate_purchase(service, round.total_sold, round.total_supply);
        service_vesting::execute_add_vesting(service, token_amount, sender);

        emit(PurchaseEvent {
            project_name: project::get_project_name(&round.project),
            round_name: round.name,
            token_amount,
            payment_amount,
            payment_method_type,
            sender: tx_context::sender(ctx)
        });

        handle_cert(round, timestamp, vesting_id, ctx);
    }

    public fun purchase_nor_staking<TOKEN, PAYMENT>(
        clock: &Clock,
        round: &mut Round,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        staking_storage: &StakingStorage,
        ctx: &mut TxContext
    ) {

        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let payment_method_type = utils::get_full_type<PAYMENT>();
        let payment_amount = cal_payment_amount(&round.payments, payment_method_type, token_amount, round.token_decimal);

        buy_validate(round, timestamp);

        assert!(vec_set::contains(&round.purchase_type, &PURCHASE_STAKING_TYPE), EPurchaseFunctionInvalid);

        // handle receipt
        let receipt =  Receipt {
                payment: *vec_map::get(&round.payments, &payment_method_type),
                payment_amount,
                token_amount,
            };
        if (!df::exists_<address>(&round.id, sender)) {
            let receipt_instance = vector::empty<Receipt>();
            vector::push_back(&mut receipt_instance, receipt);
            df::add<address, Invest>(&mut round.id, sender, Invest {
                investments: receipt_instance,
                total_accumulate_token: token_amount,
                final_accumulate_token: option::none(),
            });
        } else {
            let bm_invest_by_user = df::borrow_mut<address, Invest>(&mut round.id, sender);
            bm_invest_by_user.total_accumulate_token = bm_invest_by_user.total_accumulate_token + token_amount;
            vector::push_back(&mut bm_invest_by_user.investments, receipt);
        };

        // check policy
        let policy = object_bag::borrow_mut(&mut round.other, utf8(POLICY));
        let request = policy::new_request(object::uid_to_inner(&round.id));
        policy_purchase::check(policy, &mut request, token_amount);
        policy_whitelist::pass(policy, &mut request);
        policy_yousui_nft::pass(policy, &mut request);
        policy_staking_tier::check(policy, &mut request, staking_storage, sender);
        policy::confirm_request(policy, request);

        // update state
        update_state_purchase<PAYMENT>(round, token_amount, payment_amount, paid, ctx);

        // check service
        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));
        let vesting_id = service_vesting::get_id(service);


        service_preregister::validate_purchase(service, round.total_sold, round.total_supply);
        service_vesting::execute_add_vesting(service, token_amount, sender);

        emit(PurchaseEvent {
            project_name: project::get_project_name(&round.project),
            round_name: round.name,
            token_amount,
            payment_amount,
            payment_method_type,
            sender: tx_context::sender(ctx)
        });

        handle_cert(round, timestamp, vesting_id, ctx);
    }

///------------------------------------------------------------------------------------------------------


    public fun claim_vesting<TOKEN>(clock: &Clock, round: &mut Round, period_id_list: vector<u64>, ctx: &mut TxContext) {
        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));
        let total_claim = service_vesting::update_withdraw(clock, service, period_id_list, sender);
        // UPDATE
        if (!vec_set::contains(&round.purchase_type, &ADMIN_VESTING_TYPE)) {
            let invest_by_user = df::borrow<address, Invest>(&round.id, sender);
            if (service_preregister::is_use_preregister(service)) assert!(!option::is_none(&invest_by_user.final_accumulate_token), EShouldClaimRefundBefore);
        };
        // UPDATE
        assert!(total_claim > 0, EVestingClaimNothing);
        assert!(service_vesting::check_is_open_claim_vesting(service), EClaimVestingNotOpen);
        assert!(timestamp > round.end_at, ENotEndRoundYet);
        service_refund::insert_refund_address(service, sender);
        
        let round_balance = object_bag::borrow_mut<String, Vaults>(&mut round.other, utf8(VAULT));
        vault::withdraw<TOKEN>(round_balance, total_claim, sender, ctx);

        emit(ClaimVestingEvent {
            project_name: project::get_project_name(&round.project),
            round_name: round.name,
            period_id_list,
            total_claim,
            sender
        })
    }

    public fun claim_refund_preregister<PAYMENT>(clock: &Clock, round: &mut Round, ctx: &mut TxContext) {
        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);

        let payment_method_type = utils::get_full_type<PAYMENT>();
        assert!(vec_map::contains(&round.payments, &payment_method_type), EPaymentMethodInvalid);

        let token_decimal = round.token_decimal;

        assert!(df::exists_(&round.id, sender), ESenderNotParticipant);

        assert!(timestamp > round.end_at, ENotEndRoundYet);

        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));

        service_preregister::validate_claim_refund(service);
        
        let investor = df::borrow_mut<address, Invest>(&mut round.id, sender);

        assert!(option::is_none(&investor.final_accumulate_token), ERefundClaimed);

        if (round.total_sold > round.total_supply) {
            let investor_pool_percent = utils::mul_u64_div_u64(investor.total_accumulate_token, utils::max_percent(), round.total_sold);
            let real_allocation_amount = utils::mul_u64_div_u64(investor_pool_percent, round.total_supply, utils::max_percent());
            let revert_token_amount = investor.total_accumulate_token - real_allocation_amount;

            option::fill(&mut investor.final_accumulate_token, real_allocation_amount);

            let refund_payment_amount = cal_payment_amount(&round.payments, payment_method_type, revert_token_amount, token_decimal);

            service_vesting::execute_sub_vesting(service, revert_token_amount, sender);
            
            let round_balance = object_bag::borrow_mut<String, Vaults>(&mut round.other, utf8(VAULT));

            vault::withdraw<PAYMENT>(round_balance, refund_payment_amount, sender, ctx);
            
        } else {
            option::fill(&mut investor.final_accumulate_token, investor.total_accumulate_token);
        }
    }


    // Just handle for FCFS, not handle for pre-register yet.
    public fun claim_refund<PAYMENT>(clock: &Clock, round: &mut Round, ctx: &mut TxContext) {
        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);

        let payment_method_type = utils::get_full_type<PAYMENT>();
        assert!(vec_map::contains(&round.payments, &payment_method_type), EPaymentMethodInvalid);

        let token_decimal = round.token_decimal;

        assert!(df::exists_(&round.id, sender), ESenderNotParticipant);

        assert!(timestamp > round.end_at, ENotEndRoundYet);

        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));

        service_refund::check_valid_refund(service, clock);
        service_refund::insert_refund_address(service, sender);
        
        let investor = df::borrow_mut<address, Invest>(&mut round.id, sender);

        assert!(option::is_none(&investor.final_accumulate_token), ERefundClaimed);

        let refund_payment_amount = cal_payment_amount(&round.payments, payment_method_type, investor.total_accumulate_token, token_decimal);
        service_vesting::execute_sub_vesting(service, investor.total_accumulate_token, sender);
        let round_balance = object_bag::borrow_mut<String, Vaults>(&mut round.other, utf8(VAULT));
        vault::withdraw<PAYMENT>(round_balance, copy refund_payment_amount, sender, ctx);

        option::fill(&mut investor.final_accumulate_token, 0);

        emit(ClaimRefundEvent {
            project_name: project::get_project_name(&round.project),
            round_name: round.name,
            total_refund: refund_payment_amount,
            refund_token_type: payment_method_type,
            sender
        })
    }

///------------------------------------------------------------------------------------------------------

    public(friend) fun get_mut_policy(round: &mut Round): &mut Policy {
        object_bag::borrow_mut(&mut round.other, utf8(POLICY))
    }

    public(friend) fun get_mut_service(round: &mut Round): &mut Service {
        object_bag::borrow_mut(&mut round.other, utf8(SERVICE))
    }

    public(friend) fun get_mut_vault(round: &mut Round): &mut Vaults {
        object_bag::borrow_mut(&mut round.other, utf8(VAULT))
    }

///------------------------------------------------------------------------------------------------------

    public fun get_project(round: &Round): ProjectInfo {
        round.project
    }

    public fun get_token_type(round: &Round): String {
        round.token_type
    }

///------------------------------------------------------------------------------------------------------

    public(friend) fun set_end_at(bm_round: &mut Round, new_end_at: u64) {
        assert!(bm_round.start_at < new_end_at, EEndTimeInvalid);
        bm_round.end_at = new_end_at;
    }

    public(friend) fun set_start_at(bm_round: &mut Round, new_start_at: u64) {
        assert!(bm_round.end_at > new_start_at, EStartTimeInvalid);
        bm_round.start_at = new_start_at;
    }

    public(friend) fun set_pause(bm_round: &mut Round, is_pause: bool) {
        bm_round.is_pause = is_pause;
    }

    public(friend) fun set_total_supply(bm_round: &mut Round, new_total_supply: u64) {
        assert!(new_total_supply >= bm_round.total_sold, ETotalSupplyInvalid);
        bm_round.total_supply = new_total_supply;
    }

    public(friend) fun set_total_sold(bm_round: &mut Round, new_total_sold: u64) {
        bm_round.total_sold = new_total_sold;
    }

    public(friend) fun set_push_total_sold(bm_round: &mut Round, amount: u64) {
        bm_round.total_sold = bm_round.total_sold + amount;
    }

    public(friend) fun set_payment_rate<PAYMENT>(bm_round: &mut Round, new_ratio_per_token: u64) {
        let method_type = utils::get_full_type<PAYMENT>();
        let payment = vec_map::get_mut(&mut bm_round.payments, &method_type);
        payment.ratio_per_token = new_ratio_per_token;
    }

    public(friend) fun set_arr_purchase_type(bm_round: &mut Round, arr_purchase_type: VecSet<u8>) {
        bm_round.purchase_type = arr_purchase_type;
    }

    public(friend) fun add_payment<PAYMENT>(bm_round: &mut Round, ratio_per_token: u64, ratio_decimal: u8, payment_decimal: u8) {
        assert!(payment_decimal <= 18, ETokenDecimalInvalid);

        let method_type = utils::get_full_type<PAYMENT>();

        if(vec_map::contains(&bm_round.payments, &method_type)) {
            vec_map::remove(&mut bm_round.payments, &method_type);
        };

        vec_map::insert(&mut bm_round.payments, method_type,
            Payment {
                ratio_per_token,
                ratio_decimal,
                method_type: utils::get_full_type<PAYMENT>(),
                payment_decimal,
            }
        );
    }

    public(friend) fun remove_payment<PAYMENT>(bm_round: &mut Round) {
        let method_type = utils::get_full_type<PAYMENT>();

        if(vec_map::contains(&bm_round.payments, &method_type)) {
            vec_map::remove(&mut bm_round.payments, &method_type);
        }
    }

///------------------------------------------------------------------------------------------------------

    fun buy_validate(round: &Round, timestamp: u64) {
        assert!(timestamp >= round.start_at, EPurchaseTimeInvalid);  // ok
        assert!(round.end_at >= timestamp, ECurrentTimeInvalid);
        assert!(!round.is_pause, ECurrentPause);
    }

    fun cal_payment_amount(payments: &VecMap<String, Payment>, method_type: String, amount: u64, decimal: u8): u64 {
        let b_payment = vec_map::get(payments, &method_type);

        utils::mul_u64_div_decimal(
            utils::mul_u64_div_decimal(b_payment.ratio_per_token, amount, b_payment.ratio_decimal),
            (math::pow(10, b_payment.payment_decimal) as u64),
            decimal
        )
    }

    fun handle_cert(round: &mut Round, timestamp: u64, vesting_id: ID, ctx: &mut TxContext){
        // Handle participants
        let sender = tx_context::sender(ctx);
        if (!vec_set::contains(&round.participants, &sender)) {
            vec_set::insert(&mut round.participants, sender);
            certificate::issue_investment_certificate(timestamp, round.project, round.name, round.token_type, vesting_id, ctx);
        };
    }

    // UPDATE
    fun handle_cert_with_user(round: &mut Round, timestamp: u64, vesting_id: ID, user: address, ctx: &mut TxContext){
        if (!vec_set::contains(&round.participants, &user)) {
            vec_set::insert(&mut round.participants, user);
            certificate::issue_investment_certificate_with_user(timestamp, round.project, round.name, round.token_type, vesting_id, user, ctx);
        };
    }
    // UPDATE

    fun update_state_purchase<PAYMENT>(round: &mut Round, token_amount: u64, payment_amount: u64, paid: vector<Coin<PAYMENT>>, ctx: &mut TxContext) {
        // Handle total sold 
        round.total_sold = round.total_sold + token_amount;

        let sender = tx_context::sender(ctx);

        // // Handle participants
        // if (!vec_set::contains(&round.participants, &sender)) {
        //     vec_set::insert(&mut round.participants, sender);
        //     certificate::issue_investment_certificate(timestamp, round.project, round.name, round.token_type, vesting_id, ctx);
        // };

        // Handle Payment
        let (income, remainder) = utils::merge_and_split<PAYMENT>(paid, payment_amount, ctx);

        let round_balance = object_bag::borrow_mut<String, Vaults>(&mut round.other, utf8(VAULT));
        vault::deposit<PAYMENT>(round_balance, income, ctx);
        transfer::public_transfer(remainder, sender)
    }

///------------------------------------------------------------------------------------------------------

    fun new_policy(core: &mut VecMap<String, ID>, other: &mut ObjectBag, ctx: &mut TxContext) {
        let key = utf8(POLICY);

        let (policy, policy_id) = policy::new(ctx);
        vec_map::insert(core, key, policy_id);
        object_bag::add(other, key, policy);
    }

    fun new_service(core: &mut VecMap<String, ID>, other: &mut ObjectBag, ctx: &mut TxContext) {
        let key = utf8(SERVICE);

        let (service, service_id) = service::new(ctx);
        vec_map::insert(core, key, service_id);
        object_bag::add(other, key, service);
    }

    fun new_vault(core: &mut VecMap<String, ID>, other: &mut ObjectBag, ctx: &mut TxContext) {
        let key = utf8(VAULT);

        let (vault, vault_id) = vault::new(ctx);
        vec_map::insert(core, key, vault_id);
        object_bag::add(other, key, vault);
    }

///////////////////////////////// UPGARADE ////////////////////////////////////////////

    public(friend) fun airdrop_vesting(
        clock: &Clock,
        round: &mut Round,
        arr_user_address: vector<address>,
        arr_token_amount: vector<u64>,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&arr_user_address) == vector::length(&arr_token_amount), ELengthMismatch);
        assert!(!round.is_pause, ECurrentPause);
        assert!(vec_set::contains(&round.purchase_type, &ADMIN_VESTING_TYPE), EPurchaseFunctionInvalid);

        let timestamp = clock::timestamp_ms(clock);
        let service = object_bag::borrow_mut(&mut round.other, utf8(SERVICE));
        let vesting_id = service_vesting::get_id(service);
        let temp_arr_user_address = copy arr_user_address;

        emit(AdminVesting {
            round_id: object::uid_to_inner(&round.id),
            arr_user_address: copy arr_user_address,
            arr_token_amount: copy arr_token_amount,
            sender: tx_context::sender(ctx)
        });

        while (!vector::is_empty(&arr_user_address) && !vector::is_empty(&arr_token_amount)) {
            let user_address = vector::pop_back(&mut arr_user_address);
            let user_amount = vector::pop_back(&mut arr_token_amount);
            service_vesting::execute_add_vesting(service, user_amount, user_address);
        };

        while (!vector::is_empty(&temp_arr_user_address)) {
            let user_address = vector::pop_back(&mut temp_arr_user_address);
            handle_cert_with_user(round, timestamp, vesting_id, user_address, ctx);
        };
    }
}