// SPDX-License-Identifier: Apache-2.0
module yousui::affiliate {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::object_bag::{Self, ObjectBag};
    use sui::vec_map::{Self, VecMap};
    use sui::address;

    use std::option::{Self, Option};
    use std::string::{Self, String};
    use sui::dynamic_object_field as dof;

    use yousui::utils;

    use std::vector;

    const AFFILIATE_NAME: vector<u8> = b" <> Affiliate";

    const MAX_PERCENT: u64 = 100_000_000_000; // => 100 //decimal 9

    const EProfitClaimed: u64 = 200+0;

    friend yousui::admin;
    friend yousui::launchpad_presale;

    struct CommissionSetting has key, store{
        id: UID,
        profit_list: VecMap<u64, u64>,
        other: ObjectBag,
    }

    struct Affiliator has key, store {
        id: UID,
        user: address,
        nation: String,
        affiliate_code: String,
        history: VecMap<address, VecMap<String, Fund>>,
        accumulate_token: VecMap<String, Fund>,
        profit_amount: VecMap<String, Fund>,
    }

    struct Fund has store, drop {
        token_type: String,
        amount: u64,
        is_claim_profit: Option<bool>,
    }

    public fun get_name(): vector<u8> {
        AFFILIATE_NAME
    }


    public(friend) fun new_affiliate_system(ctx: &mut TxContext): CommissionSetting {
        CommissionSetting {
            id: object::new(ctx),
            profit_list: vec_map::empty(),
            other: object_bag::new(ctx),
        }
    }

    public(friend) fun add_commission_list(commission_setting: &mut CommissionSetting, profits: &mut VecMap<u64, u64>) {
        while (!vec_map::is_empty(profits)) {
            let (milestone, percent) = vec_map::pop(profits);
            if (vec_map::contains(&commission_setting.profit_list, &milestone)) {
                vec_map::remove(&mut commission_setting.profit_list, &milestone);
            };
            vec_map::insert(&mut commission_setting.profit_list, milestone, percent);
        };
    }

    public(friend) fun remove_commission_list(commission_setting: &mut CommissionSetting, milestones: vector<u64>) {
        while (!vector::is_empty(&milestones)) {
            let milestone = vector::pop_back(&mut milestones);
            if (vec_map::contains(&commission_setting.profit_list, &milestone)) {
                vec_map::remove(&mut commission_setting.profit_list, &milestone);
            };
        };
    }

    public fun get_affiliate_code(user: address, nation: &String): String {
        let affiliate_code = *nation;
        let user_string = address::to_string(user);
        let sub_user_string = string::sub_string(&user_string, 30, 64);
        string::append(&mut affiliate_code, sub_user_string);
        affiliate_code
    }

    public(friend) fun get_commission<T>(affiliator: &Affiliator): u64 {
        let fund_type = utils::get_full_type<T>();
        let b_fund = vec_map::get(&affiliator.profit_amount, &fund_type);
        b_fund.amount
    }

    public(friend) fun add_affiliator_list(commission_setting: &mut CommissionSetting, affiliator_list: &mut VecMap<address, String>, ctx: &mut TxContext) {
        while (!vec_map::is_empty(affiliator_list)) {
            let (user_address, nation) = vec_map::pop(affiliator_list);
            let affiliate_code = get_affiliate_code(user_address, &nation);
            if (!has_dynamic_object_field_key(commission_setting, affiliate_code)) {
                add_dynamic_object_field<Affiliator>(commission_setting, affiliate_code, Affiliator {
                    id: object::new(ctx),
                    user: user_address,
                    nation: nation,
                    affiliate_code,
                    history: vec_map::empty(),
                    accumulate_token: vec_map::empty(),
                    profit_amount: vec_map::empty(),
                });
            };
        };
    }

    public(friend) fun remove_affiliator_list(commission_setting: &mut CommissionSetting, affiliator_list: &mut VecMap<address, String>) {
        while (!vec_map::is_empty(affiliator_list)) {
            let (user_address, nation) = vec_map::pop(affiliator_list);
            let affiliate_code = get_affiliate_code(user_address, &nation);
            if (has_dynamic_object_field_key(commission_setting, affiliate_code)) {
                remove_dynamic_object_field(commission_setting, affiliate_code);
            };
        };
    }

    fun cal_profit_amount(accumulate_token: u64, profit_list: &VecMap<u64, u64>): u64 {
        let milestones = vec_map::keys(profit_list);
        let final_milestone = 0;
        while (!vector::is_empty(&milestones)) {
            let milestone = vector::pop_back(&mut milestones);
            if (accumulate_token >= milestone && milestone > final_milestone) {
                final_milestone = milestone;
            }
        };

        let bonus_percent = if (final_milestone == 0) 0 else *vec_map::get(profit_list, &final_milestone);
        let profit_amount = utils::mul_u64_div_u64(accumulate_token, bonus_percent, MAX_PERCENT);
        profit_amount
    }
    
