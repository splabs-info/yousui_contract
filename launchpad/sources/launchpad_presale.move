// SPDX-License-Identifier: Apache-2.0
module yousui::launchpad_presale {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin};
    use sui::object_bag::{Self, ObjectBag};
    use sui::bag::{Self, Bag};
    use sui::transfer;
    use sui::display;
    use sui::balance;
    use sui::pay;
    use sui::package::{Self, Publisher};
    use sui::vec_set::{Self, VecSet};
    use sui::vec_map::{Self, VecMap};
    use sui::clock::{Self, Clock};
    use sui::math;
    use sui::dynamic_field as df;

    use std::string::{Self, String, utf8};
    use std::option::{Self, Option};
    use std::vector;

    use yousui::launchpad_project::{Self, Project, ProjectInfo};
    use yousui::launchpad_vesting;
    use yousui::whitelist::{Self, Whitelist};
    use yousui::affiliate::{Self, CommissionSetting, Affiliator};
    use yousui::utils;
    use yousuinfts::nft::{Self, YOUSUINFT};

    friend yousui::admin;   
    
    const ETokenDecimalInvalid: u64 = 300+1;
    const EStartTimeInvalid: u64 = 300+2;
    const EEndTimeInvalid: u64 = 300+3;
    const EAmountLtMinPurchase: u64 = 300+4;
    const EMinAllocationInvalid: u64 = 300+5;
    const ETotalSupplyInvalid: u64 = 300+6;
    const EPaymentMethodInvalid: u64 = 300+7;
    const ETokenAmountInvalid: u64 = 300+8;
    const EAmountExceedMaxUser: u64 = 300+9;
    const EAmountExceedMaxRound: u64 = 300+10;
    const EVestingClaimNothing: u64 = 300+11;
    const EHavePurchaseOnce: u64 = 300+12;
    const EPurchaseTimeInvalid: u64 = 300+13;
    const ECurrentPause: u64 = 300+14;
    const EMinPurchaseInvalid: u64 = 300+15;
    const EMaxAllocationInvalid: u64 = 300+16;
    const ESenderNotInWhitelist: u64 = 300+17;
    const EClaimVestingNotOpen: u64 = 300+18;
    const EAmountLtMinAllocation: u64 = 300+19;
    const EClaimAffiliateNotOpen: u64 = 300+20;
    const ECurrnetTimeGtEndTime: u64 = 300+21;
    const EAmountExceedMinPurchase: u64 = 300+22;
    const EAmountExceedMaxPurchase: u64 = 300+23;
    const EMaxPurchaseAndMinPurchaseInvalid: u64 = 300+24;
    const EMaxPurchaseAndTotalSupplyInvalid: u64 = 300+25;
    const ENotInWhitelistOrNotOwnNft: u64 = 300+26;
    const ENotInWhitelist: u64 = 300+27;

    const CONDITION_USE_WHITELIST: vector<u8> = b"USE_WHITELIST";
    const CONDITION_USE_AFFILIATE: vector<u8> = b"USE_AFFILIATE";
    const CONDITION_USE_ONCE_PURCHASE: vector<u8> = b"USE_ONCE_PURCHASE";
    const CONDITION_USE_NFT_PURCHASE: vector<u8> = b"USE_NFT_PURCHASE";

    const TYPE_ROUND: vector<u8> = b"FCFS";

    const MAX_PERCENT: u64 = 100_000_000_000; // => 100 //decimal 9

    struct Round has key, store {
        id: UID,
        name: String,
        type: String,
        project: ProjectInfo,
        vesting: Option<ID>,
        token_type: String,
        token_decimal: u8,
        start_at: u64,
        end_at: u64,
        // max_allocation: u64,
        // min_allocation: u64,
        min_purchase: u64,
        max_purchase: u64,
        total_sold: u64,
        total_supply: u64,
        is_pause: bool,
        is_open_claim_commission: bool,
        is_open_claim_vesting: bool,
        payments: VecMap<String, Payment>,
        participants: VecSet<address>,
        condition: Bag,
        balance: ObjectBag,
        other: ObjectBag,
    }

    struct Payment has copy, drop, store {
        ratio_per_token: u64,
        ratio_decimal: u8, // should be 9
        method_type: String,
        payment_decimal: u8,
    }

    struct InvestmentCertificate has key {
        id: UID,
        project: ProjectInfo,
        event_name: String,
        token_type: String,
        issue_date: u64,
        description: String,
    }

    struct Invest has store {
        investments: vector<Receipt>,
        total_accumulate_token: u64,
    }

    struct Receipt has store {
        payment: Payment,
        payment_amount: u64,
        token_amount: u64,
    }

    struct LAUNCHPAD_PRESALE has drop {}

    fun init(witness: LAUNCHPAD_PRESALE, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<Round>(&publisher, utf8(b"YouSUI x {project.name} <> {name}"), utf8(b"{project.description}") , ctx);
        display<InvestmentCertificate>(&publisher, utf8(b"YouSUI x {project.name} <> {event_name} <> Investment Certificate"), utf8(b"{description}") , ctx);
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

    public(friend) fun new_round<TOKEN>(
        clock: &Clock,
        project: &Project,
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
    ): Round {
        let timestamp = clock::timestamp_ms(clock);

        assert!(token_decimal <= 18, ETokenDecimalInvalid);
        assert!(end_at >= timestamp, EStartTimeInvalid);
        assert!(end_at >= start_at, EEndTimeInvalid);
        assert!(min_purchase >= (1 * (math::pow(10, token_decimal))), EMinPurchaseInvalid);
        assert!(max_purchase >= min_purchase, EMaxPurchaseAndMinPurchaseInvalid);
        assert!(total_supply >= max_purchase, EMaxPurchaseAndTotalSupplyInvalid);
        // assert!(min_allocation >= min_purchase, EMinAllocationInvalid);
        // assert!(max_allocation >= min_allocation, ETotalSupplyInvalid);
        // assert!(total_supply >= max_allocation, EMaxAllocationInvalid);

        Round {
            id: object::new(ctx),
            name,
            type: utf8(TYPE_ROUND),
            project: launchpad_project::get_project_info(project),
            vesting: option::none(),
            token_type: utils::get_full_type<TOKEN>(),
            token_decimal,
            start_at,
            end_at,
            // max_allocation,
            // min_allocation,
            min_purchase,
            max_purchase,
            total_sold: 0,
            total_supply,
            is_pause: false,
            is_open_claim_commission: false,
            is_open_claim_vesting: false,
            payments: vec_map::empty<String, Payment>(),
            participants: vec_set::empty<address>(),
            condition: bag::new(ctx),
            balance: object_bag::new(ctx),
            other: object_bag::new(ctx),
        }
    }

    public(friend) fun add_payment<PAYMENT>(bm_round: &mut Round, ratio_per_token: u64, ratio_decimal: u8, payment_decimal: u8, ctx: &mut TxContext) {
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

        if (!object_bag::contains(&bm_round.balance, method_type)) {
            object_bag::add(&mut bm_round.balance, method_type, coin::zero<PAYMENT>(ctx));
        }
    }

    public(friend) fun remove_payment<PAYMENT>(bm_round: &mut Round) {
        let method_type = utils::get_full_type<PAYMENT>();

        if(vec_map::contains(&bm_round.payments, &method_type)) {
            vec_map::remove(&mut bm_round.payments, &method_type);
        }
    }

    public(friend) fun get_token_type(bm_round: &Round): String {
        bm_round.token_type
    }

    public(friend) fun set_is_open_claim_commission(bm_round: &mut Round, new_is_open_claim_commission: bool) {
        bm_round.is_open_claim_commission = new_is_open_claim_commission;
    }

    public(friend) fun set_max_purchase(bm_round: &mut Round, new: u64) {
        bm_round.max_purchase = new;
    }

    public(friend) fun set_min_purchase(bm_round: &mut Round, new: u64) {
        bm_round.min_purchase = new;
    }

    public(friend) fun set_total_supply(bm_round: &mut Round, new_total_supply: u64) {
        assert!(new_total_supply >= bm_round.total_sold, ETotalSupplyInvalid);
        bm_round.total_supply = new_total_supply;
    }

    public(friend) fun set_end_at(bm_round: &mut Round, new_end_at: u64) {
        assert!(bm_round.start_at < new_end_at, EEndTimeInvalid);
        bm_round.end_at = new_end_at;
    }

    public(friend) fun set_start_at(bm_round: &mut Round, new_start_at: u64) {
        assert!(bm_round.end_at > new_start_at, EStartTimeInvalid);
        bm_round.start_at = new_start_at;
    }

    public(friend) fun set_is_pause(bm_round: &mut Round, new_is_pause: bool) {
        bm_round.is_pause = new_is_pause;
    }

    public(friend) fun set_is_open_claim_vesting(bm_round: &mut Round, new_is_open_claim_vesting: bool) {
        bm_round.is_open_claim_vesting = new_is_open_claim_vesting;
    }

    public(friend) fun set_vesting(bm_round: &mut Round, vesting_id: ID) {
        option::fill(&mut bm_round.vesting, vesting_id);
    }

    public entry fun deposit_balance<T>(project: &mut Project, round_name: String, coin: Coin<T>, _ctx: &mut TxContext) {
        let method_type = utils::get_full_type<T>();
        let bm_round = borrow_mut_from_project<Round>(project, round_name);

        if (object_bag::contains(&bm_round.balance, method_type)) {
            let bm_balance = object_bag::borrow_mut(&mut bm_round.balance, method_type);
            coin::join(bm_balance, coin);
        } else {
            object_bag::add(&mut bm_round.balance, method_type, coin);
        }
    }

    public(friend) fun withdraw_all_balance<T>(bm_round: &mut Round, ctx: &mut TxContext) {
        let method_type = utils::get_full_type<T>();
        let bm_balance = object_bag::borrow_mut<String, Coin<T>>(&mut bm_round.balance, method_type);

        transfer::public_transfer(coin::from_balance<T>(balance::withdraw_all(coin::balance_mut(bm_balance)), ctx), tx_context::sender(ctx));
    }

    public(friend) fun withdraw_balance<T>(bm_round: &mut Round, amount: u64, ctx: &mut TxContext) {
        let method_type = utils::get_full_type<T>();
        let bm_balance = object_bag::borrow_mut<String, Coin<T>>(&mut bm_round.balance, method_type);

        transfer::public_transfer(coin::from_balance<T>(balance::split(coin::balance_mut(bm_balance), amount), ctx), tx_context::sender(ctx));
    }

    public(friend) fun set_use_once_purchase(bm_round: &mut Round, is_use_once_purchase: bool) {
        let condition_key = utf8(CONDITION_USE_ONCE_PURCHASE);

        if (bag::contains(&bm_round.condition, condition_key)) {
            bag::remove<String, bool>(&mut bm_round.condition, condition_key);
        };
        bag::add(&mut bm_round.condition, condition_key, is_use_once_purchase);
    }

    public(friend) fun set_use_nft_purchase(bm_round: &mut Round, is_use_nft_purchase: bool) {
        let condition_key = utf8(CONDITION_USE_NFT_PURCHASE);

        if (bag::contains(&bm_round.condition, condition_key)) {
            bag::remove<String, bool>(&mut bm_round.condition, condition_key);
        };
        bag::add(&mut bm_round.condition, condition_key, is_use_nft_purchase);
    }


    // fun check_nft_purchase<T>(project: &Project, name: String): bool {
    //     let condition_key = utf8(CONDITION_USE_NFT_PURCHASE);
    //     let nft_purchse_type = utils::get_full_type<T>();
    //     let b_round = borrow_from_project<Round>(project, name);

    //     if (bag::contains_with_type<String, Option<String>>(&b_round.condition, condition_key)) {
    //         let is_use_nft_purchase: &Option<String> = bag::borrow(&b_round.condition, condition_key);
    //         if (!option::is_none(is_use_nft_purchase)) {
    //             if (*option::borrow(is_use_nft_purchase) == nft_purchse_type) {
    //                 true
    //             } else {
    //                 false
    //             }
    //         } else {
    //             true
    //         }
    //     } else {
    //         true
    //     }
    // }


    fun check_once_purchase(b_round: &Round, investor: address) {
        let condition_key = utf8(CONDITION_USE_ONCE_PURCHASE);

        assert!(
            !if (bag::contains(&b_round.condition, condition_key)) {
                let is_use_once_purchase = *bag::borrow(&b_round.condition, condition_key);
                if (is_use_once_purchase) {
                    vec_set::contains(&b_round.participants, &investor)
                } else {
                    false
                }
            } else {
                false
            },
            EHavePurchaseOnce
        );
    }

    public(friend) fun set_is_use_affiliate(bm_round: &mut Round, new_is_use_affiliate: bool) {
        let condition_key = utf8(CONDITION_USE_AFFILIATE);

        if (!bag::contains(&bm_round.condition, condition_key)) {
            bag::add(&mut bm_round.condition, condition_key, option::none<bool>());
        };

        let bm_option_is_use_affiliate = bag::borrow_mut(&mut bm_round.condition, condition_key);
        option::swap_or_fill(bm_option_is_use_affiliate, new_is_use_affiliate);
    }

    public(friend) fun set_is_use_whitelist(bm_round: &mut Round, new_is_use_whitelist: bool) {
        let condition_key = utf8(CONDITION_USE_WHITELIST);

        if (!bag::contains(&bm_round.condition, condition_key)) {
            bag::add(&mut bm_round.condition, condition_key, option::none<bool>());
        };

        let bm_option_is_use_whitelist = bag::borrow_mut(&mut bm_round.condition, condition_key);
        option::swap_or_fill(bm_option_is_use_whitelist, new_is_use_whitelist);
    }


    fun check_in_whitelist(project: &Project, name: String, sender: &address): bool {
        let condition_key = utf8(CONDITION_USE_WHITELIST);
        let b_round = borrow_from_project<Round>(project, name);

        string::append_utf8(&mut name, whitelist::get_name());

        if (bag::contains(&b_round.condition, condition_key)) {
            let b_option_whitelist = bag::borrow(&b_round.condition, condition_key);
            let is_use_whitelist = *option::borrow(b_option_whitelist);
            if (is_use_whitelist) {
                let b_whitelist = borrow_from_project<Whitelist>(project, name);
                whitelist::check_in_whitelist(b_whitelist, sender)
            } else {
                true
            }
        } else {
            true
        }
    }

    fun handle_affiliate<PAYMENT>(project: &mut Project, name: String, affiliate_code: String, buyer: address, token_amount: u64) {
        let condition_key = utf8(CONDITION_USE_AFFILIATE);
        let b_round = borrow_from_project<Round>(project, name);

        string::append_utf8(&mut name, affiliate::get_name());

        if (bag::contains(&b_round.condition, condition_key)) {
            let b_option_affiliate = bag::borrow<String, Option<bool>>(&b_round.condition, condition_key);
            let is_use_affiliate = *option::borrow(b_option_affiliate);
            if (is_use_affiliate) {
                let bm_commission_setting = borrow_mut_from_project<CommissionSetting>(project, name);
                affiliate::add_profit_by_affiliate<PAYMENT>(bm_commission_setting, affiliate_code, buyer, token_amount);
            }
        }
    }


    fun borrow_mut_from_project<T: key + store>(project: &mut Project, name: String): &mut T {
        launchpad_project::borrow_mut_dynamic_object_field<T>(project, name)
    }

    fun borrow_from_project<T: key + store>(project: &Project, name: String): &T {
        launchpad_project::borrow_dynamic_object_field<T>(project, name)
    }

    fun buy_validate_amount(b_round: &Round, b_payment_method_type: &String, _total_accumulate_token: u64, token_amount: u64, _sender: address) {
        // let after_purchase_token_amount = total_accumulate_token + token_amount;

        assert!(vec_map::contains(&b_round.payments, b_payment_method_type), EPaymentMethodInvalid);
        // if (!vec_set::contains(&b_round.participants, &sender)) {
        //     assert!(token_amount >= b_round.min_allocation, EAmountLtMinAllocation);
        // } else {
        //     assert!(token_amount >= b_round.min_purchase, EAmountLtMinPurchase);
        // };
        assert!(token_amount >= b_round.min_purchase, EAmountExceedMinPurchase);
        assert!(token_amount <= b_round.max_purchase, EAmountExceedMaxPurchase);

        // assert!(after_purchase_token_amount <= b_round.max_allocation, EAmountExceedMaxUser);
        // assert!((total_accumulate_token + token_amount) <= b_round.total_supply, EAmountExceedMaxRound);
        assert!((b_round.total_sold + token_amount) <= b_round.total_supply, EAmountExceedMaxRound);
    }

    fun buy_validate_time(b_round: &Round, timestamp: u64) {
        assert!(timestamp >= b_round.start_at, EPurchaseTimeInvalid);
        assert!(b_round.end_at >= timestamp, EPurchaseTimeInvalid);
        assert!(!b_round.is_pause, ECurrentPause);
    }

    fun cal_payment_amount(b_round: &Round, method_type: String, amount: u64, decimal: u8): u64 {
        let b_payment = vec_map::get(&b_round.payments, &method_type);

        utils::mul_u64_div_decimal(
            utils::mul_u64_div_decimal(b_payment.ratio_per_token, amount, b_payment.ratio_decimal),
            (math::pow(10, b_payment.payment_decimal) as u64),
            decimal
        )
    }

    fun issue_investment_certificate(timestamp: u64, project: ProjectInfo, round_name: String, token_type: String, ctx: &mut TxContext) : InvestmentCertificate {
        InvestmentCertificate {
            id: object::new(ctx),
            project,
            event_name: round_name,
            token_type,
            issue_date: timestamp,
            description: utf8(b"The investment certificate, published by YouSUI, is a document providing proof of your token investment in a crypto project. It verifies your ownership, including the number of tokens purchased, and grants you certain rights and benefits within the project. The certificate ensures transparency and credibility, protecting your interests and allowing you to participate in project-related decisions. It serves as a valuable record of your investment, issued by YouSUI, in the crypto project.")
        }
    }

    fun check_nft_purchase(project: &Project, name: String, nft_purchase: &YOUSUINFT): bool {
        let condition_key = utf8(CONDITION_USE_NFT_PURCHASE);
        let b_round = borrow_from_project<Round>(project, name);
        let nft_type = nft::type(nft_purchase);

        if (bag::contains(&b_round.condition, condition_key)) {
            let is_use_nft_purchase = *bag::borrow<String, bool>(&b_round.condition, condition_key);
            if (is_use_nft_purchase) {
                (nft_type == b"og")
            } else {
                true
            }
        } else {
            true
        }
    }    

    fun check_entry_condition(project: &Project, name: String, sender: &address, nft_purchase: &YOUSUINFT) {
        assert!(check_nft_purchase(project, name, nft_purchase) || check_in_whitelist(project, name, sender), ENotInWhitelistOrNotOwnNft);
    }

    public entry fun purchase<TOKEN, PAYMENT>(clock: &Clock, project: &mut Project, round_name: String, payment: vector<Coin<PAYMENT>>, token_amount: u64, affiliate_code: String, nft_purchase: &YOUSUINFT, ctx: &mut TxContext) {
        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let payment_method_type = utils::get_full_type<PAYMENT>();

        check_entry_condition(project, round_name, &sender, nft_purchase);

        
        let bm_round = borrow_mut_from_project<Round>(project, round_name);
        let token_decimal = bm_round.token_decimal;

        buy_validate_time(bm_round, timestamp);

        // check condition
        check_once_purchase(bm_round, sender);
        //
        
        let payment_amount = cal_payment_amount(bm_round, payment_method_type, token_amount, token_decimal);

        let receipt =  Receipt {
                        payment: *vec_map::get(&bm_round.payments, &payment_method_type),
                        payment_amount,
                        token_amount,
                    };
        if (!df::exists_<address>(&bm_round.id, sender)) {
            let receipt_instance = vector::empty<Receipt>();
            vector::push_back(&mut receipt_instance, receipt);
            buy_validate_amount(bm_round, &payment_method_type, 0 ,token_amount, sender);
            df::add<address, Invest>(&mut bm_round.id, sender, Invest {
                investments: receipt_instance,
                total_accumulate_token: token_amount,
            });
        } else {
            let b_invest_by_user = df::borrow<address, Invest>(&bm_round.id, sender);
            buy_validate_amount(bm_round, &payment_method_type, b_invest_by_user.total_accumulate_token ,token_amount, sender);
            let bm_invest_by_user = df::borrow_mut<address, Invest>(&mut bm_round.id, sender);
            bm_invest_by_user.total_accumulate_token = bm_invest_by_user.total_accumulate_token + token_amount;
            vector::push_back(&mut bm_invest_by_user.investments, receipt);
        };

        let (paid, remainder) = utils::merge_and_split<PAYMENT>(payment, payment_amount, ctx);

        let bm_round_coin = object_bag::borrow_mut<String, Coin<PAYMENT>>(&mut bm_round.balance, payment_method_type);
        coin::put(coin::balance_mut(bm_round_coin), paid);

        bm_round.total_sold = bm_round.total_sold + token_amount;

        if (!vec_set::contains(&bm_round.participants, &sender)) {
            vec_set::insert(&mut bm_round.participants, sender);
            transfer::transfer(issue_investment_certificate(timestamp, bm_round.project, round_name, bm_round.token_type, ctx), sender)
        };

        if (coin::value(&remainder) > 0) {
            transfer::public_transfer(remainder, sender)
        } else {
            coin::destroy_zero(remainder);
        };

        if (option::is_none(&bm_round.vesting)) {
            let bm_balance = object_bag::borrow_mut<String, Coin<TOKEN>>(&mut bm_round.balance, bm_round.token_type);
            pay::split_and_transfer<TOKEN>(bm_balance, token_amount, sender, ctx)
        } else {
            launchpad_vesting::add_vesting(project, round_name, token_amount, ctx);
        };

        handle_affiliate<PAYMENT>(project, round_name, affiliate_code, sender, payment_amount);
    }

    public entry fun purchase_without_nft<TOKEN, PAYMENT>(clock: &Clock, project: &mut Project, round_name: String, payment: vector<Coin<PAYMENT>>, token_amount: u64, affiliate_code: String, ctx: &mut TxContext) {
        let timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let payment_method_type = utils::get_full_type<PAYMENT>();

        assert!(check_in_whitelist(project, round_name, &sender), ENotInWhitelist);
        
        let bm_round = borrow_mut_from_project<Round>(project, round_name);
        let token_decimal = bm_round.token_decimal;

        buy_validate_time(bm_round, timestamp);

        // check condition
        check_once_purchase(bm_round, sender);
        //
        
        let payment_amount = cal_payment_amount(bm_round, payment_method_type, token_amount, token_decimal);

        let receipt =  Receipt {
                        payment: *vec_map::get(&bm_round.payments, &payment_method_type),
                        payment_amount,
                        token_amount,
                    };
        if (!df::exists_<address>(&bm_round.id, sender)) {
            let receipt_instance = vector::empty<Receipt>();
            vector::push_back(&mut receipt_instance, receipt);
            buy_validate_amount(bm_round, &payment_method_type, 0 ,token_amount, sender);
            df::add<address, Invest>(&mut bm_round.id, sender, Invest {
                investments: receipt_instance,
                total_accumulate_token: token_amount,
            });
        } else {
            let b_invest_by_user = df::borrow<address, Invest>(&bm_round.id, sender);
            buy_validate_amount(bm_round, &payment_method_type, b_invest_by_user.total_accumulate_token ,token_amount, sender);
            let bm_invest_by_user = df::borrow_mut<address, Invest>(&mut bm_round.id, sender);
            bm_invest_by_user.total_accumulate_token = bm_invest_by_user.total_accumulate_token + token_amount;
            vector::push_back(&mut bm_invest_by_user.investments, receipt);
        };

        let (paid, remainder) = utils::merge_and_split<PAYMENT>(payment, payment_amount, ctx);

        let bm_round_coin = object_bag::borrow_mut<String, Coin<PAYMENT>>(&mut bm_round.balance, payment_method_type);
        coin::put(coin::balance_mut(bm_round_coin), paid);

        bm_round.total_sold = bm_round.total_sold + token_amount;

        if (!vec_set::contains(&bm_round.participants, &sender)) {
            vec_set::insert(&mut bm_round.participants, sender);
            transfer::transfer(issue_investment_certificate(timestamp, bm_round.project, round_name, bm_round.token_type, ctx), sender)
        };

        if (coin::value(&remainder) > 0) {
            transfer::public_transfer(remainder, sender)
        } else {
            coin::destroy_zero(remainder);
        };

        if (option::is_none(&bm_round.vesting)) {
            let bm_balance = object_bag::borrow_mut<String, Coin<TOKEN>>(&mut bm_round.balance, bm_round.token_type);
            pay::split_and_transfer<TOKEN>(bm_balance, token_amount, sender, ctx)
        } else {
            launchpad_vesting::add_vesting(project, round_name, token_amount, ctx);
        };

        handle_affiliate<PAYMENT>(project, round_name, affiliate_code, sender, payment_amount);
    }

    public entry fun claim_vesting<TOKEN>(clock: &Clock, project: &mut Project, round_name: String, period_id_list: vector<u64>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);
        let total_claim = launchpad_vesting::update_withdraw(clock, project, round_name, period_id_list, ctx);
        let bm_round = borrow_mut_from_project<Round>(project, round_name);

        assert!(total_claim > 0, EVestingClaimNothing);
        assert!(timestamp > bm_round.end_at, ECurrnetTimeGtEndTime);
        assert!(bm_round.is_open_claim_vesting, EClaimVestingNotOpen);
        
        let bm_balance = object_bag::borrow_mut<String, Coin<TOKEN>>(&mut bm_round.balance, bm_round.token_type);
        pay::split_and_transfer<TOKEN>(bm_balance, total_claim, sender, ctx);
    }

    public entry fun claim_commission<T>(
        clock: &Clock,
        project: &mut Project,
        round_name: String,
        nation: String,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let affiliate_code = affiliate::get_affiliate_code(sender, &nation);
        let timestamp = clock::timestamp_ms(clock);

        let affiliate_name = round_name;
        string::append_utf8(&mut affiliate_name, affiliate::get_name());
        let bm_commission_setting = launchpad_project::borrow_mut_dynamic_object_field<CommissionSetting>(project, affiliate_name);
        affiliate::claim_commission<T>(bm_commission_setting, affiliate_code);

        let bm_affiliator = affiliate::borrow_dynamic_object_field<Affiliator>(bm_commission_setting, affiliate_code);
        let commission_amount = affiliate::get_commission<T>(bm_affiliator);

        let bm_round = borrow_mut_from_project<Round>(project, round_name);
        
        assert!(timestamp > bm_round.end_at, ECurrnetTimeGtEndTime);
        assert!(bm_round.is_open_claim_commission, EClaimAffiliateNotOpen);

        let bm_balance = object_bag::borrow_mut(&mut bm_round.balance, utils::get_full_type<T>());
        pay::split_and_transfer<T>(bm_balance, commission_amount, sender, ctx);
    }

}