    public(friend) fun add_profit_by_affiliate<PAYMENT>(commission_setting: &mut CommissionSetting, affiliate_code: String, buyer: address, token_amount: u64) {
        let payment_method_type = utils::get_full_type<PAYMENT>();
        let profit_list = *&commission_setting.profit_list;
        let bm_affiliator = borrow_mut_dynamic_object_field<Affiliator>(commission_setting, affiliate_code);


        if (vec_map::contains(&bm_affiliator.profit_amount, &payment_method_type)) {
            let b_fund = vec_map::get(&bm_affiliator.profit_amount, &payment_method_type);
            assert!(!*option::borrow(&b_fund.is_claim_profit), EProfitClaimed);
        };
        
        if(!vec_map::contains(&bm_affiliator.history, &buyer)) {
            vec_map::insert(&mut bm_affiliator.history, buyer, vec_map::empty());
        };

        let bm_fund_list = vec_map::get_mut(&mut bm_affiliator.history, &buyer);
        if(!vec_map::contains(bm_fund_list, &payment_method_type)) {
            vec_map::insert(bm_fund_list, payment_method_type, Fund {
                token_type: payment_method_type,
                amount: token_amount,
                is_claim_profit: option::none()
            });
        } else {
            let (_, bm_fund_list) = vec_map::remove(&mut bm_affiliator.history, &buyer);
            let (_, fund_accumulate) = vec_map::remove(&mut bm_fund_list, &payment_method_type);
            vec_map::insert(&mut bm_fund_list, payment_method_type, Fund {
                    token_type: payment_method_type,
                    amount: fund_accumulate.amount + token_amount,
                    is_claim_profit: option::none()
            });
            vec_map::insert(&mut bm_affiliator.history, buyer, bm_fund_list);
        };

// accumulate_token cal
        if (!vec_map::contains(&bm_affiliator.accumulate_token, &payment_method_type)) {
            vec_map::insert(
                &mut bm_affiliator.accumulate_token,
                payment_method_type,
                Fund {
                    token_type: payment_method_type,
                    amount: token_amount,
                    is_claim_profit: option::none()
                }
            );
        } else {
            let (_, fund_accumulate) = vec_map::remove(&mut bm_affiliator.accumulate_token, &payment_method_type);
            vec_map::insert(
                &mut bm_affiliator.accumulate_token,
                payment_method_type,
                Fund {
                    token_type: payment_method_type,
                    amount: fund_accumulate.amount + token_amount,
                    is_claim_profit: option::none()
                }
            );
        };

// profit cal
        if (vec_map::contains(&bm_affiliator.profit_amount, &payment_method_type)) {
            let (_, _) = vec_map::remove(&mut bm_affiliator.profit_amount, &payment_method_type);
        };
        vec_map::insert(
            &mut bm_affiliator.profit_amount,
            payment_method_type,
            Fund {
                token_type: payment_method_type,
                amount: cal_profit_amount(vec_map::get(&bm_affiliator.accumulate_token, &payment_method_type).amount, &profit_list),
                is_claim_profit: option::some(false)
            }
        );

    }

    public(friend) fun claim_commission<T>(commission_setting: &mut CommissionSetting, affiliate_code: String) {
        let fund_type = utils::get_full_type<T>();
        let bm_affiliator = borrow_mut_dynamic_object_field<Affiliator>(commission_setting, affiliate_code);
        let bm_fund = vec_map::get_mut(&mut bm_affiliator.profit_amount, &fund_type);
        assert!(!*option::borrow(&bm_fund.is_claim_profit), EProfitClaimed);
        option::swap(&mut bm_fund.is_claim_profit, true);
    }

    public(friend) fun add_dynamic_object_field<T: key + store>(commission_setting: &mut CommissionSetting, field_name: String, filed_value: T) {
        dof::add(&mut commission_setting.id, field_name, filed_value);
    }

    public(friend) fun remove_dynamic_object_field(commission_setting: &mut CommissionSetting, field_name: String) {
        let affiliator = dof::remove(&mut commission_setting.id, field_name);
        let Affiliator { id, user: _, nation: _, affiliate_code: _, history: _, accumulate_token: _, profit_amount: _} = affiliator;
        object::delete(id);
    }

    public(friend) fun borrow_mut_dynamic_object_field<T: key + store>(commission_setting: &mut CommissionSetting, field_name: String): &mut T {
        dof::borrow_mut(&mut commission_setting.id, field_name)
    }

    public(friend) fun borrow_dynamic_object_field<T: key + store>(commission_setting: &CommissionSetting, field_name: String): &T {
        dof::borrow(&commission_setting.id, field_name)
    }

    public(friend) fun has_dynamic_object_field_key(commission_setting: &CommissionSetting, field_name: String): bool {
        dof::exists_(&commission_setting.id, field_name)
    }
}